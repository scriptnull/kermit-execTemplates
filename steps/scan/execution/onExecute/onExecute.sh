scan() {
  echo "[scan] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  local buildName=""
  local buildNumber=""
  local stepSetup=$(cat $STEP_JSON_PATH | jq .step.setup)
  if [ ! -z "$inputBuildInfoResourceName" ]; then
    echo "[scan] Using build name and number from buildInfo resource: $inputBuildInfoResourceName"
    buildName=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildName)
    buildNumber=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildNumber)
  elif [ ! -z "$buildStepName" ]; then
    buildName=$(eval echo "$""$buildStepName"_buildName)
    buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
  elif [ ! -z "$stepSetup" ] && [ "$stepSetup" != "null" ]; then
    local scan=$(echo $stepSetup | jq .scan)
    if [ ! -z "$scan" ] && [ "$scan" != "null" ]; then
      # TODO: fix this when setup section gets exported as envs
      buildNameVar=$(echo $scan | jq -r .buildName)
      buildNumberVar=$(echo $scan | jq -r .buildNumber)
      buildName=$(eval echo $buildNameVar)
      buildNumber=$(eval echo $buildNumberVar)
    fi
  fi

  if [ -z "$buildName" ] && [ -z "$buildNumber" ]; then
    echo "[scan] ERROR: Unable to find a build name and number to work with."
    echo "[scan] Please use environment variables, an input buildInfo resource"
    echo "[scan] or configure scan to run in an affinity group that also"
    echo "[scan] runs a build step."
    exit 1;
  fi

  echo "[scan] Scanning build $buildName/$buildNumber"
  jfrog rt bs $buildName $buildNumber
}

execute_command scan
