#
# Used to stop the container when the job is cancelled/timed-out
#

Function kill_container() {
  # Redirecting stdout to prevent it from showing up in Error console group
  docker stop -t=0 $env:TASK_CONTAINER_NAME | Out-Null
}

exec_grp "kill_container" "Stopping container $env:TASK_CONTAINER_NAME" $FALSE
