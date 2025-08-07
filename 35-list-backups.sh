#!/bin/bash
# list backups on AWS S3

# Configuration
NAMESPACE=default
BUCKET_NAME="cnpg-backup-510"
CLUSTER_NAME="example1"
SECRET_NAME="backup-storage-creds"

# Extract AWS credentials from Kubernetes secret
echo "=== Extracting AWS credentials from Kubernetes secret ==="
ACCESS_KEY=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.data.ACCESS_KEY_ID' | base64 -d 2>/dev/null)
SECRET_KEY=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.data.SECRET_ACCESS_KEY' | base64 -d 2>/dev/null)

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo "❌ Failed to extract AWS credentials from secret '$SECRET_NAME' in namespace '$NAMESPACE'"
    echo "   Make sure the secret exists and contains ACCESS_KEY_ID and SECRET_ACCESS_KEY"
    exit 1
fi

echo "✅ AWS credentials extracted successfully"
echo "   Access Key ID: ${ACCESS_KEY:0:8}..."
echo ""

echo "=== CNPG AWS S3 Backup Listing Tool ==="
echo ""

# Check if AWS CLI is installed
if command -v aws &> /dev/null; then
    echo "Using AWS CLI..."
    
    # Set AWS credentials for this session
    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    export AWS_DEFAULT_REGION="us-east-1"  # Change if your bucket is in a different region
    
    echo "📁 Testing S3 connection..."
    if aws s3 ls s3://$BUCKET_NAME/ > /dev/null 2>&1; then
        echo "✅ Connected to AWS S3 bucket: $BUCKET_NAME"
    else
        echo "❌ Failed to connect to AWS S3 bucket: $BUCKET_NAME"
        echo "   Check your AWS credentials and bucket name"
        exit 1
    fi
    echo ""
    
    echo "📁 Bucket root contents:"
    aws s3 ls s3://$BUCKET_NAME/ 2>/dev/null || echo "❌ Bucket '$BUCKET_NAME' is empty"
    echo ""
    
    echo "📁 Cluster backup directory (s3://$BUCKET_NAME/$CLUSTER_NAME/):"
    aws s3 ls s3://$BUCKET_NAME/$CLUSTER_NAME/ 2>/dev/null || echo "❌ No backups found for cluster '$CLUSTER_NAME'"
    echo ""
    
    echo "📁 All backup files (recursive):"
    aws s3 ls s3://$BUCKET_NAME/$CLUSTER_NAME/ --recursive 2>/dev/null || echo "❌ No backup files found"
    echo ""
    
    kubectl get backups -n $NAMESPACE
    # echo "📁 WAL archive files:"
    # aws s3 ls s3://$BUCKET_NAME/$CLUSTER_NAME/wals/ --recursive 2>/dev/null || echo "❌ No WAL files found"
    # echo ""
    
    # echo "📁 Base backup files:"
    # aws s3 ls s3://$BUCKET_NAME/$CLUSTER_NAME/base/ --recursive 2>/dev/null || echo "❌ No base backup files found"

else
    echo "❌ AWS CLI not found"
    echo ""
    echo "Install AWS CLI:"
    echo "  macOS: brew install awscli"
    echo "  Linux: sudo apt-get install awscli  # or sudo yum install awscli"
    echo ""
    echo "Then re-run this script."
    exit 1
fi

echo ""
echo "=== Configuration Used ==="
echo "AWS S3 Bucket: $BUCKET_NAME"
echo "Cluster Name:  $CLUSTER_NAME"
echo "Namespace:     $NAMESPACE"
echo "Secret:        $SECRET_NAME"
echo ""
echo "💡 Commands to check CNPG backup status:"
echo "   kubectl get clusters -n $NAMESPACE"
echo "   kubectl get backups -n $NAMESPACE"
echo "   kubectl get scheduledbackups -n $NAMESPACE"
echo ""
echo "🔧 Manual credential extraction:"
echo "   kubectl get secret $SECRET_NAME -n $NAMESPACE -o json | jq -r '.data.ACCESS_KEY_ID' | base64 -d && echo"
echo "   kubectl get secret $SECRET_NAME -n $NAMESPACE -o json | jq -r '.data.SECRET_ACCESS_KEY' | base64 -d && echo"
