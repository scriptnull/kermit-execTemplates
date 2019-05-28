build() {
  echo "[build] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  payloadType=$step_payloadType
  buildName=$PIPELINE_NAME
  buildNumber=$RUN_NUMBER

  buildDir=$(eval echo "$"res_"$inputGitRepoResourceName"_resourcePath)/$dockerFileLocation
  echo "[build] Changing directory: $buildDir"
  pushd $buildDir
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[build] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    if [ "$payloadType" == "docker" ]; then
      dockerFileLocation=$(jq -r ".step.setup.build.dockerFileLocation" $STEP_JSON_PATH)
      dockerFileName=$(jq -r ".step.setup.build.dockerFileName" $STEP_JSON_PATH)
      imageName=$(jq -r ".step.setup.build.imageName" $STEP_JSON_PATH)
      imageTag=$(jq -r ".step.setup.build.imageTag" $STEP_JSON_PATH)
      evalImageName=$(eval echo $imageName)
      evalImageTag=$(eval echo $imageTag)
      echo "[build] Building docker image: $evalImageName:$evalImageTag using Dockerfile: ${dockerFileName}"
      docker build -t $evalImageName:$evalImageTag -f ${buildDir}/${dockerFileName} .

      echo "[build] Adding build information to pipeline state"
      add_pipeline_variable buildStepName=${STEP_NAME}
      add_pipeline_variable ${STEP_NAME}_payloadType=${payloadType}
      add_pipeline_variable ${STEP_NAME}_buildNumber=${buildNumber}
      add_pipeline_variable ${STEP_NAME}_buildName=${buildName}
      add_pipeline_variable ${STEP_NAME}_isPromoted=false
      add_pipeline_variable ${STEP_NAME}_imageName=${evalImageName}
      add_pipeline_variable ${STEP_NAME}_imageTag=${evalImageTag}

    else
      echo "[build] Unsupported payloadType: $payloadType"
      exit 1
    fi
  popd
}

execute_command build
