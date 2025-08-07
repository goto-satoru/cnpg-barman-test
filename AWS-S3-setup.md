# AWS S3 Backup Configuration for CNPG Cluster

This guide explains how to configure CloudNativePG (CNPG) Cluster backups to use AWS S3.

## 📋 Prerequisites

1. **AWS Account** with S3 access
2. **AWS CLI** installed and configured
3. **IAM User** with S3 permissions
4. **S3 Bucket** for storing backups

## 🚀 Quick Setup

### 1. Install AWS CLI
```bash
# macOS
brew install awscli

# Configure AWS CLI
aws configure
```

### 2. Set up AWS credentials for CNPG Cluster
```bash
# Replace with your actual AWS credentials
./aws-s3-helper.sh setup-credentials <access-key> <secret-key>
```

### 3. Create AWS S3 bucket
```bash
# Create bucket (replace with your bucket name and preferred region)
./aws-s3-helper.sh create-bucket cnpg-backup-510 ap-northeast-1
```

### 4. Update cluster configuration manifest
```bash
# Update cluster.yaml with your bucket name
./aws-s3-helper.sh update-cluster cnpg-backup-510
```

### 5. Apply configuration
```bash
# Deploy the backup configuration
./10-setup-backup-s3.sh
```

## 🔧 Manual Configuration

### S3 Bucket Configuration
- **Bucket name**: Choose a unique name (e.g., `cnpg-backups-unique-id`)
- **Region**: Choose your preferred AWS region
- **Versioning**: Enable for backup protection
- **Encryption**: Enable server-side encryption

## 🔍 Verification

### Test AWS connection
```bash
./aws-s3-helper.sh test-connection
```

### Check current credentials
```bash
./aws-s3-helper.sh show-credentials
```

### Check backup status
```bash
./backup-restore-ops.sh backup-status
```

## 📁 File Structure

- `cluster.yaml` - Updated for AWS S3 backup
- `10-setup-backup-s3.sh` - Setup script
- `aws-s3-helper.sh` - Helper script for AWS operations

## 🔄 Backup Operations

### Manual backup
```bash
./backup-restore-ops.sh backup-now
```

### List backups
```bash
./backup-restore-ops.sh list-backups

# Or directly with AWS CLI
aws s3 ls s3://your-cnpg-backup-bucket/example1/ --recursive
```

### Scheduled backups
Configured in `s3-backup-schedule.yaml` - runs hourly by default.

## 🔒 Security Best Practices

1. **Use IAM roles** instead of access keys when possible
2. **Enable S3 bucket encryption**
3. **Enable S3 bucket versioning**
4. **Rotate access keys regularly**
5. **Use least privilege IAM policies**

## 🌍 Multi-Region Setup

For disaster recovery, consider:

```yaml
# In cluster.yaml - add secondary backup location
backup:
  barmanObjectStore:
    destinationPath: "s3://primary-backup-bucket"
  secondaryBarmanObjectStore:
    destinationPath: "s3://secondary-backup-bucket"
```

## ❌ Troubleshooting

### Common Issues

1. **Access Denied**
   - Check IAM permissions
   - Verify bucket policy
   - Ensure credentials are correct

2. **Bucket Not Found**
   - Verify bucket name
   - Check AWS region
   - Ensure bucket exists

3. **Connection Timeout**
   - Check network connectivity
   - Verify AWS endpoints
   - Check firewall rules

### Debug Commands
```bash
# Check CNPG cluster logs
kubectl logs -n default example1-1

# Check backup job logs
kubectl logs -n default job/backup-example1-xxx

# Test S3 access from pod
kubectl exec -it example1-1 -n default -- barman-cloud-backup-list s3://your-bucket example1
```

## 💰 Cost Optimization

- Use **S3 Intelligent Tiering** for automatic cost optimization
- Set up **lifecycle policies** to move old backups to cheaper storage classes
- Consider **S3 Glacier** for long-term backup retention

## 📞 Support

For issues specific to:
- **AWS S3**: Check AWS documentation and support
- **CNPG**: Check CloudNativePG documentation and GitHub issues
- **This setup**: Review logs and error messages above
