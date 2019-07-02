#!/bin/bash -e

aws_cleanup() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "amazonKeys" ]; then
    unset AWS_SHARED_CREDENTIALS_FILE
    unset AWS_CONFIG_FILE

    if [ -f $step_workspace_dir/.aws/credentials ]; then
      echo "Removing credentials file"
      rm $step_workspace_dir/.aws/credentials
    fi

    if [ -f $step_workspace_dir/.aws/config ]; then
      echo "Removing configuration file"
      rm $step_workspace_dir/.aws/config
    fi
  fi
}

echo "aws_cleanup %%context.name%%"
aws_cleanup "%%context.name%%"
