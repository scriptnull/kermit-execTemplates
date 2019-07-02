#!/bin/bash -e

remove_key() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "sshKey" ]; then
    mkdir -p ~./ssh
    if [ -f ~/.ssh/$integrationName ]; then
      rm ~/.ssh/$integrationName
    fi
    if [ -f ~/.ssh/$integrationName.pub ]; then
      rm ~/.ssh/$integrationName.pub
    fi
  fi
}

echo "remove_key %%context.name%%"
remove_key "%%context.name%%"
