push_to_artifactory() {
  local rtIntName="$artifactoryIntegrationName";
  local rtIntMasterName=$(eval echo "$"int_"$rtIntName"_masterName)

  if [ "$rtIntMasterName" != "artifactory" ]; then
    echo "ERROR: $rtIntName is not an Artifactory integration"
    exit 1
  fi

  local rtUrl=$(eval echo "$"int_"$rtIntName"_url)
  local rtUser=$(eval echo "$"int_"$rtIntName"_user)
  local rtApiKey=$(eval echo "$"int_"$rtIntName"_apikey)

  jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  if [ "$payloadType" == "file" ]; then
    jfrog rt u $sourcePath $targetPath --build-name=$STEP_NAME --build-number=$STEP_ID
    #jfrog rt bce $STEP_NAME $STEP_ID
    jfrog rt bp $STEP_NAME $STEP_ID
  elif [ "$payloadType" == "docker" ]; then
    jfrog rt docker-push $imageTag $targetRepo --build-name=$STEP_NAME --build-number=$STEP_ID
    #jfrog rt bce $STEP_NAME $STEP_ID
    jfrog rt bp $STEP_NAME $STEP_ID
  else
    echo "Unknown packageType: $payloadType"
    exit 1
  fi
}

execute_command push_to_artifactory
