# Quick Start with AWS S3

## Configure AWS credentials:

```
./aws-s3-helper.sh setup-credentials YOUR_ACCESS_KEY YOUR_SECRET_KEY
```

## Create S3 bucket

```
./aws-s3-helper.sh create-bucket cnpg-backup-510 ap-northeast-1
```

## Update cluster config

```
./aws-s3-helper.sh update-cluster cnpg-backup-510
```

## Deploy configuration

```
./setup-aws-s3-backup.sh
```
