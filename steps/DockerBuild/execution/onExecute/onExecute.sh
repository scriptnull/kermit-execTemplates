DockerBuild() {
  buildName=$pipeline_name
  buildNumber=$run_number
  dockerFileLocation=$(jq -r ".step.configuration.dockerFileLocation" $step_json_path)
  dockerFileName=$(jq -r ".step.configuration.dockerFileName" $step_json_path)
  dockerImageName=$(jq -r ".step.configuration.dockerImageName" $step_json_path)
  dockerImageTag=$(jq -r ".step.configuration.dockerImageTag" $step_json_path)
  evalDockerImageName=$(eval echo $dockerImageName)
  evalDockerImageTag=$(eval echo $dockerImageTag)

  buildDir=$(eval echo "$"res_"$inputGitRepoResourceName"_resourcePath)/$dockerFileLocation
  echo "[DockerBuild] Changing directory: $buildDir"
  pushd $buildDir
    if [ ! -z "$inputFileResourceName" ]; then
      filePath=$(eval echo "$"res_"$inputFileResourceName"_resourcePath)/*
      echo "[DockerBuild] Copying files from: $filePath to: $(pwd)"
      # todo: remove -v
      cp -vr $filePath .
    fi

    echo "[DockerBuild] Building docker image: $evalDockerImageName:$evalDockerImageTag using Dockerfile: ${dockerFileName}"
    docker build -t $evalDockerImageName:$evalDockerImageTag -f ${buildDir}/${dockerFileName} .

    echo "[DockerBuild] Adding build information to pipeline state"
    add_run_variable buildStepName=${step_name}
    add_run_variable ${step_name}_payloadType="docker"
    add_run_variable ${step_name}_buildNumber=${buildNumber}
    add_run_variable ${step_name}_buildName=${buildName}
    add_run_variable ${step_name}_isPromoted=false
    add_run_variable ${step_name}_dockerImageName=${evalDockerImageName}
    add_run_variable ${step_name}_dockerImageTag=${evalDockerImageTag}

  popd

  jfrog rt bce $buildName $buildNumber
  save_run_state /tmp/jfrog/. jfrog
}

execute_command DockerBuild
