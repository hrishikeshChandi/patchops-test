# #!/bin/bash

# REGION=eu-north-1
# ACCOUNT_ID=572540381020
# ROLE_ARN=arn:aws:iam::${ACCOUNT_ID}:role/breachloop-lambda-role

# NAME=$1

# cd lambdas/$NAME

# zip handler.zip handler.py

# aws lambda update-function-code \
#   --function-name breachloop-$NAME \
#   --zip-file fileb://handler.zip \
#   --region $REGION

# echo "Deployed breachloop-$NAME"

# cd ../..
#!/bin/bash
# Usage: ./deploy_lambdas.sh <lambda_name>
REGION=eu-north-1
ACCOUNT_ID=572540381020
ROLE_ARN=arn:aws:iam::${ACCOUNT_ID}:role/breachloop-lambda-role

cd lambdas/$1
zip handler.zip handler.py
aws lambda update-function-code \
  --function-name breachloop-$1 \
  --zip-file fileb://handler.zip \
  --region $REGION
cd ../..
echo "Deployed breachloop-$1"