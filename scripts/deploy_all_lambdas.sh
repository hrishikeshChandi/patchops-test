#!/bin/bash
set -e

REGION=eu-north-1
ACCOUNT_ID=572540381020
ROLE_ARN=arn:aws:iam::572540381020:role/patchops-master-role
LAYER_ARN=arn:aws:lambda:eu-north-1:572540381020:layer:patchops-dependencies:1
BUILD_DIR=/tmp/patchops_build

declare -A HANDLERS=(
  ["orchestrator"]="lambda_handler"
  ["code_analyzer"]="handler"
  ["exploit_crafter"]="handler"
  ["patch_writer"]="lambda_handler"
  ["security_reviewer"]="lambda_handler"
  ["neighbor_resolver"]="handler"
  ["component_tester"]="handler"
  ["pr_generator"]="lambda_handler"
  ["system_tester"]="handler"
  ["requirements_checker"]="handler"
  ["graph_builder"]="handler"
)

REPO_ROOT=$(pwd)

for NAME in "${!HANDLERS[@]}"; do
  HANDLER_FN="${HANDLERS[$NAME]}"
  echo "========================================="
  echo "Building: patchops-$NAME"
  echo "========================================="

  STAGING="$BUILD_DIR/$NAME"
  rm -rf "$STAGING"
  mkdir -p "$STAGING/lambdas/$NAME"
  mkdir -p "$STAGING/lambdas/shared"

  cp "$REPO_ROOT/lambdas/$NAME/handler.py"     "$STAGING/lambdas/$NAME/handler.py"
  cp "$REPO_ROOT/lambdas/shared/utils.py"       "$STAGING/lambdas/shared/utils.py"
  cp "$REPO_ROOT/lambdas/shared/__init__.py"    "$STAGING/lambdas/shared/__init__.py"
  cp "$REPO_ROOT/lambdas/__init__.py"           "$STAGING/lambdas/__init__.py"
  touch "$STAGING/lambdas/$NAME/__init__.py"

  # pr_generator needs its template.py
  if [ "$NAME" == "pr_generator" ]; then
    cp "$REPO_ROOT/lambdas/pr_generator/template.py" "$STAGING/lambdas/pr_generator/template.py"
  fi

  ZIP_PATH="$BUILD_DIR/${NAME}.zip"
  cd "$STAGING" && zip -r "$ZIP_PATH" . -x "*.pyc" -x "*/__pycache__/*" > /dev/null
  cd "$REPO_ROOT"

  FUNCTION_NAME="patchops-$NAME"
  HANDLER_STR="lambdas.$NAME.handler.$HANDLER_FN"

  # Check if function exists
  if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" > /dev/null 2>&1; then
    echo "  → Updating existing function: $FUNCTION_NAME"
    aws lambda update-function-code \
      --function-name "$FUNCTION_NAME" \
      --zip-file "fileb://$ZIP_PATH" \
      --region "$REGION" > /dev/null

    aws lambda wait function-updated \
      --function-name "$FUNCTION_NAME" \
      --region "$REGION"

    aws lambda update-function-configuration \
      --function-name "$FUNCTION_NAME" \
      --handler "$HANDLER_STR" \
      --layers "$LAYER_ARN" \
      --timeout 120 \
      --memory-size 512 \
      --region "$REGION" > /dev/null
  else
    echo "  → Creating new function: $FUNCTION_NAME"
    aws lambda create-function \
      --function-name "$FUNCTION_NAME" \
      --runtime python3.11 \
      --role "$ROLE_ARN" \
      --handler "$HANDLER_STR" \
      --zip-file "fileb://$ZIP_PATH" \
      --layers "$LAYER_ARN" \
      --timeout 120 \
      --memory-size 512 \
      --region "$REGION" > /dev/null

    aws lambda wait function-active \
      --function-name "$FUNCTION_NAME" \
      --region "$REGION"
  fi

  echo "  ✓ Done: $FUNCTION_NAME"
done

echo ""
echo "========================================="
echo "All Lambda functions deployed."
echo "========================================="
