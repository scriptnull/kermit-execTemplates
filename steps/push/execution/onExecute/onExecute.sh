push_to_artifactory() {
  local outputIntName="$outputIntegrationName";
  local outputIntMasterName=$(eval echo "$"int_"$outputIntName"_masterName)

  if [ "$outputIntMasterName" == "artifactory" ]; then
    local rtUrl=$(eval echo "$"int_"$outputIntName"_url)
    local rtUser=$(eval echo "$"int_"$outputIntName"_user)
    local rtApiKey=$(eval echo "$"int_"$outputIntName"_apikey)
    retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
  elif [ "$outputIntMasterName" == "dockerRegistryLogin" ]; then
    local dhUrl=$(eval echo "$"int_"$outputIntName"_url)
    local dhUsername=$(eval echo "$"int_"$outputIntName"_username)
    local dhPassword=$(eval echo "$"int_"$outputIntName"_password)
    retry_command docker login -u "$userName" -p "$password" "$url"
  else
    echo "$outputIntegrationName is not an Artifactory or Docker Registry integration"
    exit 1
  fi

  if [ "$step_payloadType" == "file" ]; then
    retry_command jfrog rt u $sourcePath $targetPath --build-name=$STEP_NAME --build-number=$STEP_ID
    #retry_command jfrog rt bce $STEP_NAME $STEP_ID
    retry_command jfrog rt bp $STEP_NAME $STEP_ID
  elif [ "$step_payloadType" == "docker" ]; then
    docker tag $inputImageName:$inputImageTag $outputImageName:$outputImageTag
    if [ "$outputIntMasterName" == "artifactory" ]; then
      retry_command jfrog rt docker-push $outputImageName:$outputImageTag $targetRepo --build-name=$STEP_NAME --build-number=$STEP_ID
      #retry_command jfrog rt bce $STEP_NAME $STEP_ID
      retry_command jfrog rt bp $STEP_NAME $STEP_ID
    elif [ "$outputIntMasterName" == "dockerRegistryLogin" ]; then
      retry_command docker push $outputImageName:$outputImageTag
    fi
  else
    echo "Unknown packageType: $payloadType"
    exit 1
  fi
}

execute_command push_to_artifactory
