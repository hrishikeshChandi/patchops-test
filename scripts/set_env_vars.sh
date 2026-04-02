#!/bin/bash
set -e

GROQ_KEY=$1
GH_TOKEN=$2
EC2_IP=$3
GH_REPO=$4
REGION=eu-north-1

if [ -z "$GROQ_KEY" ] || [ -z "$GH_TOKEN" ] || [ -z "$EC2_IP" ] || [ -z "$GH_REPO" ]; then
  echo "Usage: ./set_env_vars.sh <GROQ_API_KEY> <GITHUB_TOKEN> <EC2_IP> <GITHUB_REPO>"
  echo "Example: ./set_env_vars.sh gsk_abc123 ghp_xyz789 54.12.34.56 myuser/PatchOps-Target"
  exit 1
fi

COMMON_VARS="Variables={GROQ_API_KEY=$GROQ_KEY,GITHUB_TOKEN=$GH_TOKEN,SANDBOX_URL=http://$EC2_IP:8000,GITHUB_REPO=$GH_REPO}"

LAMBDAS=(
  "code_analyzer"
  "exploit_crafter"
  "patch_writer"
  "security_reviewer"
  "neighbor_resolver"
  "component_tester"
  "pr_generator"
  "system_tester"
  "requirements_checker"
  "graph_builder"
)

for NAME in "${LAMBDAS[@]}"; do
  echo "Setting env vars on patchops-$NAME ..."
  aws lambda update-function-configuration \
    --function-name "patchops-$NAME" \
    --environment "$COMMON_VARS" \
    --region "$REGION" > /dev/null
  aws lambda wait function-updated \
    --function-name "patchops-$NAME" \
    --region "$REGION"
  echo "  ✓ patchops-$NAME"
done

# Orchestrator gets DynamoDB vars too
echo "Setting env vars on patchops-orchestrator ..."
aws lambda update-function-configuration \
  --function-name "patchops-orchestrator" \
  --environment "Variables={GROQ_API_KEY=$GROQ_KEY,GITHUB_TOKEN=$GH_TOKEN,SANDBOX_URL=http://$EC2_IP:8000,GITHUB_REPO=$GH_REPO,DYNAMODB_TABLE=patchops_pipeline,AWS_REGION_NAME=$REGION}" \
  --region "$REGION" > /dev/null
aws lambda wait function-updated \
  --function-name "patchops-orchestrator" \
  --region "$REGION"
echo "  ✓ patchops-orchestrator"

echo ""
echo "========================================="
echo "All environment variables set."
echo "========================================="
