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

  start_group "Booting Container"
  local default_docker_options="-v /opt/docker/docker:/usr/bin/docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $RUN_DIR:$RUN_DIR \
    -v $PIPELINE_WORKSPACE_DIR:$PIPELINE_WORKSPACE_DIR \
    -v $STATUS_DIR:$STATUS_DIR \
    -v $REQEXEC_DIR:$REQEXEC_DIR \
    -w $(pwd) -d --init --rm --privileged --name $DOCKER_CONTAINER_NAME"
  local docker_run_cmd="docker run $DOCKER_CONTAINER_OPTIONS $default_docker_options \
    -e RUNNING_IN_CONTAINER=$RUNNING_IN_CONTAINER \
    $DOCKER_IMAGE \
    bash -c \"$REQEXEC_BIN_PATH $STEPLET_SCRIPT_PATH $STATUS_DIR/step.env\""

  execute_command "$docker_run_cmd"

  stop_group

  wait_for_exit
}

if [ -z $RUNNING_IN_CONTAINER ]; then
  export RUNNING_IN_CONTAINER=false;
fi
if ! $RUNNING_IN_CONTAINER; then
  export DOCKER_IMAGE="%%context.imageName%%:%%context.imageTag%%"
  export DOCKER_CONTAINER_OPTIONS="%%context.containerOptions%%"
  export DOCKER_CONTAINER_NAME="$STEP_DOCKER_CONTAINER_NAME"
  SKIP_BEFORE_EXIT_METHODS=true
  RUNNING_IN_CONTAINER=true
  boot_container
fi
