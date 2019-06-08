publish() {
  echo "[NpmPublish] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  local sourceStateName=$(eval echo "$""$inputNpmBuildStepName"_sourceStateName)
  restore_run_state $sourceStateName /tmp/jfrog/$sourceStateName

  local buildNumber=$(eval echo "$""$inputNpmBuildStepName"_buildNumber)
  local buildName=$(eval echo "$""$inputNpmBuildStepName"_buildName)
  local sourceLocation=$(eval echo "$""$inputNpmBuildStepName"_sourceLocation)
  local repositoryName=$(jq -r ".step.configuration.repositoryName" $step_json_path)

  echo -e "\n[NpmPublish] Changing directory: /tmp/jfrog/$sourceStateName/$sourceLocation"
  pushd /tmp/jfrog/$sourceStateName/$sourceLocation
    jfrog rt npm-publish $repositoryName --build-name=$buildName --build-number=$buildNumber
    echo -e "\n[NpmPublish] Adding publish information to run state"
    add_run_variable buildStepName=${step_name}
    add_run_variable ${step_name}_payloadType=npm
    add_run_variable ${step_name}_buildNumber=${buildNumber}
    add_run_variable ${step_name}_buildName=${buildName}
  popd
}

execute_command publish
