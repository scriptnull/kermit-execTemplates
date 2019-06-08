build() {
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
    if [ "$npmArgs" == "" ]; then
      echo -e "\n[NpmBuild] Installing npm packages"
    else
      echo -e "\n[NpmBuild] Installing npm packages with arguments: $npmArgs"
    fi
    jfrog rt npm-install $repositoryName --build-name=$buildName --build-number=$buildNumber --npm-args="$npmArgs"
    echo -e "\n[NpmBuild] Adding build information to run state"
    add_run_variable buildStepName=${step_name}
    add_run_variable ${step_name}_payloadType=npm
    add_run_variable ${step_name}_buildNumber=${buildNumber}
    add_run_variable ${step_name}_buildName=${buildName}
    add_run_variable ${step_name}_isPromoted=false
    add_run_variable ${step_name}_sourceStateName="npmBuildInputGitRepo"
  popd
  jfrog rt bce $buildName $buildNumber
  save_run_state $inputGitRepoResourcePath/. npmBuildInputGitRepo
}

execute_command build
