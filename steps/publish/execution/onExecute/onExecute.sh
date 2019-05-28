publish() {
  echo "[publish] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  restore_run_state jfrog /tmp/jfrog

  local buildName="$buildName"
  local buildNumber="$buildNumber"
  if [ -z "$buildName" ] && [ -z "$buildNumber" ]; then
    if [ ! -z "$buildStepName" ]; then
      echo "[push] Using build name and number from build step: $buildStepName"
      buildName=$(eval echo "$""$buildStepName"_buildName)
      buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
    fi
  fi

  jfrog rt bce $buildName $buildNumber

  local publish=""
  local envInclude=""
  local envExclude=""
  local publishCmd="jfrog rt bp $buildName $buildNumber"

  local stepSetup=$(cat $STEP_JSON_PATH | jq .step.setup)
  if [ ! -z "$stepSetup" ] && [ "$stepSetup" != "null" ]; then
    local publish=$(echo $stepSetup | jq .publish)
    if [ ! -z "$publish" ] && [ "$publish" != "null" ]; then
      envInclude=$(echo $publish | jq -r .envInclude)
      envExclude=$(echo $publish | jq -r .envExclude)
    fi
  fi

  if [ ! -z "$envInclude" ] && [ "$envInclude" != "null" ]; then
    publishCmd="$publishCmd --env-include $envInclude"
  fi

  if [ ! -z "$envExclude" ] && [ "$envExclude" != "null" ]; then
    publishCmd="$publishCmd --env-exclude $envExclude"
  fi

  echo "[publish] Publishing build info $buildName/$buildNumber"
  retry_command $publishCmd

  if [ ! -z "$outputBuildInfoResourceName" ]; then
    echo "[publish] Updating output resource: $outputBuildInfoResourceName"
    write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber
  fi

  save_run_state /tmp/jfrog jfrog
}

execute_command publish
