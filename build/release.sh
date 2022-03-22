#!/usr/bin/env bash

# Copyright 2015 Google Inc. All rights reserved.
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

set -e

#VERSION=$( git describe --tags --dirty --abbrev=14 | sed -E 's/-([0-9]+)-g/.\1+/' )
## Only allow releases of tagged versions.
#TAGGED='^v[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.?[0-9]*)?$'
#if [[ ! "$VERSION" =~ $TAGGED ]]; then
  #echo "Error: Only tagged versions are allowed for releases" >&2
  #echo "Found: $VERSION" >&2
  #exit 1
#fi

VERSION="v0.44.1-test"

# Don't include hostname with release builds
if ! git_user="$(git config --get user.email)"; then
  echo "Error: git user not set, use:"
  echo "git config user.email <email>"
  exit 1
fi

export BUILD_USER="$git_user"
export BUILD_DATE=$( date +%Y%m%d ) # Release date is only to day-granularity
export VERBOSE=true

# Build the docker image
echo ">> building cadvisor docker image"
gcr_tag="gcr.io/cadvisor/cadvisor:$VERSION"

docker buildx rm cadvisor-builder || true
docker buildx create --name cadvisor-builder
docker buildx use cadvisor-builder
docker buildx build --platform linux/amd64,linux/arm64 -f deploy/Dockerfile -t "${gcr_tag}" --progress plain --push .
docker buildx rm cadvisor-builder

# Build binaries
arches=('amd64' 'arm64')
for arch in "${arches[@]}"; do
  GO_ARCH="$arch" OUTPUT_NAME_WITH_ARCH="true" build/build.sh
done

exit 0
