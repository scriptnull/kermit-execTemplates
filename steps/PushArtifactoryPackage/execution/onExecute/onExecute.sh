PushArtifactoryPackage() {
  echo "[PushArtifactoryPackage] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)

  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
  restore_run_files jfrog /tmp/jfrog

  local step_payloadType=$(eval echo "$""$buildStepName"_payloadType)
  local buildName=$(eval echo "$""$buildStepName"_buildName)
  local buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
  local targetRepo=$(jq -r ".step.configuration.targetRepo" $step_json_path)

  if [ "$step_payloadType" == "docker" ]; then
    local dockerImageName=$(eval echo "$""$buildStepName"_dockerImageName)
    local dockerImageTag=$(eval echo "$""$buildStepName"_dockerImageTag)
    jfrog rt docker-push $dockerImageName:$dockerImageTag $targetRepo --build-name=$buildName --build-number=$buildNumber
  elif [ "$step_payloadType" == "go" ]; then
    local outputStateName=$(eval echo "$""$buildStepName"_outputStateName)
    local tempStateLocation="$step_tmp_dir/goOutput"
    restore_run_files $outputStateName $tempStateLocation
    jfrog rt u "$tempStateLocation/*" $targetRepo --build-name=$buildName --build-number=$buildNumber
  else
    echo "[PushArtifactoryPackage] Unsupported payload type: $step_payloadType"
    exit 1;
  fi

  local publish=false
  local scan=false
    local publishVal=$(echo $configuration | jq -r .step.configuration.autoPublishBuildInfo)
    local scanVal=$(echo $configuration | jq -r .step.configuration.forceXrayScan)
    if [ "$publishVal" == "true" ]; then
      publish=true
    fi
    if [ "$scanVal" == "true" ]; then
      scan=true
    fi

  if $publish; then
    echo "[PushArtifactoryPackage] Publishing build $buildName/$buildNumber"
    jfrog rt bp $buildName $buildNumber
  fi

  if $scan; then
    echo "[PushArtifactoryPackage] Scanning build $buildName/$buildNumber"
    jfrog rt bs $buildName $buildNumber
  fi

  add_run_files /tmp/jfrog/. jfrog
}

execute_command PushArtifactoryPackage
