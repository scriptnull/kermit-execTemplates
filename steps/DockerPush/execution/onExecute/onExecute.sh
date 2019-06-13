DockerPush() {
  echo "[DockerPush] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  targetRepository=$(jq -r ".step.configuration.targetRepository" $step_json_path)
  buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
  buildName=$(eval echo "$""$buildStepName"_buildName)
  dockerImageName=$(eval echo "$""$buildStepName"_dockerImageName)
  dockerImageTag=$(eval echo "$""$buildStepName"_dockerImageTag)

  echo -e "\n[DockerPush] Pushing image $dockerImageName:$dockerImageTag to repository $targetRepository"
  jfrog rt docker-push $dockerImageName:$dockerImageTag $targetRepository --build-name=$buildName --build-number=$buildNumber

  scan=$(jq -r ".step.configuration.forceXrayScan" $step_json_path)
  publish=$(jq -r ".step.configuration.autoPublishBuildInfo" $step_json_path)
  if [ "$publish" == "true" ]; then
    echo -e "\n[DockerPush] Publishing build $buildName/$buildNumber"
    jfrog rt bp $buildName $buildNumber
    if [ ! -z "$outputBuildInfoResourceName" ]; then
      echo -e "\n[DockerPush] Updating output resource: $outputBuildInfoResourceName"
      write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber
    fi
  fi

   if [ "$scan" == "true" ]; then
    echo -e "\n[DockerPush] Scanning build $buildName/$buildNumber"
    jfrog rt bs $buildName $buildNumber
  fi
}

execute_command DockerPush
