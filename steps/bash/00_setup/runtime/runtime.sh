boot_container() {
  boot() {
    local default_docker_options="-v /opt/docker/docker:/usr/bin/docker \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $STEP_JSON_PATH:$STEP_JSON_PATH \
      -v $(pwd):$(pwd) \
      -v $PIPLELINES_RUN_STATUS_DIR:$PIPLELINES_RUN_STATUS_DIR \
      -v $REQEXEC_DIR:$REQEXEC_DIR \
      -v $STEP_DEPENDENCY_STATE_DIR:$STEP_DEPENDENCY_STATE_DIR \
      -v $STEP_OUTPUT_DIR:$STEP_OUTPUT_DIR:rw \
      -w $(pwd) -d --init --rm --privileged --name $(cat $STEP_JSON_PATH | jq .step.name)"
    local docker_run_cmd="docker run $default_docker_options \
      -e RUNNING_IN_CONTAINER=$RUNNING_IN_CONTAINER \
      $DOCKER_IMAGE \
      bash -c \"$REQEXEC_BIN_PATH $STEPLET_SCRIPT_PATH $PIPLELINES_RUN_STATUS_DIR/step.env\""

    exec_cmd "$docker_run_cmd"
  }

  exec_grp "boot" "Booting container" true

  wait_for_exit() {
    local exit_code=$(docker wait $(cat $STEP_JSON_PATH | jq -r '.step.name'))

    container_exit() {
      exec_cmd "echo \"Container exited with exit_code: $exit_code\""
    }

    if [ $exit_code -ne 0 ]; then
      exec_grp "container_exit" "Container exit code" "true"
    fi

    exit $exit_code
  }

  wait_for_exit
}

if [ "%%context.type%%" != "host" ]; then
  runtime="image"
  image_runtime_object="%%context.image%%"
  auto_default=false
  if [ -z "$image_runtime_object" ]; then
    auto_default=true
  else
    image_runtime_object=$(cat $STEP_JSON_PATH | jq '.step.setup.runtime.image')
    custom_image_runtime=$(echo $image_runtime_object | jq -r .custom)
    auto_image_runtime=$(echo $image_runtime_object | jq -r .auto)
    if [ -z "$custom_image_runtime" ] || [ -z "$auto_image_runtime" ]; then
      auto_default=true
    fi
  fi
  if $auto_default; then
    export DOCKER_IMAGE=$DEFAULT_DOCKER_IMAGE_NAME
    if [ -z $RUNNING_IN_CONTAINER ]; then
      export RUNNING_IN_CONTAINER=false;
    fi
    if ! $RUNNING_IN_CONTAINER; then
      SKIP_BEFORE_EXIT_METHODS=true
      RUNNING_IN_CONTAINER=true
      boot_container
    fi
  fi

  runtime_type="%%context.type%%"
  if [ "$(type -t $runtime_type)" == "function" ]; then
    :
    %%context.type%%
  fi
fi
