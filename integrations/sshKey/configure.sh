#!/bin/bash -e

add_key() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "sshKey" ]; then
    local sshPrivateKeyVar="int_""$integrationName""_privateKey"
    local sshPrivateKey=$(echo "${!sshPrivateKeyVar}")
    local sshPublicKey=$(eval echo "$"int_"$integrationName"_publicKey)

    mkdir -p ~./ssh
    echo "$sshPrivateKey" > ~/.ssh/$integrationName
    echo "$sshPublicKey" > ~/.ssh/"$integrationName".pub
    chmod 600 ~/.ssh/$integrationName
    chmod 600 ~/.ssh/$integrationName.pub
  fi
}

execute_command "add_key %%context.name%%"
