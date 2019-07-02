#!/bin/bash -e

gcloud_auth() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "gcloudKey" ]; then
    local jsonKey=$(eval echo "$"int_"$integrationName"_jsonKey)
    local projectId="$( echo "$jsonKey" | jq -r '.project_id' )"

    mkdir -p $step_tmp_dir/$intMasterName
    local keyFile="$step_tmp_dir/$intMasterName/$integrationName.json"
    touch $keyFile
    echo "$jsonKey" > $keyFile
    gcloud -q auth activate-service-account --key-file "$keyFile"
    gcloud config set project "$projectId"
  fi
}

execute_command "gcloud_auth %%context.name%%"
