NpmPublish() {
  echo "[NpmPublish] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  restore_run_files jfrog /tmp/jfrog

  local sourceStateName=$(eval echo "$""$inputNpmBuildStepName"_sourceStateName)
  local tempStateLocation="$step_tmp_dir/npmSourceState"
  restore_run_files $sourceStateName $tempStateLocation

  local buildNumber=$(eval echo "$""$inputNpmBuildStepName"_buildNumber)
  local buildName=$(eval echo "$""$inputNpmBuildStepName"_buildName)
  local sourceLocation=$(eval echo "$""$inputNpmBuildStepName"_sourceLocation)
  local repositoryName=$(jq -r ".step.configuration.repositoryName" $step_json_path)

  pushd $tempStateLocation/$sourceLocation
    echo -e "\n[NpmPublish] Publishing npm packages to repository: $repositoryName"
    jfrog rt npm-publish $repositoryName --build-name=$buildName --build-number=$buildNumber
  popd

  local forceXrayScan=$(jq -r .step.configuration.forceXrayScan $step_json_path)
  local autoPublishBuildInfo=$(jq -r .step.configuration.autoPublishBuildInfo $step_json_path)
  if [ "$autoPublishBuildInfo" == "true" ]; then
    echo "[NpmPublish] Publishing build $buildName/$buildNumber"
    jfrog rt bp $buildName $buildNumber
    if [ ! -z "$outputBuildInfoResourceName" ]; then
      echo "[NpmPublish] Updating output resource: $outputBuildInfoResourceName"
      write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber
    fi
  fi

  if [ "$forceXrayScan" == "true" ]; then
    echo "[NpmPublish] Scanning build $buildName/$buildNumber"
    jfrog rt bs $buildName $buildNumber
  fi

  add_run_files /tmp/jfrog/. jfrog
  # remove gitRepo from run state
  rm -rf $run_dir/workspace/$sourceStateName
}

execute_command NpmPublish
