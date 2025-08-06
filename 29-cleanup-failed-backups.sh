#!/bin/bash

# Clean up failed backup resources

echo "Cleaning up failed backup resources..."

# Delete all failed backups
echo "Deleting failed backups..."
kubectl delete backup --all

# Suspend scheduled backup
echo "Suspending scheduled backup..."
kubectl patch scheduledbackup cluster-example-scheduled-backup  -p '{"spec":{"suspend":true}}'

# Apply cluster without backup configuration
echo "Applying cluster configuration without backup..."
kubectl apply -f cluster.yaml

echo "Cleanup complete!"
echo ""
echo "Your cluster should now be running without backup issues."
echo "To re-enable backups later:"
echo "1. Configure external S3 storage"
echo "2. Uncomment backup section in cluster.yaml"
echo "3. Set suspend: false in backup-schedule.yaml"
