push() {
  if [ -z "$outputIntegrationName" ]; then
    # We need to use the integration from the output resource
    if [ "$step_payloadType" == "docker" ]; then
      local outputIntMasterName=$(eval echo "$"res_"$outputImageResourceName"_int_masterName)
      local outputResName=$outputImageResourceName
    elif [ "$step_payloadType" == "file" ]; then
      local outputIntMasterName=$(eval echo "$"res_"$outputFileResourceName"_int_masterName)
      local outputResName=$outputFileResourceName
    fi

    echo "[push] Authenticating using resource $outputResName"
    if [ "$outputIntMasterName" == "artifactory" ]; then
      local rtUrl=$(eval echo "$"res_"$outputResName"_int_url)
      local rtUser=$(eval echo "$"res_"$outputResName"_int_user)
      local rtApiKey=$(eval echo "$"res_"$outputResName"_int_apikey)
      retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
    elif [ "$outputIntMasterName" == "dockerRegistryLogin" ]; then
      local dhUrl=$(eval echo "$"res_"$outputResName"_int_url)
      local dhUsername=$(eval echo "$"res_"$outputResName"_int_username)
      local dhPassword=$(eval echo "$"res_"$outputResName"_int_password)
      retry_command docker login -u "$dhUsername" -p "$dhPassword" "$dhUrl"
    else
      echo "[push] $outputResName uses an unsupported integration"
      exit 1
    fi
  else
    # We need to use the named integration
    local outputIntName="$outputIntegrationName";
    local outputIntMasterName=$(eval echo "$"int_"$outputIntName"_masterName)
    echo "[push] Authenticating using integration $outputIntegrationName"

    if [ "$outputIntMasterName" == "artifactory" ]; then
      local rtUrl=$(eval echo "$"int_"$outputIntName"_url)
      local rtUser=$(eval echo "$"int_"$outputIntName"_user)
      local rtApiKey=$(eval echo "$"int_"$outputIntName"_apikey)
      retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
    elif [ "$outputIntMasterName" == "dockerRegistryLogin" ]; then
      local dhUrl=$(eval echo "$"int_"$outputIntName"_url)
      local dhUsername=$(eval echo "$"int_"$outputIntName"_username)
      local dhPassword=$(eval echo "$"int_"$outputIntName"_password)
      retry_command docker login -u "$dhUsername" -p "$dhPassword" "$dhUrl"
    else
      echo "[push] $outputIntegrationName is an unsupported integration"
      exit 1
    fi

    echo "[push] Authentication was successful"
  fi

  if [ "$step_payloadType" == "file" ]; then
    if [ ! -z "$inputFileResourceName" ]; then
      # We need to get $inputFileLocation and $inputFileName from the resource
      local inputFileLocation=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)
      local inputFileName=$(eval echo "$"res_"$inputFileResourceName"_fileName)
    fi
    if [ ! -z "$outputFileResourceName" ]; then
      # We need to get $inputFileLocation and $inputFileName from the resource
      local outputFileLocation=$(eval echo "$"res_"$outputFileResourceName"_fileLocation)
    fi

    if [ "$outputIntMasterName" == "artifactory" ]; then
      retry_command jfrog rt u $inputFileLocation/$inputFileName $outputFileLocation/$outputFileName --build-name=$STEP_NAME --build-number=$STEP_ID
      #retry_command jfrog rt bce $STEP_NAME $STEP_ID
      retry_command jfrog rt bp $STEP_NAME $STEP_ID
    fi
  elif [ "$step_payloadType" == "docker" ]; then
    if [ ! -z "$inputImageResourceName" ]; then
      local inputImageName=$(eval echo "$"res_"$inputImageResourceName"_imageName)
      local inputImageTag=$(eval echo "$"res_"$inputImageResourceName"_imageTag)
    fi
    if [ ! -z "$outputImageResourceName" ]; then
      local outputImageName=$(eval echo "$"res_"$outputImageResourceName"_imageName)
    fi

    echo "[push] Tagging docker image $inputImageName:$inputImageTag -> $outputImageName:$outputImageTag"
    docker tag $inputImageName:$inputImageTag $outputImageName:$outputImageTag
    if [ "$outputIntMasterName" == "artifactory" ]; then
      echo "[push] Pushing docker image $outputImageName:$outputImageTag to Artifactory"
      retry_command jfrog rt docker-push $outputImageName:$outputImageTag $targetRepo --build-name=$STEP_NAME --build-number=$STEP_ID
      #retry_command jfrog rt bce $STEP_NAME $STEP_ID
      retry_command jfrog rt bp $STEP_NAME $STEP_ID
    elif [ "$outputIntMasterName" == "dockerRegistryLogin" ]; then
      echo "[push] Pushing docker image $outputImageName:$outputImageTag"
      retry_command docker push $outputImageName:$outputImageTag
    fi

    echo "[push] Docker push successful"

    if [ ! -z "$outputImageResourceName" ]; then
      echo "[push] Writing output to resource $outputImageResourceName"
      write_output $outputImageResourceName imageName=$outputImageName imageTag=$outputImageTag
    fi

  else
    echo "Unknown packageType: $payloadType"
    exit 1
  fi
}

execute_command push
