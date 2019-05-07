#!/bin/bash -e

get_image() {
  local resourceName="$1"
  local resourceId=$(eval echo "$"res_"$resourceName"_resourceId)
  local intMasterName=$(eval echo "$"res_"$resourceName"_masterName)

  if [ "$intMasterName" == "dockerRegistryLogin" ]; then
    local userName=$(eval echo "$"res_"$resourceName"_int_username)
    local password=$(eval echo "$"res_"$resourceName"_int_password)
    local url=$(eval echo "$"res_"$resourceName"_int_url)

    retry_command docker login -u "$userName" -p "$password" "$url"
    echo "Docker login for resource $resourceName was successful"
  elif [ "$intMasterName" == "aws" ]; then

    local accessKeyId=$(eval echo "$"res_"$resourceName"_int_accessKeyId)
    local secretAccessKey=$(eval echo "$"res_"$resourceName"_int_secretAccessKey)
    local region=$(eval echo "$"res_"$resourceName"_region)

    aws configure set aws_access_key_id "$accessKeyId"
    aws configure set aws_secret_access_key "$secretAccessKey"
    aws configure set region "$region"

    retry_command $(aws ecr get-login --no-include-email)
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
