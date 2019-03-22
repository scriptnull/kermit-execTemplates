#
# Used to generate the boot script that brings up the task container
#

boot() {
  ret=0
  is_success=false

  if [ "$TASK_CONTAINER_IMAGE_SHOULD_PULL" == true ]; then
    exec_cmd "sudo docker pull $TASK_CONTAINER_IMAGE"
  fi

  if [ "$IS_RESTRICTED_NODE" == true ]; then
    exec_cmd "sudo docker rm -fv $SHIPPABLE_DIND_CONTAINER_NAME || true"
    exec_cmd "sudo docker run -d --privileged --name $SHIPPABLE_DIND_CONTAINER_NAME $SHIPPABLE_DIND_IMAGE"

    local dind_container_ip_address=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $SHIPPABLE_DIND_CONTAINER_NAME)
    TASK_CONTAINER_OPTIONS="$TASK_CONTAINER_OPTIONS \
      -e DOCKER_HOST=tcp://$dind_container_ip_address:2375"
  fi

  exec_cmd "sudo docker run $TASK_CONTAINER_OPTIONS $TASK_CONTAINER_IMAGE $TASK_CONTAINER_COMMAND"
  ret=$?

  trap before_exit EXIT
  [ "$ret" != 0 ] && return $ret;

  is_success=true
}

wait_for_exit() {
  is_success=false

  exec_cmd "echo Waiting for $TASK_CONTAINER_NAME to exit"
  container_exit_code=$(sudo docker wait $TASK_CONTAINER_NAME)
  exec_cmd "echo Container $TASK_CONTAINER_NAME exited with exit code: $container_exit_code"

  if [ "$IS_RESTRICTED_NODE" == true ]; then
    exec_cmd "sudo docker rm -fv $SHIPPABLE_DIND_CONTAINER_NAME || true"
  fi

  trap before_exit EXIT
  [ "$container_exit_code" != 0 ] && return $container_exit_code;

  is_success=true
}

trap before_exit EXIT
exec_grp "boot" "Booting up container for task: $TASK_NAME" "true"

trap before_exit EXIT
wait_for_exit
