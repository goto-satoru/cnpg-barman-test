#!/bin/sh

kubectl create namespace postgresql-operator-system
kubectl create secret -n postgresql-operator-system docker-registry edb-pull-secret \
  --docker-server=docker.enterprisedb.com \
  --docker-username=k8s_$EDB_SUBSCRIPTION_PLAN \
  --docker-password=$EDB_SUBSCRIPTION_TOKEN

kubectl apply --server-side -f \
  https://get.enterprisedb.io/pg4k/pg4k-$EDB_SUBSCRIPTION_PLAN-1.26.1.yaml

kubectl create ns cnpg
kubectl create ns barman
