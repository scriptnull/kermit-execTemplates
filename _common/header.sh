#!/bin/bash -e

#
# Header script is attached at the beginning of every script generated and
# contains the most common methods use across the script
#

before_exit() {
  return_code=$?
  exit_code=1;
  if [ -z "$is_success" ]; then
    if [ $return_code -eq 0 ]; then
      is_success=true
      exit_code=0
    fi
  fi

  # Flush any remaining console
  echo $1
  echo $2

  if [ -n "$current_cmd_uuid" ]; then
    current_timestamp=`date +"%s"`
    echo "__SH__CMD__END__|{\"type\":\"cmd\",\"sequenceNumber\":\"$current_timestamp\",\"id\":\"$current_cmd_uuid\",\"exitcode\":\"$exit_code\"}|$current_cmd"
  fi

  if [ "$is_success" == true ]; then
    # "on_success" is only defined for the last task, so execute "always" only
    # if this is the last task.
    # running always and on_success inside a subshell to handle the scenario of
    # exit 0/exit 1 in these sections not failing the build
    subshell_exit_code=0
    (
      if [ "$(type -t on_success)" == "function" ]; then
        exec_cmd "on_success" || true

        if [ "$(type -t always)" == "function" ]; then
          exec_cmd "always" || true
        fi
      fi
    # subshell_exit_code will be set to 1 only when there is a exit 1 command in
    # the on_success & on_failure sections. exit 1 in these sections, is
    # considered as failure
    ) || subshell_exit_code=1

    if [ -n "$current_grp_uuid" ]; then
      current_timestamp=`date +"%s"`
      echo "__SH__GROUP__END__|{\"type\":\"grp\",\"sequenceNumber\":\"$current_timestamp\",\"id\":\"$current_grp_uuid\",\"is_shown\":\"false\",\"exitcode\":\"$subshell_exit_code\"}|$current_grp"
    fi

    if [ $subshell_exit_code -eq 0 ]; then
      echo "__SH__SCRIPT_END_SUCCESS__";
    else
      echo "__SH__SCRIPT_END_FAILURE__";
    fi
  else
    # running always and on_failure inside a subshell to handle the scenario of
    # exit 0/exit 1 in these sections not failing the build
    (
      if [ "$(type -t on_failure)" == "function" ]; then
        exec_cmd "on_failure" || true
      fi

      if [ "$(type -t always)" == "function" ]; then
        exec_cmd "always" || true
      fi
    # adding || true so that the script doesn't exit when on_failure/always
    # section has exit 1. if the script exits the group will not be
    # closed correctly.
    ) || true

    if [ -n "$current_grp_uuid" ]; then
      current_timestamp=`date +"%s"`
      echo "__SH__GROUP__END__|{\"type\":\"grp\",\"sequenceNumber\":\"$current_timestamp\",\"id\":\"$current_grp_uuid\",\"is_shown\":\"false\",\"exitcode\":\"$exit_code\"}|$current_grp"
    fi

    echo "__SH__SCRIPT_END_FAILURE__";
  fi
}

on_error() {
  exit $?
}

exec_cmd() {
  cmd="$@"
  # TODO: use shipctl to compute this
  cmd_uuid=$(cat /proc/sys/kernel/random/uuid)
  cmd_start_timestamp=`date +"%s"`
  echo "__SH__CMD__START__|{\"type\":\"cmd\",\"sequenceNumber\":\"$cmd_start_timestamp\",\"id\":\"$cmd_uuid\"}|$cmd"

  export current_cmd=$cmd
  export current_cmd_uuid=$cmd_uuid

  trap on_error ERR

  eval "$cmd"
  cmd_status=$?

  unset current_cmd
  unset current_cmd_uuid

  if [ "$2" ]; then
    echo $2;
  fi

  cmd_end_timestamp=`date +"%s"`
  # If cmd output has no newline at end, marker parsing
  # would break. Hence force a newline before the marker.
  echo ""
  local cmd_first_line=$(printf "$cmd" | head -n 1)
  echo "__SH__CMD__END__|{\"type\":\"cmd\",\"sequenceNumber\":\"$cmd_start_timestamp\",\"id\":\"$cmd_uuid\",\"exitcode\":\"$cmd_status\"}|$cmd_first_line"
  return $cmd_status
}

exec_grp() {
  # First argument is function to execute
  # Second argument is function description to be shown
  # Third argument is whether the group should be shown or not
  group_name=$1
  group_message=$2
  is_shown=true
  group_close=true
  if [ ! -z "$3" ]; then
    is_shown=$3
  fi

  if [ ! -z "$4" ]; then
    group_close=$4
  fi

  if [ -z "$group_message" ]; then
    group_message=$group_name
  fi
  # TODO: use shipctl to compute this
  group_uuid=$(cat /proc/sys/kernel/random/uuid)
  group_start_timestamp=`date +"%s"`
  echo ""
  echo "__SH__GROUP__START__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_start_timestamp\",\"id\":\"$group_uuid\",\"is_shown\":\"$is_shown\"}|$group_message"
  group_status=0

  export current_grp=$group_message
  export current_grp_uuid=$group_uuid

  {
    eval "$group_name"
  } || {
    group_status=1
  }

  if [ "$group_close" == "true" ]; then
    unset current_grp
    unset current_grp_uuid

    group_end_timestamp=`date +"%s"`
    echo "__SH__GROUP__END__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_end_timestamp\",\"id\":\"$group_uuid\",\"is_shown\":\"$is_shown\",\"exitcode\":\"$group_status\"}|$group_message"
  fi
  return $group_status
}
