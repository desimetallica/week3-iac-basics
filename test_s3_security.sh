#!/bin/bash

# Script to verify S3 bucket security: public access block and TLS-only enforcement
# Assumes AWS CLI is configured with appropriate credentials (e.g., root account or IAM user with S3 permissions)
# Run this script after 'terraform apply' in the terraform copy/ directory

# Configuration - update these if your tfvars change
BUCKET_NAME=$(cd terraform && terraform output -raw s3_bucket_name)
REGION="eu-south-1"
TEST_OBJECT="index.html"

echo "=== S3 Bucket Security Verification Script ==="
echo "Bucket: $BUCKET_NAME"
echo "Region: $REGION"
echo ""

# Function to check if command succeeded
check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "\033[32mPASS\033[0m: $2"
    else
        echo -e "\033[31mFAIL\033[0m: $2"
    fi
}

# Test 1: Verify public access is blocked
echo "Test 1: Verifying public access is blocked..."
echo "Attempting unauthenticated access to bucket root..."
RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$BUCKET_NAME.s3.$REGION.amazonaws.com/")
if [ "$RESPONSE_CODE" -eq 403 ]; then
    check_result 0 "Public access is blocked (HTTP $RESPONSE_CODE)"
else
    check_result 1 "Public access may not be blocked (HTTP $RESPONSE_CODE - expected 403)"
fi
echo ""

# Test 2: Verify TLS-only enforcement (non-TLS requests are denied)
echo "Test 2: Verifying TLS-only enforcement..."
echo "Ensuring test object exists..."
aws s3api head-object --bucket "$BUCKET_NAME" --key "$TEST_OBJECT" --region "$REGION" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating test object..."
    # aws s3 cp config/index.html s3://desimetallica-workload-bucket/index.html 
    aws s3 cp "./config/$TEST_OBJECT" "s3://$BUCKET_NAME/$TEST_OBJECT" --region "$REGION"
    check_result $? "Test object created"
else
    echo "Test object already exists"
fi

echo "Generating pre-signed URL..."
#  aws s3 presign s3://desimetallica-workload-bucket/index.html --region eu-south-1 --expires-in 3600  --endpoint-url https://s3.eu-south-1.amazonaws.com
PRESIGNED_URL=$(aws s3 presign "s3://$BUCKET_NAME/$TEST_OBJECT" --region "$REGION" --expires-in 3600  --endpoint-url "https://s3.$REGION.amazonaws.com")
check_result $? "Pre-signed URL generated"

echo "Checking access over TLS..."
RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PRESIGNED_URL")
if [ "$RESPONSE_CODE" -eq 200 ]; then
    check_result 0 "TLS access successful (HTTP $RESPONSE_CODE)"
else
    check_result 1 "TLS access failed (HTTP $RESPONSE_CODE - expected 200)"
fi

echo "Modifying URL to use HTTP (non-TLS)..."
HTTP_URL=$(echo "$PRESIGNED_URL" | sed 's/https:/http:/')
echo "Testing non-TLS access..."
RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HTTP_URL")
if [ "$RESPONSE_CODE" -eq 403 ]; then
    check_result 0 "Non-TLS requests are denied (HTTP $RESPONSE_CODE)"
else
    check_result 1 "Non-TLS requests may be allowed (HTTP $RESPONSE_CODE - expected 403)"
fi



echo ""

echo "=== Verification Complete ==="
echo "Note: If any tests fail, check your Terraform configuration and AWS permissions."
echo "Clean up: aws s3 rm s3://$BUCKET_NAME/$TEST_OBJECT --region $REGION"