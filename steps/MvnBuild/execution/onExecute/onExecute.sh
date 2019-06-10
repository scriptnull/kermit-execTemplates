MvnBuild() {
  echo "[MvnBuild] Authenticating with integration: $artifactoryIntegrationName"
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

  echo "[MvnBuild] Changing directory: $buildDir"
  pushd "$buildDir"
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[MvnBuild] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    mvnCommand=$(jq -r ".step.configuration.mvnCommand" $step_json_path)
    mvnCommand=$(eval echo "$mvnCommand")

    echo "[MvnBuild] Building module with mvnCommand: $mvnCommand"
    jfrog rt mvn "$mvnCommand" "$configFileLocation"/"$configFileName" --build-name "$buildName" --build-number "$buildNumber"

    echo "[MvnBuild] Adding build information to run state"
    add_run_variable buildStepName="$step_name"
    add_run_variable "$step_name"_payloadType=mvn
    add_run_variable "$step_name"_buildNumber="$buildNumber"
    add_run_variable "$step_name"_buildName="$buildName"
    add_run_variable "$step_name"_isPromoted=false
  popd

  jfrog rt bce "$buildName" "$buildNumber"
  save_run_state /tmp/jfrog/. jfrog
}

execute_command MvnBuild
