build() {
  echo "[GoBuild] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  buildName=$PIPELINE_NAME
  buildNumber=$RUN_NUMBER

  sourceLocation=$(jq -r ".step.configuration.sourceLocation" $STEP_JSON_PATH)
  repository=$(jq -r ".step.configuration.repository" $STEP_JSON_PATH)
  version=$(jq -r ".step.configuration.version" $STEP_JSON_PATH)
  version=$(eval echo $version)
  buildDir=$(eval echo "$"res_"$inputGitRepoResourceName"_resourcePath)/$sourceLocation
  outputLocation=$(jq -r ".step.configuration.outputLocation" $STEP_JSON_PATH)
  outputLocation=$(eval echo $outputLocation)
  outputFile=$(jq -r ".step.configuration.outputFile" $STEP_JSON_PATH)
  outputFile=$(eval echo $outputFile)
  echo "[GoBuild] Changing directory: $buildDir"
  pushd $buildDir
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[GoBuild] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    goCommand=$(jq -r ".step.configuration.goCommand" $STEP_JSON_PATH)
    goCommand=$(eval echo $goCommand)
    if [ -z "$goCommand" ] || [ "$goCommand" == "null" ]; then
      goCommand="build -o $outputLocation/$outputFile"
    fi
    echo "[GoBuild] Building module with goCommand: $goCommand"
    jfrog rt go "$goCommand" $repository --build-name $buildName --build-number $buildNumber

    echo "[GoBuild] Adding build information to run state"
    add_run_variable buildStepName=${step_name}
    add_run_variable ${step_name}_payloadType=go
    add_run_variable ${step_name}_version=${version}
    add_run_variable ${step_name}_buildNumber=${buildNumber}
    add_run_variable ${step_name}_buildName=${buildName}
    add_run_variable ${step_name}_isPromoted=false
    save_run_state $outputLocation/$outputFile output/$outputFile
  popd

  jfrog rt bce $buildName $buildNumber
  save_run_state /tmp/jfrog/. jfrog
}

execute_command build
