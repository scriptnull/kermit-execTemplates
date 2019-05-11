push_to_artifactory() {
  local rtIntName="$artifactoryIntegrationName";
  local rtIntMasterName=$(eval echo "$"res_"$rtIntName"_int_masterName)

  if [ "$rtIntMasterName" != "artifactory" ]; then
    echo "ERROR: $rtIntName is not an Artifactory integration"
    exit 1;
  fi

  local rtUrl=$(eval echo "$"int_"$rtIntName"_url)
  local rtUser=$(eval echo "$"int_"$rtIntName"_user)
  local rtApiKey=$(eval echo "$"int_"$rtIntName"_apikey)

  jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  if [ "$stepPackageType" == "files" ]; then
    jfrog rt u $sourcePath $targetPath --build-name=$STEP_NAME --build-number=$STEP_ID
    #jfrog rt bce $STEP_NAME $STEP_NUMBER
    jfrog rt bp $STEP_NAME $STEP_NUMBER
  elif [ "$stepPackageType" == "docker" ]; then
    jfrog rt docker-push $imageTag $targetRepo --build-name=$STEP_NAME --build-number=$STEP_ID
    #jfrog rt bce $STEP_NAME $STEP_ID
    jfrog rt bp $STEP_NAME $STEP_ID
  fi
}

execute_command push_to_artifactory
