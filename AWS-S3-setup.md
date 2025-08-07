# AWS S3 Backup Configuration for CNPG

This guide explains how to configure CloudNativePG (CNPG) backups to use AWS S3 instead of MinIO.

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

### 2. Set up AWS credentials for CNPG
```bash
# Replace with your actual AWS credentials
./aws-s3-helper.sh setup-credentials <access-key> <secret-key>
```

### 3. Create S3 bucket
```bash
# Create bucket (replace with your bucket name and preferred region)
./aws-s3-helper.sh create-bucket cnpg-backup-510 ap-northeast-1
```

### 4. Update cluster configuration
```bash
# Update cluster.yaml with your bucket name
./aws-s3-helper.sh update-cluster cnpg-backup-510
```

### 5. Apply configuration
```bash
# Deploy the backup configuration
./setup-aws-s3-backup.sh
```

## 🔧 Manual Configuration

### AWS IAM Policy
Create an IAM user with this policy for CNPG backups:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::your-cnpg-backup-bucket",
                "arn:aws:s3:::your-cnpg-backup-bucket/*"
            ]
        }
    ]
}
```

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

- `aws-s3-backup-storage.yaml` - AWS credentials secret
- `cluster.yaml` - Updated for AWS S3 backup
- `setup-aws-s3-backup.sh` - Setup script
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
aws s3 ls s3://your-cnpg-backup-bucket/cluster-example/ --recursive
```

### Scheduled backups
Configured in `backup-schedule.yaml` - runs hourly by default.

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
    destinationPath: "s3://primary-backup-bucket/cluster-example"
  secondaryBarmanObjectStore:
    destinationPath: "s3://secondary-backup-bucket/cluster-example"
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
kubectl logs -n default cluster-example-1

# Check backup job logs
kubectl logs -n default job/backup-cluster-example-xxx

# Test S3 access from pod
kubectl exec -it cluster-example-1 -n default -- barman-cloud-backup-list s3://your-bucket cluster-example
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
