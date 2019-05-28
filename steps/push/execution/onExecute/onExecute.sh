push() {
  echo "[push] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)

  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
  restore_run_state jfrog /tmp/jfrog

  local step_payloadType=$(eval echo "$""$buildStepName"_payloadType)
  if [ "$step_payloadType" == "docker" ]; then
    local imageName=$(eval echo "$""$buildStepName"_imageName)
    local imageTag=$(eval echo "$""$buildStepName"_imageTag)
    local targetRepo=$(jq -r ".step.setup.push.targetRepo" $STEP_JSON_PATH)
    local buildName=$(eval echo "$""$buildStepName"_buildName)
    local buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
    jfrog rt docker-push $imageName:$imageTag $targetRepo --build-name=$buildName --build-number=$buildNumber
  fi

  save_run_state /tmp/jfrog/. jfrog
}

execute_command push
