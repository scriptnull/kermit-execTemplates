#!/bin/bash -e

get_file() {
  local resourceName="$1"
  local integrationAlias=$(eval echo "$"res_"$resourceName"_integrationAlias)
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)
  local intMasterName=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_masterName)
  local fileLocation=$(eval echo "$"res_"$resourceName"_fileLocation)
  local fileName=$(eval echo "$"res_"$resourceName"_fileName)
  local autoPull=$(eval echo "$"res_"$resourceName"_autoPull)

  if [ -z "$autoPull" ] || "$autoPull" == "true" ; then

    if [ "$intMasterName" == "amazonKeys" ]; then
      local accessKeyId=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_accessKeyId)
      local secretAccessKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_secretAccessKey)

      aws configure set aws_access_key_id "$accessKeyId"
      aws configure set aws_secret_access_key "$secretAccessKey"

      aws s3 cp "$fileLocation/$fileName" "$resourcePath"
    elif [ "$intMasterName" == "gcloudKey" ]; then
      local jsonKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_jsonKey)
      local projectId="$( echo "$jsonKey" | jq -r '.project_id' )"

      touch key.json
      echo "$jsonKey" > key.json
      gcloud -q auth activate-service-account --key-file "key.json"
      gcloud config set project "$projectId"

      gsutil cp $fileLocation/$fileName $resourcePath
    elif [ "$intMasterName" == "artifactory" ]; then
      local rtUrl=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_url)
      local rtUser=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_user)
      local rtApiKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_apikey)

      jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
      jfrog rt dl --build-name=$pipeline_name --build-number=$run_number "$fileLocation/$fileName" "$resourcePath/$fileName"
    elif [ "$intMasterName" == "fileServer" ]; then
      local fsProtocol=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_protocol)
      local fsUrl=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_url)
      local fsUsername=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_username)
      local fsPassword=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_password)

      if [ "$fsProtocol" == "FTP" ]; then
        local ftpScriptFileName="ftp_get_file.txt"
        pushd $resourcePath
        touch $ftpScriptFileName
        cp /dev/null $ftpScriptFileName
        echo "open $fsUrl" >> $ftpScriptFileName
        echo "user $fsUsername $fsPassword" >> $ftpScriptFileName
        echo "pass" >> $ftpScriptFileName
        echo "cd $fileLocation" >> $ftpScriptFileName
        echo "get $fileName" >> $ftpScriptFileName
        echo "bye" >> $ftpScriptFileName
        ftp -n < $ftpScriptFileName
        rm -f $ftpScriptFileName
        popd
      fi
    fi
    echo "Successfully fetched file"
  fi
}

execute_command "get_file %%context.resourceName%%"
