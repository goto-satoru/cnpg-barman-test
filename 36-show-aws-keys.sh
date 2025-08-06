#!/bin/sh

NAMESPACE=cnpg
echo ACCESS_KEY_ID:
kubectl get secret backup-storage-creds -n $NAMESPACE -o json | jq -r '.data.ACCESS_KEY_ID' | base64 -d && echo
echo SECRET_ACCESS_KEY:
kubectl get secret backup-storage-creds -n $NAMESPACE -o json | jq -r '.data.SECRET_ACCESS_KEY' | base64 -d && echo
