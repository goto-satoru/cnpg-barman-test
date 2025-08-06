# CNPG Backup and Restore Guide

This guide covers backup and restore operations for CloudNativePG (CNPG) clusters, including both PostgreSQL and EDB Postgres Advanced Server.

## Files Overview

- `cluster.yaml` - Main PostgreSQL cluster with backup configuration
- `epas16.yaml` - EDB Postgres Advanced Server cluster with backup configuration
- `backup-storage.yaml` - MinIO deployment for backup storage
- `backup-schedule.yaml` - Scheduled and manual backup definitions
- `restore-cluster.yaml` - Various restore examples
- `setup-backup.sh` - Initial backup setup script
- `backup-restore-ops.sh` - Common backup/restore operations

## Quick Start

### 1. Setup Backup Infrastructure

```bash
# Run the setup script to deploy backup storage and configure backups
./20-setup-backup.sh
```

### 2. Common Operations

```bash
# Create immediate backup
./backup-restore-ops.sh backup-now

# List all backups
./backup-restore-ops.sh list-backups

# Check backup status
./backup-restore-ops.sh backup-status

# Restore from specific backup
./backup-restore-ops.sh restore <backup-name>

# Point-in-time restore
./backup-restore-ops.sh restore-pitr "2024-08-05 14:30:00"
```

## Backup Types

### 1. Continuous WAL Archiving
- Automatically configured when `backup.barmanObjectStore` is set
- WAL files are continuously shipped to object storage
- Enables point-in-time recovery

### 2. Scheduled Backups
- Configured in `backup-schedule.yaml`
- Runs daily at 2 AM by default
- Adjust schedule using cron syntax

### 3. Manual Backups
- On-demand backups using `Backup` resource
- Useful before major changes or migrations

## Restore Scenarios

### 1. Restore from Latest Backup
```yaml
bootstrap:
  recovery:
    source: cluster-backup-source
```

### 2. Restore from Specific Backup
```yaml
bootstrap:
  recovery:
    backup:
      name: cluster-example-manual-backup
```

### 3. Point-in-Time Recovery
```yaml
bootstrap:
  recovery:
    source: cluster-backup-source
    recoveryTarget:
      targetTime: "2024-08-05 14:30:00"
```

### 4. Recovery to Specific LSN
```yaml
bootstrap:
  recovery:
    source: cluster-backup-source
    recoveryTarget:
      targetLSN: "0/1500000"
```

## Storage Configuration

### MinIO (Included)
- Local object storage for development/testing
- Deployed automatically by setup script

### External S3/Compatible Storage
Update the `endpointURL` and credentials in:
- `cluster.yaml`
- `epas16.yaml`
- `backup-storage.yaml`

Example for AWS S3:
```yaml
backup:
  barmanObjectStore:
    destinationPath: "s3://my-backup-bucket/cluster-name"
    s3Credentials:
      accessKeyId:
        name: aws-backup-creds
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: aws-backup-creds
        key: SECRET_ACCESS_KEY
    # Remove endpointURL for AWS S3
```

## Monitoring Backups

### Check Backup Status
```bash
kubectl get backup
kubectl get scheduledbackup 
```

### View Backup Details
```bash
kubectl describe backup <backup-name> 
```

### Check Cluster Backup Status
```bash
kubectl get cluster <cluster-name>  -o yaml
```

## Backup Retention

### WAL Retention
- Configured via `backup.barmanObjectStore.wal.retention`
- Default: 7 days
- Format: `7d`, `168h`, `10080m`

### Data Retention
- Configured via `backup.barmanObjectStore.data.retention`
- Default: 30 days
- Format: `30d`, `720h`, `43200m`

## Troubleshooting

### Common Issues

1. **Backup Fails with S3 Errors**
   - Check credentials and endpoint URL
   - Verify bucket exists and is accessible
   - Check network connectivity to storage

2. **WAL Archiving Not Working**
   - Verify object storage configuration
   - Check cluster logs: `kubectl logs <pod-name> `

3. **Restore Fails**
   - Ensure backup source is correctly configured
   - Check that backup exists and is complete
   - Verify external cluster configuration

### Useful Commands

```bash
# Check cluster status
kubectl get cluster 

# View cluster events
kubectl get events  --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs <pod-name> 

# Check backup storage connectivity
kubectl exec -it <pod-name>  -- barman-wal-archive --test
```

## Security Considerations

1. **Credentials Management**
   - Use Kubernetes secrets for storage credentials
   - Consider using cloud provider IAM roles when possible
   - Rotate credentials regularly

2. **Network Security**
   - Use TLS for object storage connections
   - Restrict network access to backup storage
   - Use private endpoints when available

3. **Encryption**
   - Enable encryption at rest in object storage
   - Consider encrypting backups before upload
   - Use encrypted network connections

## Best Practices

1. **Regular Testing**
   - Test restore procedures regularly
   - Validate backup integrity
   - Document recovery procedures

2. **Monitoring**
   - Set up alerts for backup failures
   - Monitor backup storage usage
   - Track backup and restore times

3. **Documentation**
   - Keep recovery procedures up to date
   - Document backup retention policies
   - Maintain contact information for emergencies

## Advanced Features

### Cross-Region Backups
Configure multiple backup destinations for disaster recovery:

```yaml
backup:
  barmanObjectStore:
    destinationPath: "s3://primary-backup-bucket/cluster"
  secondaryBarmanObjectStore:
    destinationPath: "s3://secondary-backup-bucket/cluster"
```

### Backup Validation
Enable backup validation to ensure integrity:

```yaml
backup:
  barmanObjectStore:
    destinationPath: "s3://backup-bucket/cluster"
    wal:
      retention: "7d"
      validation: true
```

### Custom Backup Scripts
Use hooks for custom backup procedures:

```yaml
backup:
  barmanObjectStore:
    destinationPath: "s3://backup-bucket/cluster"
  hooks:
    preBackup:
      - "echo 'Starting backup'"
    postBackup:
      - "echo 'Backup completed'"
```
