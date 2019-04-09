if ! type jq &> /dev/null; then
  ### installing jq, if not present
  ### this handles only apt installs for now
  apt-get update &> /dev/null
  apt-get install -y jq &> /dev/null
fi

export SKIP_BEFORE_EXIT_METHODS=false

if [ "$(type -t setup)" == "function" ]; then
  setup
else
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

  default_runtime=true
  context=$(cat $STEP_JSON_PATH)
  context_setup=$(echo $context | jq .setup)
  if [ ! -z $context_setup ]; then
    runtime_object=$(echo $setup | jq -r .runtime)
    if [ ! -z "runtime_object" ]; then
      default_runtime=false
    fi
  fi

  if $default_runtime; then
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
fi

if [ "$(type -t onStart)" == "function" ]; then
  exec_grp "onStart" "On Start" "true"
fi

exec_grp "onExecute" "Executing step" "true"
