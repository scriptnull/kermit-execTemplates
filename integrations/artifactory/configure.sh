#!/bin/bash -e

artifactory_configure() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "artifactory" ]; then
    local url=$(eval echo "$"int_"$integrationName"_url)
    local user=$(eval echo "$"int_"$integrationName"_user)
    local apiKey=$(eval echo "$"int_"$integrationName"_apikey)

    jfrog rt config --url "$url" --user "$user" --apikey "$apiKey" --interactive=false $integrationName
    jfrog rt use $integrationName
  fi
}

execute_command "artifactory_configure %%context.name%%"
