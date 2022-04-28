#! /usr/bin/env bash

set -euo pipefail

GIT_TAG="v2022-04-27"
NODE_TAG="1.34.1"

DOCKER_TAG=`echo "${GIT_TAG##v}" | sed -e s/-0/-/g -e s/-/./g`

echo "Updating docker-compose.yml with WALLET:$DOCKER_TAG, NODE:$NODE_TAG"
sed -i "s|inputoutput/cardano-wallet:.*|inputoutput/cardano-wallet:$DOCKER_TAG|" docker-compose.yml
sed -i "s|inputoutput/cardano-node:.*|inputoutput/cardano-node:$NODE_TAG|" docker-compose.yml
echo ""

echo "Updating Ikar version to $GIT_TAG"
sed -i "s|'.*' #version|'$GIT_TAG' #version|" ./helpers/app_helpers.rb
sed -i "s|piotrstachyra/icarus:.*|piotrstachyra/icarus:$GIT_TAG|" docker-compose.yml
echo ""

read -p "Do you want to create a commit (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  msg="Bump version to wallet/ikar: $GIT_TAG and node:$NODE_TAG"
  git diff --quiet || git commit -am "$msg"
fi
