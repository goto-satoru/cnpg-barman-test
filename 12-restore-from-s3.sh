#!/bin/bash
# restore CNPG cluster from AWS S3 backup

BUCKET_NAME="cnpg-backup-510"
SOURCE_CLUSTER_NAME="example1"
RESTORE_CLUSTER_NAME="restored"
NAMESPACE="default"
SECRET_NAME="backup-storage-creds"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CNPG Restore from AWS S3 Backup ===${NC}"
echo ""

# Function to print colored messages
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if credentials exist
print_info "Checking AWS S3 credentials..."
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    print_success "AWS credentials found"
else
    print_error "AWS credentials secret '$SECRET_NAME' not found in namespace '$NAMESPACE'"
    echo "Create the secret first with:"
    echo "kubectl apply -f aws-s3-backup-storage.yaml"
    exit 1
fi

# List available backups
print_info "Listing available backups..."
echo ""
echo "📋 Available backups for cluster '$SOURCE_CLUSTER_NAME':"
kubectl get backups -n "$NAMESPACE" -o wide 2>/dev/null | grep "$SOURCE_CLUSTER_NAME" | head -10

# Get the latest completed backup
LATEST_BACKUP=$(kubectl get backups -n "$NAMESPACE" | tail -1)

if [ -z "$LATEST_BACKUP" ]; then
    print_error "No completed backups found for cluster '$SOURCE_CLUSTER_NAME'"
    echo ""
    echo "Create a backup first:"
    echo "./31-manual-backup.sh"
    exit 1
fi

print_success "Latest completed backup: $LATEST_BACKUP"
echo ""

# Prompt for restore options
echo "🔧 Restore Options:"
echo "1. Restore to latest backup (Point-in-time: latest)"
echo "2. Restore to specific backup"
echo "3. Point-in-time recovery (PITR) to specific timestamp"
echo ""
read -p "Choose option (1-3): " RESTORE_OPTION

case $RESTORE_OPTION in
    1)
        RESTORE_TYPE="latest"
        BACKUP_NAME="$LATEST_BACKUP"
        ;;
    2)
        echo ""
        echo "Available backups:"
        kubectl get backups -n "$NAMESPACE" -o jsonpath='{.items[?(@.spec.cluster.name=="'$SOURCE_CLUSTER_NAME'")].metadata.name}' | tr ' ' '\n'
        echo ""
        read -p "Enter backup name: " BACKUP_NAME
        RESTORE_TYPE="backup"
        ;;
    3)
        read -p "Enter timestamp (YYYY-MM-DD HH:MM:SS): " RESTORE_TIMESTAMP
        RESTORE_TYPE="pitr"
        BACKUP_NAME="$LATEST_BACKUP"
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

# Check if restore cluster already exists
if kubectl get cluster "$RESTORE_CLUSTER_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    print_warning "Cluster '$RESTORE_CLUSTER_NAME' already exists!"
    read -p "Do you want to delete it and create a new one? (y/N): " CONFIRM
    if [[ $CONFIRM =~ ^[Yy]$ ]]; then
        print_info "Deleting existing cluster..."
        kubectl delete cluster "$RESTORE_CLUSTER_NAME" -n "$NAMESPACE"
        # Wait for cluster to be fully deleted
        print_info "Waiting for cluster deletion to complete..."
        while kubectl get cluster "$RESTORE_CLUSTER_NAME" -n "$NAMESPACE" > /dev/null 2>&1; do
            sleep 5
        done
        print_success "Cluster deleted"
    else
        print_info "Restore cancelled"
        exit 0
    fi
fi

echo ""
print_info "Creating restore cluster configuration..."

# Create restore cluster YAML
RESTORE_YAML="/tmp/restore-cluster.yaml"

cat > "$RESTORE_YAML" << EOF
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: $RESTORE_CLUSTER_NAME
  namespace: $NAMESPACE
spec:
  instances: 3
  storage:
    size: 1Gi
  
  # Bootstrap from backup
  bootstrap:
    recovery:
      # Source cluster configuration
      source: cluster-backup-source
EOF

# Add recovery options based on restore type
case $RESTORE_TYPE in
    "latest")
        echo "      # Restore to latest available backup" >> "$RESTORE_YAML"
        ;;
    "backup")
        cat >> "$RESTORE_YAML" << EOF
      # Restore to specific backup
      backup:
        name: $BACKUP_NAME
EOF
        ;;
    "pitr")
        cat >> "$RESTORE_YAML" << EOF
      # Point-in-time recovery
      recoveryTarget:
        targetTime: "$RESTORE_TIMESTAMP"
EOF
        ;;
esac

# Add external cluster configuration
cat >> "$RESTORE_YAML" << EOF

  # External cluster definition for restore
  externalClusters:
  - name: cluster-backup-source
    barmanObjectStore:
      # CRITICAL: serverName must match the original cluster that created the backup
      serverName: "$SOURCE_CLUSTER_NAME"
      destinationPath: "s3://$BUCKET_NAME/"
      s3Credentials:
        accessKeyId:
          name: $SECRET_NAME
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: $SECRET_NAME
          key: SECRET_ACCESS_KEY
EOF

echo ""
print_info "Restore Configuration:"
echo "  Source Cluster: $SOURCE_CLUSTER_NAME"
echo "  Restore Cluster: $RESTORE_CLUSTER_NAME"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  Restore Type: $RESTORE_TYPE"
if [ "$RESTORE_TYPE" = "backup" ]; then
    echo "  Backup Name: $BACKUP_NAME"
elif [ "$RESTORE_TYPE" = "pitr" ]; then
    echo "  Target Time: $RESTORE_TIMESTAMP"
fi
echo ""

read -p "Proceed with restore? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    print_info "Restore cancelled"
    rm -f "$RESTORE_YAML"
    exit 0
fi

# Apply the restore cluster
print_info "Creating restore cluster..."
kubectl apply -f "$RESTORE_YAML"

if [ $? -eq 0 ]; then
    print_success "Restore cluster '$RESTORE_CLUSTER_NAME' created"
else
    print_error "Failed to create restore cluster"
    rm -f "$RESTORE_YAML"
    exit 1
fi

# Monitor restore progress
echo ""
print_info "Monitoring restore progress..."
echo "  (This may take several minutes depending on backup size)"
echo ""

TIMEOUT=1800  # 30 minutes
ELAPSED=0
INTERVAL=15

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get cluster "$RESTORE_CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    READY_INSTANCES=$(kubectl get cluster "$RESTORE_CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyInstances}' 2>/dev/null)
    INSTANCES=$(kubectl get cluster "$RESTORE_CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.instances}' 2>/dev/null)
    
    case "$STATUS" in
        "Cluster in healthy state")
            print_success "Restore completed successfully!"
            print_success "Cluster is healthy with $READY_INSTANCES/$INSTANCES instances ready"
            
            # Additional verification for restore success
            if kubectl get pods -n "$NAMESPACE" -l cnpg.io/cluster="$RESTORE_CLUSTER_NAME" | grep -q "Running"; then
                print_success "Primary instance is running and ready"
            fi
            break
            ;;
        "Setting up primary")
            echo "🔄 Setting up primary instance... (${ELAPSED}s elapsed)"
            ;;
        "Creating replicas")
            echo "🔄 Creating replica instances... (${ELAPSED}s elapsed)"
            ;;
        "Cluster in recovery")
            echo "📥 Restoring data from backup... (${ELAPSED}s elapsed)"
            ;;
        *)
            if [ -n "$STATUS" ]; then
                echo "📊 Status: $STATUS ($READY_INSTANCES/$INSTANCES ready) (${ELAPSED}s elapsed)"
            else
                echo "⏳ Waiting for cluster to start... (${ELAPSED}s elapsed)"
            fi
            ;;
    esac
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_warning "Restore monitoring timed out after ${TIMEOUT} seconds"
    echo "   Check restore status manually:"
    echo "   kubectl get cluster $RESTORE_CLUSTER_NAME -n $NAMESPACE"
fi

echo ""
print_info "Final cluster status:"
kubectl get cluster "$RESTORE_CLUSTER_NAME" -n "$NAMESPACE" -o wide

echo ""
print_info "Pods status:"
kubectl get pods -n "$NAMESPACE" -l cnpg.io/cluster="$RESTORE_CLUSTER_NAME"

echo ""
print_success "Restore operation completed!"

# Verify data restoration
echo ""
print_info "Verifying data restoration..."

# Wait a moment for the cluster to be fully ready
sleep 10

# Check if sample data exists
print_info "Checking restored data..."
DATA_COUNT=$(kubectl exec -n "$NAMESPACE" "$RESTORE_CLUSTER_NAME-1" -- psql -U postgres -d app -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ')

if [ $? -eq 0 ] && [ -n "$DATA_COUNT" ] && [ "$DATA_COUNT" -gt 0 ]; then
    print_success "Data verification successful! Found $DATA_COUNT records in users"
else
    print_warning "Data verification: No users found or empty"
    echo "   This might be normal if the original cluster had no sample data"
fi

# Check database list
print_info "Available databases:"
kubectl exec -n "$NAMESPACE" "$RESTORE_CLUSTER_NAME-1" -- psql -U postgres -c "\l" 2>/dev/null | grep -E "^ (app|postgres)"

echo ""
echo "🔧 Useful commands:"
echo "   # Check cluster details"
echo "   kubectl describe cluster $RESTORE_CLUSTER_NAME -n $NAMESPACE"
echo ""
echo "   # Connect to restored database"
echo "   kubectl port-forward svc/$RESTORE_CLUSTER_NAME-rw -n $NAMESPACE 5432:5432"
echo ""
echo "   # Get connection details"
echo "   kubectl get secret $RESTORE_CLUSTER_NAME-app -n $NAMESPACE -o json | jq -r '.data.password' | base64 -d && echo"
echo ""
echo "   # View restore logs"
echo "   kubectl logs -n $NAMESPACE -l cnpg.io/cluster=$RESTORE_CLUSTER_NAME -f"

# Clean up temporary file
rm -f "$RESTORE_YAML"
