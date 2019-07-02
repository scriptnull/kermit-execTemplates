#!/bin/bash -e

artifactory_delete() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "artifactory" ]; then
    jfrog rt config delete $integrationName --interactive=false
  fi
}

echo "artifactory_delete %%context.name%%"
artifactory_delete "%%context.name%%"
