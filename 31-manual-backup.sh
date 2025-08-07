#!/bin/bash
# create manual backups for CNPG cluster with AWS S3

NAMESPACE=default
CLUSTER_NAME=cluster-example
BUCKET_NAME=cnpg-backup-510

echo "=== CNPG Manual Backup Tool (AWS S3) ==="
echo ""

# Check if cluster exists and is ready
echo "🔍 Checking cluster status..."
if kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    STATUS=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    echo "✅ Cluster '$CLUSTER_NAME' found with status: $STATUS"
    
    if [ "$STATUS" != "Cluster in healthy state" ]; then
        echo "⚠️  Cluster is not in healthy state. Backup may fail."
    fi
else
    echo "❌ Cluster '$CLUSTER_NAME' not found in namespace '$NAMESPACE'"
    echo "   Available clusters:"
    kubectl get clusters -n "$NAMESPACE" 2>/dev/null || echo "   None found"
    exit 1
fi
echo ""

# Generate unique backup name with timestamp
BACKUP_NAME="manual-$(date +%y%m%d-%H%M)"
echo "📦 Creating manual backup: $BACKUP_NAME"
echo ""

# Create the backup resource
cat <<EOF | kubectl apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Backup
metadata:
  name: $BACKUP_NAME
  namespace: $NAMESPACE
spec:
  cluster:
    name: $CLUSTER_NAME
EOF

if [ $? -eq 0 ]; then
    echo "✅ Backup '$BACKUP_NAME' created successfully"
else
    echo "❌ Failed to create backup"
    exit 1
fi
echo ""

# Monitor backup progress
echo "⏳ Monitoring backup progress..."
echo "   (This may take several minutes depending on database size)"
echo ""

# Wait for backup to complete (with timeout)
TIMEOUT=600  # 10 minutes
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get backup "$BACKUP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    
    case "$STATUS" in
        "completed")
            echo "🎉 Backup completed successfully!"
            break
            ;;
        "failed")
            echo "❌ Backup failed!"
            echo ""
            echo "📋 Backup details:"
            kubectl describe backup "$BACKUP_NAME" -n "$NAMESPACE"
            exit 1
            ;;
        "running")
            echo "⏳ Backup in progress... (${ELAPSED}s elapsed)"
            ;;
        *)
            echo "📊 Backup status: $STATUS (${ELAPSED}s elapsed)"
            ;;
    esac
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "⏰ Backup timed out after ${TIMEOUT} seconds"
    echo "   Check backup status manually:"
    echo "   kubectl get backup $BACKUP_NAME -n $NAMESPACE"
fi

echo ""
echo "📋 Final backup details:"
kubectl get backup "$BACKUP_NAME" -n "$NAMESPACE" -o wide

echo ""
echo "📊 All backups for cluster '$CLUSTER_NAME':"
kubectl get backups -n "$NAMESPACE" --selector=cnpg.io/cluster="$CLUSTER_NAME" 2>/dev/null || kubectl get backups -n "$NAMESPACE"

echo ""
echo "🗂️  To view backup files in S3, run:"
echo "   ./31-list-backups.sh"
echo ""
echo "📋 Backup information:"
echo "   Name:      $BACKUP_NAME"
echo "   Cluster:   $CLUSTER_NAME"
echo "   Namespace: $NAMESPACE"
echo "   S3 Bucket: $BUCKET_NAME"
echo ""
echo "🔧 Useful commands:"
echo "   # View backup details"
echo "   kubectl describe backup $BACKUP_NAME -n $NAMESPACE"
echo ""
echo "   # View backup logs"
echo "   kubectl logs -n $NAMESPACE -l cnpg.io/backup=$BACKUP_NAME"
echo ""
echo "   # Delete this backup"
echo "   kubectl delete backup $BACKUP_NAME -n $NAMESPACE"
