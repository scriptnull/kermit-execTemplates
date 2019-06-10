NpmPublish() {
  echo "[NpmPublish] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  restore_run_state jfrog /tmp/jfrog

  local sourceStateName=$(eval echo "$""$inputNpmBuildStepName"_sourceStateName)
  local tempStateLocation="$step_tmp_dir/npmSourceState"
  restore_run_state $sourceStateName $tempStateLocation

  local buildNumber=$(eval echo "$""$inputNpmBuildStepName"_buildNumber)
  local buildName=$(eval echo "$""$inputNpmBuildStepName"_buildName)
  local sourceLocation=$(eval echo "$""$inputNpmBuildStepName"_sourceLocation)
  local repositoryName=$(jq -r ".step.configuration.repositoryName" $step_json_path)

  pushd $tempStateLocation/$sourceLocation
    echo -e "\n[NpmPublish] Publishing npm packages to repository: $repositoryName"
    jfrog rt npm-publish $repositoryName --build-name=$buildName --build-number=$buildNumber
  popd

  save_run_state /tmp/jfrog/. jfrog
  # remove gitRepo from run state
  rm -rf $run_dir/workspace/$sourceStateName
}

execute_command NpmPublish
