GoPublishBinary() {
  if [ ! -z "$outputBuildInfoResourceName" ]; then
    echo "[GoPublishBinary] Authenticating with integration from resource: $outputBuildInfoResourceName"
    local integrationAlias=$(eval echo "$"res_"$outputBuildInfoResourceName"_integrationAlias)
    local rtUrl=$(eval echo "$"res_"$outputBuildInfoResourceName"_"$integrationAlias"_url)
    local rtUser=$(eval echo "$"res_"$outputBuildInfoResourceName"_"$integrationAlias"_user)
    local rtApiKey=$(eval echo "$"res_"$outputBuildInfoResourceName"_"$integrationAlias"_apikey)
  else
    echo "[GoPublishBinary] Authenticating with integration: $artifactoryIntegrationName"
    local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
    local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
    local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  fi

  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  restore_run_state jfrog /tmp/jfrog

  local outputStateName=$(eval echo "$""$buildStepName"_outputStateName)
  local tempStateLocation="$step_tmp_dir/goOutput"
  restore_run_state $outputStateName $tempStateLocation

  local buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
  local buildName=$(eval echo "$""$buildStepName"_buildName)
  local sourceLocation=$(eval echo "$""$buildStepName"_sourceLocation)
  targetRepository=$(jq -r ".step.configuration.targetRepository" $step_json_path)
  echo -e "\n[GoPublishBinary] Pushing go binary to repository: $targetRepository"
  jfrog rt u "$tempStateLocation/*" $targetRepository --build-name=$buildName --build-number=$buildNumber

  local publish=$(jq -r .step.configuration.autoPublishBuildInfo $step_json_path)
  if [ "$publish" == "true" ]; then
    echo "[GoPublishBinary] Publishing build $buildName/$buildNumber"
    jfrog rt bp $buildName $buildNumber
    if [ ! -z "$outputBuildInfoResourceName" ]; then
      echo "[GoPublishBinary] Updating output resource: $outputBuildInfoResourceName"
      write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber
    fi
  fi
  local forceXrayScan=$(jq -r .step.configuration.forceXrayScan $step_json_path)
  if [ "$forceXrayScan" == "true" ]; then
    echo "[GoPublishBinary] Scanning build $buildName/$buildNumber"
    jfrog rt bs $buildName $buildNumber
  fi

  save_run_state /tmp/jfrog/. jfrog
}

execute_command GoPublishBinary
