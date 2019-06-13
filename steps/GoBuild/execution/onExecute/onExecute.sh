build() {
  local rtUrl=""
  local rtUser=""
  local rtApiKey=""

  if [ ! -z "$artifactoryIntegrationName" ]; then
    echo "[GoBuild] Authenticating with integration: $artifactoryIntegrationName"
    rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
    rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
    rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  elif [ ! -z "$inputFileResourceName" ]; then
    echo "[GoBuild] Authenticating with integration from resource: $inputFileResourceName"
    local integrationAlias
    integrationAlias=$(eval echo "$"res_"$inputFileResourceName"_integrationAlias)
    rtUrl=$(eval echo "$"res_"$inputFileResourceName"_"$integrationAlias"_url)
    rtUser=$(eval echo "$"res_"$inputFileResourceName"_"$integrationAlias"_user)
    rtApiKey=$(eval echo "$"res_"$inputFileResourceName"_"$integrationAlias"_apikey)
  fi

  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  buildName=$pipeline_name
  buildNumber=$run_number

  sourceLocation=$(jq -r ".step.configuration.sourceLocation" $step_json_path)
  repository=$(jq -r ".step.configuration.repository" $step_json_path)
  version=$(jq -r ".step.configuration.version" $step_json_path)
  version=$(eval echo $version)
  buildDir=$(eval echo "$"res_"$inputGitRepoResourceName"_resourcePath)/$sourceLocation
  outputLocation=$(jq -r ".step.configuration.outputLocation" $step_json_path)
  outputLocation=$(eval echo $outputLocation)
  outputFile=$(jq -r ".step.configuration.outputFile" $step_json_path)
  outputFile=$(eval echo $outputFile)

  noRegistry=$(jq -r ".step.configuration.noRegistry" $step_json_path)
  publishDeps=$(jq -r ".step.configuration.publishDeps" $step_json_path)
  echo "[GoBuild] Changing directory: $buildDir"
  pushd $buildDir
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[GoBuild] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    goCommand=$(jq -r ".step.configuration.goCommand" $step_json_path)
    goCommand=$(eval echo $goCommand)
    if [ -z "$goCommand" ] || [ "$goCommand" == "null" ]; then
      goCommand="build -o $outputLocation/$outputFile"
    fi
    mkdir -p "$outputLocation"

    options=""
    if [ ! -z "$noRegistry" ] && [ "$noRegistry" != 'null' ]; then
      options+=" --no-registry $noRegistry"
    fi

    if [ ! -z "$publishDeps" ] && [ "$publishDeps" != 'null' ]; then
      options+=" --publish-deps $publishDeps"
    fi

    echo "[GoBuild] Building module with goCommand: $goCommand"
    jfrog rt go "$goCommand" $repository $options --build-name $buildName --build-number $buildNumber

    echo "[GoBuild] Adding build information to run state"
    add_run_variable buildStepName=${step_name}
    add_run_variable ${step_name}_payloadType=go
    add_run_variable ${step_name}_version=${version}
    add_run_variable ${step_name}_buildNumber=${buildNumber}
    add_run_variable ${step_name}_buildName=${buildName}
    add_run_variable ${step_name}_isPromoted=false
    add_run_variable ${step_name}_outputStateName=output
    add_run_variable ${step_name}_sourceLocation=${sourceLocation}
    save_run_state $outputLocation/. output
  popd

  jfrog rt bce $buildName $buildNumber
  save_run_state /tmp/jfrog/. jfrog
}

execute_command build
