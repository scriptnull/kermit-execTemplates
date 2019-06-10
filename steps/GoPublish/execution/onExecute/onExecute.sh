build() {
  echo "[GoPublish] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  buildName=$pipeline_name
  buildNumber=$run_number

  sourceLocation=$(jq -r ".step.configuration.sourceLocation" $step_json_path)
  targetRepository=$(jq -r ".step.configuration.targetRepository" $step_json_path)
  version=$(jq -r ".step.configuration.version" $step_json_path)
  version=$(eval echo $version)
  buildDir=$(eval echo "$"res_"$inputGitRepoResourceName"_resourcePath)/$sourceLocation

  self=$(jq -r ".step.configuration.self" $step_json_path)
  deps=$(jq -r ".step.configuration.deps" $step_json_path)
  echo "[GoPublish] Changing directory: $buildDir"
  pushd $buildDir
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[GoPublish] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    options=""
    if [ ! -z "$self" ] && [ "$self" != 'null' ]; then
      options+=" --self $self"
    fi

    if [ ! -z "$deps" ] && [ "$deps" != 'null' ]; then
      options+=" --deps $deps"
    fi

    echo "[GoPublish] Publishing go packages to repository: $targetRepository"
    retry_command jfrog rt gp $targetRepository $version $options --build-name $buildName --build-number $buildNumber

    echo "[GoPublish] Adding build information to run state"
    add_run_variable buildStepName=${step_name}
    add_run_variable ${step_name}_payloadType=go
    add_run_variable ${step_name}_version=${version}
    add_run_variable ${step_name}_buildNumber=${buildNumber}
    add_run_variable ${step_name}_buildName=${buildName}
    add_run_variable ${step_name}_isPromoted=false
  popd

  jfrog rt bce $buildName $buildNumber
  save_run_state /tmp/jfrog/. jfrog
}

execute_command build
