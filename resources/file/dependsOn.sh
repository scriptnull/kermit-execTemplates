#!/bin/bash -e

get_file() {
  local resourceName="$1"
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)
  local intMasterName=$(eval echo "$"res_"$resourceName"_int_masterName)
  local fileLocation=$(eval echo "$"res_"$resourceName"_fileLocation)
  local fileName=$(eval echo "$"res_"$resourceName"_fileName)
  local autoPull=$(eval echo "$"res_"$resourceName"_autoPull)

  if [ -z "$autoPull" ] || "$autoPull" == "true" ; then

    if [ "$intMasterName" == "amazonKeys" ]; then
      local accessKeyId=$(eval echo "$"res_"$resourceName"_int_accessKeyId)
      local secretAccessKey=$(eval echo "$"res_"$resourceName"_int_secretAccessKey)

      aws configure set aws_access_key_id "$accessKeyId"
      aws configure set aws_secret_access_key "$secretAccessKey"

      aws s3 cp "$fileLocation/$fileName" "$resourcePath"
    elif [ "$intMasterName" == "gcloudKey" ]; then
      local jsonKey=$(eval echo "$"res_"$resourceName"_int_jsonKey)
      local projectId="$( echo "$jsonKey" | jq -r '.project_id' )"

      touch key.json
      echo "$jsonKey" > key.json
      gcloud -q auth activate-service-account --key-file "key.json"
      gcloud config set project "$projectId"

      gsutil cp $fileLocation/$fileName $resourcePath
    elif [ "$intMasterName" == "artifactory" ]; then
      local rtUrl=$(eval echo "$"res_"$resourceName"_int_url)
      local rtUser=$(eval echo "$"res_"$resourceName"_int_user)
      local rtApiKey=$(eval echo "$"res_"$resourceName"_int_apikey)

      jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
      if [ ! -z "$fileLocation" ] && [ ! -z "$fileName" ]; then
        jfrog rt dl --build-name=$PIPELINE_NAME --build-number=$RUN_NUMBER "$fileLocation/$fileName" "$resourcePath/$fileName"
      else
        local pattern=$(eval echo "$"res_"$resourceName"_pattern)
        local aql=$(eval echo "$"res_"$resourceName"_aql)
        local target=$(eval echo "$"res_"$resourceName"_target)
        local props=$(eval echo "$"res_"$resourceName"_props)
        local recursive=$(eval echo "$"res_"$resourceName"_recursive)
        local flat=$(eval echo "$"res_"$resourceName"_flat)
        local excludePatterns=$(eval echo "$"res_"$resourceName"_excludePatterns)
        local archiveEntries=$(eval echo "$"res_"$resourceName"_archiveEntries)
        local build=$(eval echo "$"res_"$resourceName"_build)
        local sortBy=$(eval echo "$"res_"$resourceName"_sortBy)
        local sortOrder=$(eval echo "$"res_"$resourceName"_sortOrder)
        local limit=$(eval echo "$"res_"$resourceName"_limit)
        local offset=$(eval echo "$"res_"$resourceName"_offset)

        specs='{}'
        if [ ! -z "$pattern" ]; then
          specs=$(echo $specs | jq --arg pattern $pattern '. + {pattern: $pattern}')
        fi

        if [ ! -z "$aql" ]; then
          specs=$(echo $specs | jq --arg aql $aql '. + {aql: $aql}')
        fi

        if [ ! -z "$target" ]; then
          specs=$(echo $specs | jq --arg target $target '. + {target: $target}')
        fi

        if [ ! -z "$props" ]; then
          specs=$(echo $specs | jq --arg props $props '. + {props: $props}')
        fi

        if [ ! -z "$recursive" ]; then
          specs=$(echo $specs | jq --arg recursive $recursive '. + {recursive: $recursive}')
        fi

        if [ ! -z "$flat" ]; then
          specs=$(echo $specs | jq --arg flat $flat '. + {flat: $flat}')
        fi

        if [ ! -z "$excludePatterns" ]; then
          specs=$(echo $specs | jq --arg excludePatterns $excludePatterns '. + {excludePatterns: $excludePatterns}')
        fi

        if [ ! -z "$archiveEntries" ]; then
          specs=$(echo $specs | jq --arg archiveEntries $archiveEntries '. + {archiveEntries: $archiveEntries}')
        fi

        if [ ! -z "$build" ]; then
          specs=$(echo $specs | jq --arg build $build '. + {build: $build}')
        fi

        if [ ! -z "$sortBy" ]; then
          specs=$(echo $specs | jq --arg sortBy $sortBy '. + {sortBy: $sortBy}')
        fi

        if [ ! -z "$sortOrder" ]; then
          specs=$(echo $specs | jq --arg sortOrder $sortOrder '. + {sortOrder: $sortOrder}')
        fi
        if [ ! -z "$limit" ]; then
          specs=$(echo $specs | jq --arg limit $limit '. + {limit: $limit|tonumber}')
        fi

        if [ ! -z "$offset" ]; then
          specs=$(echo $specs | jq --arg offset $offset '. + {offset: $offset|tonumber}')
        fi

        fileSpecs='{"files": []}'
        fileSpecs=$(echo $fileSpecs | jq --argjson json "$specs" '.files += [ $json ]')
        echo $fileSpecs | jq . > $STEP_TMP_DIR/fileSpecs.json
        pushd $resourcePath
        jfrog rt dl --build-name=$PIPELINE_NAME --build-number=$RUN_NUMBER --spec $STEP_TMP_DIR/fileSpecs.json
        popd
      fi
    elif [ "$intMasterName" == "fileServer" ]; then
      local fsProtocol=$(eval echo "$"res_"$resourceName"_int_protocol)
      local fsUrl=$(eval echo "$"res_"$resourceName"_int_url)
      local fsUsername=$(eval echo "$"res_"$resourceName"_int_username)
      local fsPassword=$(eval echo "$"res_"$resourceName"_int_password)

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
