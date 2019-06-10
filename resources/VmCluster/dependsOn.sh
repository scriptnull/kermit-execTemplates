#!/bin/bash -e

get_vmCluster() {
  local resourceName="$1"
  local integrationAlias=$(eval echo "$"res_"$resourceName"_integrationAlias)
  local intMasterName=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_masterName)

  if [ "$intMasterName" == "sshKey" ]; then
    local sshPrivateKeyVar="res_""$resourceName"_"$integrationAlias""_privateKey"
    local sshPrivateKey=$(echo "${!sshPrivateKeyVar}")
    local sshPublicKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_publicKey)

    mkdir -p ~./ssh
    echo "$sshPrivateKey" > ~/.ssh/$resourceName
    echo "$sshPublicKey" > ~/.ssh/"$resourceName".pub
    chmod 600 ~/.ssh/$resourceName
    chmod 600 ~/.ssh/$resourceName.pub
  fi
  echo "Successfully configured $resourceName"
}

execute_command "get_vmCluster %%context.resourceName%%"
