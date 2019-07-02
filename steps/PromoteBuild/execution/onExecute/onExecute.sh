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

  args=()
  if [ ! -z "$status" ] && [ "$status" != 'null' ]; then
    args+=("--status")
    args+=("$status")
  fi
  if [ ! -z "$comment" ] && [ "$comment" != 'null' ]; then
   args+=("--comment")
   args+=("$comment")
  fi

  if [ "$copy" == 'true' ]; then
    args+=("--copy")
  fi

  if [ "$includeDependencies" == 'true' ]; then
    args+=("--include-dependencies")
  fi

  args+=("$buildName")
  args+=("$buildNumber")
  args+=("$targetRepo")
  echo "[PromoteBuild] Promoting build $buildName/$buildNumber to: $targetRepo"
  retry_command jfrog rt build-promote "${args[@]}"

  if [ ! -z "$outputBuildInfoResourceName" ]; then
    echo "[PromoteBuild] Updating output resource: $outputBuildInfoResourceName"
    write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber targetRepo=$targetRepo
  fi
}

execute_command PromoteBuild
