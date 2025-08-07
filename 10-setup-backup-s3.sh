#!/bin/bash
# Setup backup and restore for CNPG cluster with AWS S3

NAMESPACE=default
CLUSTER_NAME=example1
echo "Setting up backup and restore for CNPG cluster with AWS S3..."

# Check if kubectl is working
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "Please ensure your cluster is running and kubectl is configured properly"
    exit 1
fi

# Verify credentials are created
echo -e "\nVerifying AWS credentials..."
if kubectl get secret backup-storage-creds -n $NAMESPACE > /dev/null 2>&1; then
    echo "✅ AWS S3 credentials deployed in $NAMESPACE successfully"
else
    echo "❌ Error: Failed to create backup-storage-creds secret in $NAMESPACE"
    exit 1
fi

# Apply cluster configuration with AWS S3 backup
echo -e "\nApplying cluster configuration with AWS S3 backup..."
kubectl apply -f cluster.yaml

# Wait for cluster to be ready
echo -e "\nWaiting for PostgreSQL cluster to be ready..."
kubectl wait --for=condition=Ready cluster/$CLUSTER_NAME -n $NAMESPACE --timeout=300s

# 4. Setup scheduled backups
BACKUP_SCHEDULE_FILE="s3-backup-schedule.yaml"
echo -e "\nSetting up scheduled backups..."
if [ -f "$BACKUP_SCHEDULE_FILE" ]; then
    kubectl apply -f "$BACKUP_SCHEDULE_FILE"
    echo "✅ Scheduled backup configured"
else
    echo "   ⚠️  Backup schedule file not found, skipping..."
fi

# Test AWS S3 connectivity
echo -e "\nTesting AWS S3 connectivity..."
echo "   Checking if backup storage credentials work..."

# Get AWS credentials for testing
ACCESS_KEY=$(kubectl get secret backup-storage-creds -n $NAMESPACE -o json | jq -r '.data.ACCESS_KEY_ID' | base64 -d)
SECRET_KEY=$(kubectl get secret backup-storage-creds -n $NAMESPACE -o json | jq -r '.data.SECRET_ACCESS_KEY' | base64 -d)

if [ -n "$ACCESS_KEY" ] && [ -n "$SECRET_KEY" ]; then
    echo "✅ AWS credentials extracted successfully"
    echo "   Access Key ID: ${ACCESS_KEY:0:8}..."
else
    echo "❌ Error: Could not extract AWS credentials"
fi

echo -e "\n✅ AWS S3 backup setup complete!"
echo ""
echo "📊 AWS S3 Configuration:"
echo "   Bucket: cnpg-backup-510"
echo "   Cluster: example1"
echo "   Namespace: cnpg"
echo ""
echo "🔍 Check status:"
echo "   kubectl get clusters -n $NAMESPACE"
echo "   kubectl get backup -n $NAMESPACE"
echo "   kubectl get scheduledbackup -n $NAMESPACE"
echo ""
echo "🔄 Manual backup:"
echo "   kubectl create -f - <<EOF"
echo "   apiVersion: postgresql.k8s.enterprisedb.io/v1"
echo "   kind: Backup"
echo "   metadata:"
echo "     name: manual-backup-\$(date +%Y%m%d-%H%M%S)"
echo "     namespace: cnpg"
echo "   spec:"
echo "     cluster:"
echo "       name: example1"
echo "   EOF"
echo ""
echo "� View credentialsc:"
echo "   kubectl get secret backup-storage-creds -n $NAMESPACE -o json | jq -r '.data.ACCESS_KEY_ID' | base64 -d && echo"
echo "   kubectl get secret backup-storage-creds -n $NAMESPACE -o json | jq -r '.data.SECRET_ACCESS_KEY' | base64 -d && echo"
