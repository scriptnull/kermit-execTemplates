#!/bin/bash -e

get_image() {
  local resourceName="$1"
  local integrationAlias=$(eval echo "$"res_"$resourceName"_integrationAlias)
  local resourceId=$(eval echo "$"res_"$resourceName"_resourceId)
  local intMasterName=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_masterName)

  if [ "$intMasterName" == "dockerRegistryLogin" ]; then
    local userName=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_username)
    local password=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_password)
    local url=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_url)

    retry_command docker login -u "$userName" -p "$password" "$url"
    echo "Docker login for resource $resourceName was successful"
  elif [ "$intMasterName" == "amazonKeys" ]; then

    local accessKeyId=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_accessKeyId)
    local secretAccessKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_secretAccessKey)
    local region=$(eval echo "$"res_"$resourceName"_region)

    aws configure set aws_access_key_id "$accessKeyId"
    aws configure set aws_secret_access_key "$secretAccessKey"
    aws configure set region "$region"

    retry_command $(aws ecr get-login --no-include-email)
  elif [ "$intMasterName" == "gcloudKey" ]; then
    local jsonKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_jsonKey)
    local projectId="$( echo "$jsonKey" | jq -r '.project_id' )"

    touch key.json
    echo "$jsonKey" > key.json
    gcloud -q auth activate-service-account --key-file "key.json"
    gcloud config set project "$projectId"
    gcloud docker -a
  elif [ "$intMasterName" == "artifactory" ]; then
    local url=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_url)
    local user=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_user)
    local apiKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_apikey)
    jfrog rt config default-server --url "$url" --user "$user" \
      --apikey "$apiKey" --interactive=false
    jfrog rt use default-server
    retry_command docker login -u "$user" -p "$apiKey" "$url"
  fi

  local autoPull=$(eval echo "$"res_"$resourceName"_autoPull)

  if [ -z "$autoPull" ] || "$autoPull" == "true" ; then

    local imageName=$(eval echo "$"res_"$resourceName"_imageName)
    local imageTag=$(eval echo "$"res_"$resourceName"_imageTag)

    retry_command docker pull "$imageName:$imageTag"
    echo "Docker pull for image $imageName:$imageTag was successful"
  fi
}

execute_command "get_image %%context.resourceName%%"
