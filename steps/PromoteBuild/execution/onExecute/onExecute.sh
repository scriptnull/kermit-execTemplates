PromoteBuild() {
  local integrationName=$(eval echo "$"res_"$inputBuildInfoResourceName"_integrationName)
  echo "[PromoteBuild] Authenticating with integration: $integrationName"
  local integrationAlias=$(eval echo "$"res_"$inputBuildInfoResourceName"_integrationAlias)
  local rtUrl=$(eval echo "$"res_"$inputBuildInfoResourceName"_"$integrationAlias"_url)
  local rtUser=$(eval echo "$"res_"$inputBuildInfoResourceName"_"$integrationAlias"_user)
  local rtApiKey=$(eval echo "$"res_"$inputBuildInfoResourceName"_"$integrationAlias"_apikey)

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

  targetRepo=$(jq -r ".step.configuration.targetRepository" $step_json_path)
  includeDependencies=$(jq -r ".step.configuration.includeDependencies" $step_json_path)
  status=$(jq -r ".step.configuration.status" $step_json_path)
  comment=$(jq -r ".step.configuration.comment" $step_json_path)
  copy=$(jq -r ".step.configuration.copy" $step_json_path)

  options=""
  if [ ! -z "$status" ] && [ "$status" != 'null' ]; then
    options+=" --status $status"
  fi

  if [ ! -z "$comment" ] && [ "$comment" != 'null' ]; then
    options+=" --comment $comment"
  fi

  if [ ! -z "$copy" ] && [ "$copy" == 'true' ]; then
    options+=" --copy"
  fi

  if [ ! -z "$includeDependencies" ] && [ "$includeDependencies" == 'true' ]; then
    options+=" --include-dependencies"
  fi

  echo "[PromoteBuild] Promoting build $buildName/$buildNumber to: $targetRepo"
  local promoteBuildCmd="jfrog rt build-promote $options $buildName $buildNumber $targetRepo"

  retry_command $promoteBuildCmd

  if [ ! -z "$outputBuildInfoResourceName" ]; then
    echo "[PromoteBuild] Updating output resource: $outputBuildInfoResourceName"
    write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber targetRepo=$targetRepo
  fi
}

execute_command PromoteBuild
