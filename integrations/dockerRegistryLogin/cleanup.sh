#!/bin/bash -e

docker_logout() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "dockerRegistryLogin" ]; then
    local integrationUrl=$(eval echo "$"int_"$integrationName"_url)
  fi

  docker logout "$integrationUrl"
}

echo "docker_logout %%context.name%%"
docker_logout "%%context.name%%"
