import os
import json
import boto3
from dotenv import load_dotenv

load_dotenv()

USE_LAMBDA = os.environ.get("USE_LAMBDA", "false").lower() == "true"
REGION = os.environ.get("AWS_REGION", "eu-north-1")

def invoke(function_name: str, payload: dict) -> dict:
    client = boto3.client("lambda", region_name=REGION)
    response = client.invoke(
        FunctionName=f"patchops-{function_name}",
        InvocationType="RequestResponse",
        Payload=json.dumps(payload)
    )
    raw = response["Payload"].read()
    return json.loads(raw)
