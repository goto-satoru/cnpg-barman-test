#!/bin/bash

# Setup backup and restore for CNPG cluster with AWS S3

echo "Setting up backup and restore for CNPG cluster with AWS S3..."

# Check if kubectl is working
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "Please ensure your cluster is running and kubectl is configured properly"
    exit 1
fi

# 1. Deploy AWS S3 backup storage credentials
echo -e "\n1. Deploying AWS S3 backup storage credentials..."
echo "⚠️  IMPORTANT: Make sure to update aws-s3-backup-storage.yaml with your actual AWS credentials!"
kubectl apply -f aws-s3-backup-storage.yaml

# 2. Apply cluster configuration with backup
echo -e "\n2. Applying cluster configuration with AWS S3 backup..."
echo "⚠️  IMPORTANT: Make sure to update the S3 bucket name in cluster.yaml!"
kubectl apply -f cluster.yaml

# 3. Setup scheduled backups
echo -e "\n3. Setting up scheduled backups..."
if [ -f "backup-schedule.yaml" ]; then
    kubectl apply -f backup-schedule.yaml
else
    echo "   ⚠️  Backup schedule file not found, skipping..."
fi

echo -e "\n✅ AWS S3 backup setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Update AWS credentials in aws-s3-backup-storage.yaml"
echo "2. Create your S3 bucket in AWS Console"
echo "3. Update bucket name in cluster.yaml"
echo "4. Reapply the configuration"
echo ""
echo "🔑 AWS S3 Configuration Required:"
echo "   • S3 Bucket: Create 'your-cnpg-backup-bucket' in AWS"
echo "   • IAM Policy: Ensure your AWS user has S3 permissions"
echo "   • Region: CNPG will use default AWS region from environment"
echo ""
echo "🔍 Check status:"
echo "   kubectl get backup "
echo "   kubectl get scheduledbackup "
echo "   ./backup-restore-ops.sh backup-status"
echo ""
echo "🔄 Manual backup:"
echo "   ./backup-restore-ops.sh backup-now"
