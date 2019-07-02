#!/bin/bash -e

docker_login() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "dockerRegistryLogin" ]; then
    local integrationUrl=$(eval echo "$"int_"$integrationName"_url)
    local integrationUsername=$(eval echo "$"int_"$integrationName"_username)
    local integrationPassword=$(eval echo "$"int_"$integrationName"_password)
  fi

  docker login -u "$integrationUsername" -p "$integrationPassword" "$integrationUrl"
}

execute_command "docker_login %%context.name%%"
