#!/bin/bash -e

gcloud_revoke() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "gcloudKey" ]; then
    local jsonKey=$(eval echo "$"int_"$integrationName"_jsonKey)
    local email="$( echo "$jsonKey" | jq -r '.client_email' )"
    echo "$email"
    gcloud auth revoke $email
  fi
}

echo "gcloud_revoke %%context.name%%"
gcloud_revoke "%%context.name%%"
