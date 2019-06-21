GradleBuild() {
  echo "[GradleBuild] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url "$rtUrl" --user "$rtUser" --apikey "$rtApiKey" --interactive=false

  buildName="$pipeline_name"
  buildNumber="$run_number"

  sourceLocation=$(jq -r ".step.configuration.sourceLocation" $step_json_path)
  configFileLocation=$(jq -r ".step.configuration.configFileLocation" $step_json_path)
  configFileName=$(jq -r ".step.configuration.configFileName" $step_json_path)

  buildDir=$(eval echo "$"res_"$inputGitRepoResourceName"_resourcePath)/$sourceLocation

  echo "[GradleBuild] Changing directory: $buildDir"
  pushd "$buildDir"
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[GradleBuild] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    gradleCommand=$(jq -r ".step.configuration.gradleCommand" $step_json_path)
    gradleCommand=$(eval echo "$gradleCommand")

    echo "[GradleBuild] Building module with gradleCommand: $gradleCommand"
    jfrog rt gradle "$gradleCommand" "$configFileLocation"/"$configFileName" --build-name "$buildName" --build-number "$buildNumber"

    echo "[GradleBuild] Adding build information to run state"
    add_run_variables buildStepName="$step_name"
    add_run_variables "$step_name"_payloadType=gradle
    add_run_variables "$step_name"_buildNumber="$buildNumber"
    add_run_variables "$step_name"_buildName="$buildName"
    add_run_variables "$step_name"_isPromoted=false
  popd

  local forceXrayScan=$(jq -r .step.configuration.forceXrayScan $step_json_path)
  if [ "$forceXrayScan" == "true" ]; then
    echo "[GradleBuild] Scanning build $buildName/$buildNumber"
    jfrog rt bs $buildName $buildNumber
  fi

  local autoPublishBuildInfo=$(jq -r .step.configuration.autoPublishBuildInfo $step_json_path)
  if [ "$autoPublishBuildInfo" == "true" ]; then
    echo "[GradleBuild] Publishing build $buildName/$buildNumber"
    jfrog rt bp $buildName $buildNumber
    if [ ! -z "$outputBuildInfoResourceName" ]; then
      echo "[GradleBuild] Updating output resource: $outputBuildInfoResourceName"
      write_output $outputBuildInfoResourceName buildName=$buildName buildNumber=$buildNumber
    fi
  fi

  jfrog rt bce "$buildName" "$buildNumber"
  add_run_files /tmp/jfrog/. jfrog
}

execute_command GradleBuild
