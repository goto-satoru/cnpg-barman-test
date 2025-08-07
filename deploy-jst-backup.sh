#!/bin/bash
# Deploy JST-based scheduled backup using CronJob

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

echo -e "${BLUE}=== Deploy JST Scheduled Backup CronJob ===${NC}"
echo ""

print_info "This will create a CronJob that generates backups with JST timestamps"
print_info "Backup names will be: example1-jst-YYYYMMDDHHMMSS (JST time)"
echo ""

# Check if CronJob already exists
if kubectl get cronjob jst-backup-cronjob -n "$NAMESPACE" > /dev/null 2>&1; then
    print_warning "CronJob 'jst-backup-cronjob' already exists!"
    read -p "Do you want to delete and recreate it? (y/N): " CONFIRM
    if [[ $CONFIRM =~ ^[Yy]$ ]]; then
        print_info "Deleting existing CronJob..."
        kubectl delete cronjob jst-backup-cronjob -n "$NAMESPACE"
    else
        print_info "Deployment cancelled"
        exit 0
    fi
fi

# Apply the CronJob
print_info "Deploying JST backup CronJob..."
kubectl apply -f jst-scheduled-backup-cronjob.yaml

if [ $? -eq 0 ]; then
    print_success "JST backup CronJob deployed successfully"
else
    print_error "Failed to deploy CronJob"
    exit 1
fi

echo ""
print_info "CronJob Details:"
kubectl get cronjob jst-backup-cronjob -n "$NAMESPACE" -o wide

echo ""
print_info "Schedule: Daily at midnight JST (15:00 UTC)"
print_info "Backup naming: example1-jst-YYYYMMDDHHMMSS (JST timestamps)"
echo ""

print_success "JST scheduled backup is now active!"
echo ""
echo "🔧 Useful commands:"
echo "   # Check CronJob status"
echo "   kubectl get cronjob jst-backup-cronjob -n $NAMESPACE"
echo ""
echo "   # View CronJob logs"
echo "   kubectl logs -l job-name=jst-backup-cronjob -n $NAMESPACE"
echo ""
echo "   # List JST backups"
echo "   kubectl get backups -n $NAMESPACE -l backup-type=scheduled-jst"
echo ""
echo "   # Manually trigger a backup job"
echo "   kubectl create job --from=cronjob/jst-backup-cronjob manual-jst-backup-\$(date +%s) -n $NAMESPACE"
echo ""
echo "   # Disable the old UTC scheduled backup"
echo "   kubectl patch scheduledbackup example1-jst -n $NAMESPACE -p '{\"spec\":{\"suspend\":true}}'"
