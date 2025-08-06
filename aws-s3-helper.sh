#!/bin/bash

# AWS S3 Backup Configuration Helper

NAMESPACE=default
SECRET_NAME="backup-storage-creds"

function show_help() {
    echo "AWS S3 Backup Configuration Helper"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup-credentials <access-key> <secret-key>  - Set AWS credentials"
    echo "  show-credentials                             - Show current credentials (decoded)"
    echo "  create-bucket <bucket-name> [region]         - Create S3 bucket"
    echo "  test-connection                              - Test AWS S3 connection"
    echo "  update-cluster <bucket-name>                 - Update cluster config with bucket name"
    echo ""
    echo "Examples:"
    echo "  $0 create-bucket cnpg-backup-510 ap-northeast-1"
    echo "  $0 update-cluster cnpg-backup-510"
    echo "  $0 test-connection"
    echo "  $0 show-credentials"
}

function setup_credentials() {
    local access_key="$1"
    local secret_key="$2"
    
    if [ -z "$access_key" ] || [ -z "$secret_key" ]; then
        echo "Error: Access key and secret key required"
        echo "Usage: $0 setup-credentials <access-key> <secret-key>"
        exit 1
    fi
    
    # Encode credentials
    local encoded_access=$(echo -n "$access_key" | base64)
    local encoded_secret=$(echo -n "$secret_key" | base64)
    
    echo "Setting up AWS S3 credentials..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
data:
  ACCESS_KEY_ID: $encoded_access
  SECRET_ACCESS_KEY: $encoded_secret
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ AWS credentials configured successfully!"
        echo "Access Key: ${access_key:0:8}..."
        echo "Secret Key: ${secret_key:0:8}..."
    else
        echo "❌ Failed to configure credentials"
    fi

    echo "Next step: create S3 bucket"
    echo "Usage: $0 create-bucket <bucket-name> ap-northeast-1"
}

function show_credentials() {
    echo "Current AWS S3 credentials:"
    
    if ! kubectl get secret $SECRET_NAME -n $NAMESPACE >/dev/null 2>&1; then
        echo "❌ Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'"
        return 1
    fi
    
    local access_key=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ACCESS_KEY_ID}' | base64 -d)
    local secret_key=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.SECRET_ACCESS_KEY}' | base64 -d)
    
    echo "Access Key: ${access_key:0:12}...${access_key: -4}"
    echo "Secret Key: ${secret_key:0:8}...${secret_key: -4}"
}

function create_bucket() {
    local bucket_name="$1"
    local region="${2:-us-east-1}"
    
    if [ -z "$bucket_name" ]; then
        echo "Error: Bucket name required"
        echo "Usage: $0 create-bucket <bucket-name> [region]"
        exit 1
    fi
    
    echo "Creating S3 bucket: $bucket_name in region: $region"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install it:"
        echo "   brew install awscli"
        echo "   aws configure"
        return 1
    fi
    
    # Create bucket
    if [ "$region" = "us-east-1" ]; then
        aws s3 mb s3://$bucket_name
    else
        aws s3 mb s3://$bucket_name --region $region
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ Bucket created successfully!"
        echo "Bucket: s3://$bucket_name"
        echo "Region: $region"
        echo ""
        echo "Next: Update cluster configuration with:"
        echo "$0 update-cluster $bucket_name"
    else
        echo "❌ Failed to create bucket"
    fi

    echo "Next step:"
    echo "$0 update_cluster $bucket_name"
}

function test_connection() {
    echo "Testing AWS S3 connection..."
    
    # Check if AWS CLI is configured
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install and configure it."
        return 1
    fi
    
    # Test AWS credentials
    aws sts get-caller-identity > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ AWS credentials are valid"
        aws sts get-caller-identity
    else
        echo "❌ AWS credentials are invalid or not configured"
        echo "Run: aws configure"
        return 1
    fi
    
    # List buckets
    echo ""
    echo "Available S3 buckets:"
    aws s3 ls
}

function update_cluster() {
    local bucket_name="$1"
    
    if [ -z "$bucket_name" ]; then
        echo "Error: Bucket name required"
        echo "Usage: $0 update-cluster <bucket-name>"
        exit 1
    fi
    
    echo "Updating cluster configuration with bucket: $bucket_name"
    
    # Update cluster.yaml with the bucket name
    sed -i.bak "s|s3://your-cnpg-backup-bucket|s3://$bucket_name|g" cluster.yaml
    
    if [ $? -eq 0 ]; then
        echo "✅ Cluster configuration updated!"
        echo "Bucket name: s3://$bucket_name"
        echo ""
        echo "Apply changes with:"
        echo "kubectl apply -f cluster.yaml"
    else
        echo "❌ Failed to update cluster configuration"
    fi
}

# Main script logic
case "$1" in
    setup-credentials)
        setup_credentials "$2" "$3"
        ;;
    show-credentials)
        show_credentials
        ;;
    create-bucket)
        create_bucket "$2" "$3"
        ;;
    test-connection)
        test_connection
        ;;
    update-cluster)
        update_cluster "$2"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
