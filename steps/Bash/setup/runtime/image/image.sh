boot_container() {
  wait_for_exit() {
    local exit_code=$(docker wait $DOCKER_CONTAINER_NAME)

    if [ $exit_code -ne 0 ]; then
      start_group "Container exit code"
      execute_command "echo \"Container exited with exit_code: $exit_code\""
      stop_group
    fi

    exit $exit_code
  }

  local image_autopull="%%context.autoPull%%"

  if [ "$image_autopull" == "true" ]; then
    start_group "Pulling Image"
    execute_command "docker pull $DOCKER_IMAGE"
    stop_group
  fi

  start_group "Booting Container"
  local default_docker_options="-v /opt/docker/docker:/usr/bin/docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $run_dir:$run_dir \
    -v $pipeline_workspace_dir:$pipeline_workspace_dir \
    -v $reqexec_dir:$reqexec_dir \
    -w $(pwd) -d --init --rm --privileged --name $DOCKER_CONTAINER_NAME"
  local docker_run_cmd="docker run $DOCKER_CONTAINER_OPTIONS $default_docker_options \
    -e running_in_container=$running_in_container \
    $DOCKER_IMAGE \
    bash -c \"$reqexec_bin_path $steplet_script_path steplet.env\""

  execute_command "$docker_run_cmd"

  stop_group

  wait_for_exit
}

if [ -z $running_in_container ]; then
  export running_in_container=false;
fi
if ! $running_in_container; then
  export DOCKER_IMAGE="%%context.imageName%%:%%context.imageTag%%"
  export DOCKER_CONTAINER_OPTIONS="%%context.containerOptions%%"
  export DOCKER_CONTAINER_NAME="$step_docker_container_name"
  skip_before_exit_methods=true
  running_in_container=true
  boot_container
fi
