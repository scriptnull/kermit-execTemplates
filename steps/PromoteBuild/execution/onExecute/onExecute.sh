PromoteBuild() {
  echo "[PromoteBuild] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  if [ -z "$buildName" ] && [ -z "$buildNumber" ]; then
    if [ ! -z "$inputBuildInfoResourceName" ]; then
      echo "[PromoteBuild] Using build name and number from BuildInfo resource: $inputBuildInfoResourceName"
      buildName=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildName)
      buildNumber=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildNumber)
    elif [ ! -z "$buildStepName" ]; then
      buildName=$(eval echo "$""$buildStepName"_buildName)
      buildNumber=$(eval echo "$""$buildStepName"_buildNumber)
    else
      echo "[PromoteBuild] ERROR: Unable to find a build name and number to work with."
      echo "[PromoteBuild] Please use environment variables, an input BuildInfo resource"
      echo "[PromoteBuild] or configure PromoteBuild to run in an affinity group that also"
      echo "[PromoteBuild] runs a build step."
      exit 1;
    fi
  fi

  targetRepo=$(jq -r ".step.configuration.targetRepo" $step_json_path)
  includeDependencies=$(jq -r ".step.configuration.includeDependencies" $step_json_path)

  echo "[PromoteBuild] Promoting build $buildName/$buildNumber to: $targetRepo"
  local PromoteBuildCmd="jfrog rt build-promote $buildName $buildNumber $targetRepo"
  if [ ! -z "$includeDependencies" ] && [ "$includeDependencies" == "true" ]; then
    PromoteBuildCmd="$PromoteBuildCmd --include-dependencies"
    echo "[PromoteBuild] (including dependencies)"
  fi

  retry_command $PromoteBuildCmd

  if [ ! -z "$outputBuildInfoResourceName" ]; then
    echo "[PromoteBuild] Updating output resource: $outputBuildInfoResourceName"
    write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber targetRepo=$targetRepo
  fi
}

execute_command PromoteBuild
