#!/bin/bash
# Scheduled backup script for CNPG cluster with AWS S3
# Optimized for cron jobs with logging

# Configuration
NAMESPACE=default
CLUSTER_NAME=example1
BUCKET_NAME=cnpg-backup-510
LOG_DIR="/var/log/cnpg-backups"
LOG_FILE="$LOG_DIR/backup-$(date +%Y%m%d).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to log error and exit
log_error() {
    log "ERROR: $1"
    exit 1
}

log "=== Starting scheduled backup ==="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl command not found"
fi

# Check if cluster exists and is ready
log "Checking cluster status..."
if ! kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    log_error "Cluster '$CLUSTER_NAME' not found in namespace '$NAMESPACE'"
fi

STATUS=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$STATUS" != "Cluster in healthy state" ]; then
    log_error "Cluster is not in healthy state. Status: $STATUS"
fi

log "Cluster '$CLUSTER_NAME' is healthy"

# Generate unique backup name with timestamp
BACKUP_NAME="scheduled-$(date +%Y%m%d-%H%M)"
log "Creating backup: $BACKUP_NAME"

# Create the backup resource
cat <<EOF | kubectl apply -f - >> "$LOG_FILE" 2>&1
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Backup
metadata:
  name: $BACKUP_NAME
  namespace: $NAMESPACE
spec:
  cluster:
    name: $CLUSTER_NAME
EOF

if [ $? -ne 0 ]; then
    log_error "Failed to create backup resource"
fi

log "Backup '$BACKUP_NAME' created successfully"

# Monitor backup progress with timeout
TIMEOUT=600  # 10 minutes
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get backup "$BACKUP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    
    case "$STATUS" in
        "completed")
            log "Backup completed successfully!"
            break
            ;;
        "failed")
            log_error "Backup failed!"
            ;;
        "running")
            log "Backup in progress... (${ELAPSED}s elapsed)"
            ;;
        *)
            log "Backup status: $STATUS (${ELAPSED}s elapsed)"
            ;;
    esac
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    log_error "Backup timed out after ${TIMEOUT} seconds"
fi

# Get final backup details
kubectl get backup "$BACKUP_NAME" -n "$NAMESPACE" -o wide >> "$LOG_FILE" 2>&1

# Cleanup old backups (keep last 24 backups = 24 hours)
log "Cleaning up old scheduled backups..."
OLD_BACKUPS=$(kubectl get backups -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp -o name | grep "backup/scheduled-" | head -n -24)
if [ -n "$OLD_BACKUPS" ]; then
    echo "$OLD_BACKUPS" | xargs kubectl delete >> "$LOG_FILE" 2>&1
    log "Cleaned up old backups"
else
    log "No old backups to clean up"
fi

log "=== Backup completed successfully ==="
log "Backup name: $BACKUP_NAME"
log "Cluster: $CLUSTER_NAME"
log "Namespace: $NAMESPACE"
log "S3 Bucket: $BUCKET_NAME"

exit 0
