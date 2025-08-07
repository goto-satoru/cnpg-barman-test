#!/bin/bash
# Create manual backup with JST timestamp

CLUSTER_NAME="example1"
NAMESPACE="default"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

echo -e "${BLUE}=== CNPG Manual Backup with JST Timestamp ===${NC}"
echo ""

# Generate JST timestamp
# Get current time in JST (UTC+9)
JST_TIMESTAMP=$(TZ='Asia/Tokyo' date '+%Y%m%d%H%M%S')
BACKUP_NAME="${CLUSTER_NAME}-jst-${JST_TIMESTAMP}"

print_info "Creating backup with JST timestamp..."
print_info "Cluster: $CLUSTER_NAME"
print_info "Backup Name: $BACKUP_NAME"
print_info "JST Time: $(TZ='Asia/Tokyo' date '+%Y-%m-%d %H:%M:%S %Z')"
print_info "UTC Time: $(date -u '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Create backup YAML
BACKUP_YAML="/tmp/backup-jst-${JST_TIMESTAMP}.yaml"

cat > "$BACKUP_YAML" << EOF
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Backup
metadata:
  name: $BACKUP_NAME
  namespace: $NAMESPACE
  labels:
    backup-type: "manual-jst"
    backup-time-jst: "$JST_TIMESTAMP"
    cluster: "$CLUSTER_NAME"
spec:
  cluster:
    name: $CLUSTER_NAME
EOF

print_info "Backup configuration:"
cat "$BACKUP_YAML"
echo ""

read -p "Proceed with backup creation? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    print_info "Backup cancelled"
    rm -f "$BACKUP_YAML"
    exit 0
fi

# Create the backup
print_info "Creating backup..."
kubectl apply -f "$BACKUP_YAML"

if [ $? -eq 0 ]; then
    print_success "Backup '$BACKUP_NAME' created successfully"
else
    print_error "Failed to create backup"
    rm -f "$BACKUP_YAML"
    exit 1
fi

# Monitor backup progress
print_info "Monitoring backup progress..."
echo ""

TIMEOUT=600  # 10 minutes
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get backup "$BACKUP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    
    case "$STATUS" in
        "completed")
            print_success "Backup completed successfully!"
            break
            ;;
        "running")
            echo "🔄 Backup in progress... (${ELAPSED}s elapsed)"
            ;;
        "failed")
            print_error "Backup failed!"
            kubectl describe backup "$BACKUP_NAME" -n "$NAMESPACE"
            rm -f "$BACKUP_YAML"
            exit 1
            ;;
        *)
            if [ -n "$STATUS" ]; then
                echo "📊 Status: $STATUS (${ELAPSED}s elapsed)"
            else
                echo "⏳ Waiting for backup to start... (${ELAPSED}s elapsed)"
            fi
            ;;
    esac
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_warning "Backup monitoring timed out after ${TIMEOUT} seconds"
    echo "   Check backup status manually:"
    echo "   kubectl get backup $BACKUP_NAME -n $NAMESPACE"
fi

echo ""
print_info "Final backup status:"
kubectl get backup "$BACKUP_NAME" -n "$NAMESPACE" -o wide

echo ""
print_success "Manual backup with JST timestamp completed!"
echo ""
echo "🔧 Backup Details:"
echo "   Name: $BACKUP_NAME"
echo "   JST Time: $(TZ='Asia/Tokyo' date '+%Y-%m-%d %H:%M:%S %Z')"
echo "   UTC Time: $(date -u '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo "🔧 Useful commands:"
echo "   # Check backup details"
echo "   kubectl describe backup $BACKUP_NAME -n $NAMESPACE"
echo ""
echo "   # List all JST backups"
echo "   kubectl get backups -n $NAMESPACE -l backup-type=manual-jst"
echo ""
echo "   # Use this backup for restore"
echo "   # Update restore configuration with: $BACKUP_NAME"

# Clean up temporary file
rm -f "$BACKUP_YAML"
