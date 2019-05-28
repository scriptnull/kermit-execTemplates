promote() {
  echo "[promote] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  if [ -z "$buildName" ] && [ -z "$buildNumber" ]; then
    if [ ! -z "$inputBuildInfoResourceName" ]; then
      echo "[promote] Using build name and number from buildInfo resource: $inputBuildInfoResourceName"
      buildName=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildName)
      buildNumber=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildNumber)
    elif [ ! -z "$buildStepName" ]; then
      buildName=$(eval echo "$""$buildStepName"_buildName)
      buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
    else
      echo "[promote] ERROR: Unable to find a build name and number to work with."
      echo "[promote] Please use environment variables, an input buildInfo resource"
      echo "[promote] or configure promote to run in an affinity group that also"
      echo "[promote] runs a build step."
      exit 1;
    fi
  fi

  targetRepo=$(jq -r ".step.setup.promote.targetRepo" $STEP_JSON_PATH)

  echo "[promote] Promoting build $buildName/$buildNumber to: $targetRepo"
  retry_command jfrog rt build-promote $buildName $buildNumber $targetRepo

  if [ ! -z "$outputBuildInfoResourceName" ]; then
    echo "[promote] Updating output resource: $outputBuildInfoResourceName"
    write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber targetRepo=$targetRepo --include-dependencies
  fi
}

execute_command promote
