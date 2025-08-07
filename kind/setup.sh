#!/usr/bin/env bash

set -eu

# Ensure prerequisites are met
prereqs="kind kubectl git"
for cmd in $prereqs; do
   if [ -z "$(which $cmd)" ]; then
      echo "Missing command $cmd"
      exit 1
   fi
done

# Look for a supported container provider and use it throughout
containerproviders="docker podman"
for containerProvider in `which $containerproviders`; do
    CONTAINER_PROVIDER=$containerProvider
    break
done

# Ensure we found a supported container provider
if [ -z ${CONTAINER_PROVIDER+x} ]; then
    echo "Missing container provider, supported providers are $containerproviders"
    exit 1
fi

git_repo_root=$(git rev-parse --show-toplevel)
kube_config_path=${git_repo_root}/k8s/kube-config.yaml
kind_config_path=${git_repo_root}/k8s/kind-cluster.yaml

# Setup a separate Kubeconfig
cd "${git_repo_root}"
export KUBECONFIG=${kube_config_path}

# Setup the US Kind Cluster
kind create cluster --config ${kind_config_path} --name my-k8s
# The `node-role.kubernetes.io` label must be set after the node have been created
kubectl label node -l postgres.node.kubernetes.io node-role.kubernetes.io/postgres=
kubectl label node -l infra.node.kubernetes.io node-role.kubernetes.io/infra=
kubectl label node -l app.node.kubernetes.io node-role.kubernetes.io/app=

./kind/info.sh
