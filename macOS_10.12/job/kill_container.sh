#
# Used to stop the container when the job is cancelled/timed-out
#

kill_container() {
  # Redirecting stdout to prevent it from showing up in Error console group
  sudo docker stop -t=0 $TASK_CONTAINER_NAME > /dev/null
}

exec_grp "kill_container" "Stopping container $TASK_CONTAINER_NAME" false
