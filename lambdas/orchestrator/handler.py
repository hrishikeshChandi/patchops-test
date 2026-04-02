import json, boto3, uuid
from datetime import datetime
from lambdas.shared.utils import invoke_lambda, save_state

dynamo = boto3.resource("dynamodb", region_name="eu-north-1")
table = dynamo.Table("breachloop_pipeline")

SANDBOX_URL = "http://16.170.212.128:8000/run"


def lambda_handler(event, context):
    try:
        body = event.get("body")
        if isinstance(body, str):
            body = json.loads(body)
        elif body is None:
            body = event

        run_id = str(uuid.uuid4())
        repo_url = body.get("repo_url")
        file_path = body.get("file_path")

        save_state(
            table,
            run_id,
            {
                "status": "STARTED",
                "timestamp": datetime.utcnow().isoformat(),
                "repo_url": repo_url,
                "file_path": file_path,
            },
        )

        # Step 1 — Code Analyzer
        analyzer_result = invoke_lambda(
            "breachloop-code-analyzer", {"repo_url": repo_url, "file_path": file_path}
        )
        save_state(
            table, run_id, {"status": "ANALYZED", "analyzer_result": analyzer_result}
        )

        # Step 2 — Exploit Crafter
        exploit_result = invoke_lambda(
            "breachloop-exploit-crafter", {"vulnerability": analyzer_result}
        )
        save_state(
            table,
            run_id,
            {"status": "EXPLOIT_CRAFTED", "exploit_result": exploit_result},
        )

        # Step 3 — Run exploit in sandbox
        import urllib.request

        sandbox_payload = json.dumps(
            {
                "app_code": body.get("source_code", ""),
                "exploit_code": exploit_result.get("exploit_code", ""),
            }
        ).encode()

        req = urllib.request.Request(
            SANDBOX_URL,
            data=sandbox_payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=40) as resp:
            sandbox_result = json.loads(resp.read())

        save_state(
            table, run_id, {"status": "SANDBOX_DONE", "sandbox_result": sandbox_result}
        )

        # If exploit didn't succeed, stop — nothing to patch
        if not sandbox_result.get("exploit_succeeded"):
            save_state(table, run_id, {"status": "NOT_EXPLOITABLE"})
            return {
                "statusCode": 200,
                "body": json.dumps({"run_id": run_id, "status": "NOT_EXPLOITABLE"}),
            }

        # Step 4 — Patch Writer
        patch_result = invoke_lambda(
            "breachloop-patch-writer",
            {
                "source_code": body.get("source_code", ""),
                "vulnerability": analyzer_result,
                "exploit_code": exploit_result.get("exploit_code", ""),
            },
        )
        save_state(table, run_id, {"status": "PATCHED", "patch_result": patch_result})

        # Step 5 — Security Reviewer
        review_result = invoke_lambda(
            "breachloop-security-reviewer",
            {
                "original_code": body.get("source_code", ""),
                "patched_code": patch_result.get("patched_code", ""),
                "vulnerability": analyzer_result,
            },
        )
        save_state(
            table, run_id, {"status": "REVIEWED", "review_result": review_result}
        )

        # Step 6 — PR Generator
        pr_result = invoke_lambda(
            "breachloop-pr-generator",
            {
                "run_id": run_id,
                "file_path": file_path,
                "patched_code": review_result.get(
                    "final_patch", patch_result.get("patched_code", "")
                ),
                "vulnerability": analyzer_result,
                "exploit_output": sandbox_result.get("output", ""),
                "patch_explanation": patch_result.get("changes_made", ""),
            },
        )
        save_state(table, run_id, {"status": "PR_OPENED", "pr_result": pr_result})

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "run_id": run_id,
                    "status": "PR_OPENED",
                    "pr_url": pr_result.get("pr_url"),
                }
            ),
        }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
