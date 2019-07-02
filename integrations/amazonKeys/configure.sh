#!/bin/bash -e

aws_configure() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "amazonKeys" ]; then
    export AWS_SHARED_CREDENTIALS_FILE=$step_workspace_dir/.aws/credentials
    export AWS_CONFIG_FILE=$step_workspace_dir/.aws/config

    local accessKeyId=$(eval echo "$"int_"$integrationName"_accessKeyId)
    local secretAccessKey=$(eval echo "$"int_"$integrationName"_secretAccessKey)

    aws configure set aws_access_key_id "$accessKeyId"
    aws configure set aws_secret_access_key "$secretAccessKey"
  fi
}

execute_command "aws_configure %%context.name%%"
