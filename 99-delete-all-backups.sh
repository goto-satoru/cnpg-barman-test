#!/bin/bash
# Delete all CNPG backups from Kubernetes and S3

NAMESPACE=default
CLUSTER_NAME=example1
BUCKET_NAME=cnpg-backup-510

echo "=== CNPG Backup Cleanup Tool ==="
echo ""

# Show current backups
echo "📋 Current backups in Kubernetes:"
kubectl get backups -n "$NAMESPACE"
echo ""

# Confirm deletion
echo "⚠️  This will delete ALL backups for cluster '$CLUSTER_NAME'"
echo "   This action cannot be undone!"
echo ""
echo "Do you want to continue? (y/N)"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Backup deletion cancelled"
    exit 0
fi

echo ""
echo "🗑️  Starting backup cleanup..."

# Delete all Kubernetes backup resources
echo "Deleting Kubernetes backup resources..."
BACKUP_COUNT=$(kubectl get backups -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 0 ]; then
    kubectl delete backups --all -n "$NAMESPACE"
    echo "✅ Deleted $BACKUP_COUNT backup resources from Kubernetes"
else
    echo "ℹ️  No backup resources found in Kubernetes"
fi

# Delete scheduled backups
echo ""
echo "Checking for scheduled backups..."
SCHEDULED_COUNT=$(kubectl get scheduledbackups -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$SCHEDULED_COUNT" -gt 0 ]; then
    kubectl delete scheduledbackups --all -n "$NAMESPACE"
    echo "✅ Deleted $SCHEDULED_COUNT scheduled backup resources"
else
    echo "ℹ️  No scheduled backup resources found"
fi

# Check if AWS CLI is available for S3 cleanup
if command -v aws &> /dev/null; then
    echo ""
    echo "🗂️  Checking S3 bucket for backup files..."
    
    # List files in S3 bucket
    S3_FILES=$(aws s3 ls s3://"$BUCKET_NAME"/"$CLUSTER_NAME"/ --recursive 2>/dev/null | wc -l)
    
    if [ "$S3_FILES" -gt 0 ]; then
        echo "Found $S3_FILES files in S3 bucket"
        echo ""
        echo "Do you also want to delete all backup files from S3? (y/N)"
        read -r s3_response
        
        if [[ "$s3_response" =~ ^[Yy]$ ]]; then
            echo "Deleting S3 backup files..."
            aws s3 rm s3://"$BUCKET_NAME"/"$CLUSTER_NAME"/ --recursive
            echo "✅ Deleted all backup files from S3"
        else
            echo "ℹ️  S3 backup files kept"
        fi
    else
        echo "ℹ️  No backup files found in S3 bucket"
    fi
else
    echo ""
    echo "⚠️  AWS CLI not found. Cannot clean up S3 backup files."
    echo "   To manually delete S3 files, run:"
    echo "   aws s3 rm s3://$BUCKET_NAME/$CLUSTER_NAME/ --recursive"
fi

# Check for any remaining backup jobs
echo ""
echo "Checking for backup jobs..."
JOBS=$(kubectl get jobs -n "$NAMESPACE" -l cnpg.io/cluster="$CLUSTER_NAME" --no-headers 2>/dev/null | wc -l)
if [ "$JOBS" -gt 0 ]; then
    kubectl delete jobs -n "$NAMESPACE" -l cnpg.io/cluster="$CLUSTER_NAME"
    echo "✅ Deleted $JOBS backup jobs"
else
    echo "ℹ️  No backup jobs found"
fi

echo ""
echo "🎉 Backup cleanup completed!"
echo ""
echo "📊 Final status:"
kubectl get backups -n "$NAMESPACE" 2>/dev/null || echo "No backups remaining"

echo ""
echo "💡 To verify S3 cleanup (if performed):"
echo "   aws s3 ls s3://$BUCKET_NAME/$CLUSTER_NAME/ --recursive"
echo ""
echo "💡 To create new backups:"
echo "   ./31-manual-backup.sh"
