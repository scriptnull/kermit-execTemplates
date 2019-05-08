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
  elif [ "$intMasterName" == "gcloudKey" ]; then
    local jsonKey=$(eval echo "$"res_"$resourceName"_int_jsonKey)
    local projectId="$( echo "$jsonKey" | jq -r '.project_id' )"

    touch key.json
    echo "$jsonKey" > key.json
    gcloud -q auth activate-service-account --key-file "key.json"
    gcloud config set project "$projectId"
    gcloud docker -a
  elif [ "$intMasterName" == "artifactory" ]; then
    local url=$(eval echo "$"res_"$resourceName"_int_url)
    local apiKey=$(eval echo "$"res_"$resourceName"_int_apiKey)
    if _is_jfrog_version_new; then
      jfrog rt config default-server --url "$url" \
      --apikey "$apiKey" --interactive=false
      jfrog rt use default-server
    else
      jfrog rt config --url "$url" --apikey "$apiKey"
    fi;
  fi

  local autoPull=$(eval echo "$"res_"$resourceName"_autoPull)

  if [ -z "$autoPull" ] || "$autoPull" == "true" ; then

    local imageName=$(eval echo "$"res_"$resourceName"_imageName)
    local imageTag=$(eval echo "$"res_"$resourceName"_imageTag)

    retry_command docker pull "$imageName:$imageTag"
    echo "Docker pull for image $imageName:$imageTag was successful"
  fi
}

# _is_jfrog_version_new checks if jfrog version is new or old
_is_jfrog_version_new() {
  local jfrog_version=""
  local jfrog_major_version=""
  local jfrog_minor_version=""

  jfrog_version=$(jfrog --version | awk '{print $3}' )
  jfrog_major_version=$(echo "$jfrog_version" | awk -F '.' '{print $1}' )
  jfrog_minor_version=$(echo "$jfrog_version" | awk -F '.' '{print $2}' )

  [[ "$jfrog_major_version" -gt "1" ]] || ( [[ "$jfrog_major_version" -eq "1" ]] &&
    [[ "$jfrog_minor_version" -gt "9" ]] )
}

execute_command "get_image %%context.resourceName%%"
