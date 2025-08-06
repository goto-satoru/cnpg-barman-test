#!/usr/bin/env bash
#
# Copyright The CloudNativePG Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -eu

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
cd "${git_repo_root}"

$CONTAINER_PROVIDER rm minio-eu -f ||:
$CONTAINER_PROVIDER rm minio-us -f ||:
kind delete cluster --name k8s-eu ||:
kind delete cluster --name k8s-us ||:
rm -fr minio-eu/* minio-eu/.minio.sys ||:
rm -fr minio-us/* minio-us/.minio.sys ||:
rm -f k8s/kube-config.yaml
