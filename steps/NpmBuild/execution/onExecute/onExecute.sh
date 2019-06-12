NpmBuild() {
  echo "[NpmBuild] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
  buildName=$pipeline_name
  buildNumber=$run_number
  sourceLocation=$(jq -r ".step.configuration.sourceLocation" $step_json_path)
  repositoryName=$(jq -r ".step.configuration.repositoryName" $step_json_path)
  inputGitRepoResourcePath=$(eval echo "$"res_"$inputGitRepoResourceName"_resourcePath)
  npmArgs=$(jq -r ".step.configuration.npmArgs" $step_json_path)
  if [ -z "$npmArgs" ] || [ "$npmArgs" == "null" ]; then
    npmArgs=""
  fi
  echo -e "\n[NpmBuild] Changing directory: $inputGitRepoResourcePath/$sourceLocation"
  pushd $inputGitRepoResourcePath/$sourceLocation
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[NpmBuild] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    if [ "$npmArgs" == "" ]; then
      echo -e "\n[NpmBuild] Installing npm packages"
    else
      echo -e "\n[NpmBuild] Installing npm packages with npmArgs: $npmArgs"
    fi
    echo -e "\n[NpmBuild] Download run state and check "$step_name"_logs to check the complete logs"
    jfrog rt npm-install $repositoryName --build-name=$buildName --build-number=$buildNumber --npm-args="$npmArgs"  &> $run_dir/workspace/"$step_name"_logs
    echo -e "\n[NpmBuild] Adding build information to run state"
    add_run_variable buildStepName=${step_name}
    add_run_variable ${step_name}_payloadType=npm
    add_run_variable ${step_name}_buildNumber=${buildNumber}
    add_run_variable ${step_name}_buildName=${buildName}
    add_run_variable ${step_name}_isPromoted=false
    add_run_variable ${step_name}_sourceStateName="npmBuildInputGitRepo"
    add_run_variable ${step_name}_sourceLocation=${sourceLocation}
  popd

  jfrog rt bce $buildName $buildNumber
  save_run_state /tmp/jfrog/. jfrog
  save_run_state $inputGitRepoResourcePath/. npmBuildInputGitRepo
}

execute_command NpmBuild
