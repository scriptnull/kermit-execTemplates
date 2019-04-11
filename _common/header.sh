#!/bin/bash -e

#
# Header script is attached at the beginning of every script generated and
# contains the most common methods use across the script
#

bump_semver() {
  local version_to_bump=$1
  local action=$2
  local versionParts=$(echo "$version_to_bump" | cut -d "-" -f 1 -s)
  local prerelease=$(echo "$version_to_bump" | cut -d "-" -f 2 -s)
  if [[ $versionParts == "" && $prerelease == "" ]]; then
    # when no prerelease is present
    versionParts=$version_to_bump
  fi
  local major=$(echo "$versionParts" | cut -d "." -f 1 | sed "s/v//")
  local minor=$(echo "$versionParts" | cut -d "." -f 2)
  local patch=$(echo "$versionParts" | cut -d "." -f 3)
  if ! [[ $action == "major" || $action == "minor" || $action == "patch" ||
    $action == "rc" || $action == "alpha" || $action == "beta" || $action == "final" ]]; then
    echo "error: Invalid action given in the argument." >&2; exit 99
  fi
  local numRegex='^[0-9]+$'
  if ! [[ $major =~ $numRegex && $minor =~ $numRegex && $patch =~ $numRegex ]] ; then
    echo "error: Invalid semantics given in the argument." >&2; exit 99
  fi
  if [[ $(echo "$versionParts" | cut -d "." -f 1) == $major ]]; then
    appendV=false
  else
    appendV=true
  fi
  if [[ $action == "final" ]];then
    local new_version="$major.$minor.$patch"
  else
    if [[ $action == "major" ]]; then
      major=$((major + 1))
      minor=0
      patch=0
    elif [[ $action == "minor" ]]; then
      minor=$((minor + 1))
      patch=0
    elif [[ $action == "patch" ]]; then
      patch=$((patch + 1))
    elif [[ $action == "rc" || $action == "alpha" || $action == "beta" ]]; then
      local prereleaseCount="";
      local prereleaseText="";
      if [ ! -z $(echo "$prerelease" | grep -oP "$action") ]; then
        local count=$(echo "$prerelease" | grep -oP "$action.[0-9]*")
        if [ ! -z $count ]; then
          prereleaseCount=$(echo "$count" | cut -d "." -f 2 -s)
          prereleaseCount=$(($prereleaseCount + 1))
        else
          prereleaseCount=1
        fi
        prereleaseText="$action.$prereleaseCount"
      else
        prereleaseText=$action
      fi
    fi
    local new_version="$major.$minor.$patch"
    if [[ $prereleaseText != "" ]]; then
      new_version="$new_version-$prereleaseText"
    fi
  fi
  if [[ $appendV == true ]]; then
    new_version="v$new_version"
  fi
  echo $new_version
}

read_json() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_json_value JSON_PATH FIELD"
    exit 99
  fi
  if [ -f "$1" ]; then
    cat "$1" | jq -r '.'"$2"
  else
    echo "$1: No such file present in this directory"
    exit 99
  fi
}

before_exit() {
  return_code=$?
  exit_code=1;
  if [ $return_code -eq 0 ]; then
    is_success=true
    exit_code=0
  else
    is_success=false
    exit_code=$return_code
  fi

  # Flush any remaining console
  echo $1
  echo $2

  if [ -n "$current_cmd_uuid" ]; then
    current_timestamp=`date +"%s"`
    echo "__SH__CMD__END__|{\"type\":\"cmd\",\"sequenceNumber\":\"$current_timestamp\",\"id\":\"$current_cmd_uuid\",\"exitcode\":\"$exit_code\"}|$current_cmd"
  fi

  if [ -z $SKIP_BEFORE_EXIT_METHODS ]; then
    SKIP_BEFORE_EXIT_METHODS=false
  fi

  if [ "$is_success" == true ]; then
    # "onSuccess" is only defined for the last task, so execute "onComplete" only
    # if this is the last task.
    # running onComplete and onSuccess inside a subshell to handle the scenario of
    # exit 0/exit 1 in these sections not failing the build
    subshell_exit_code=0
    (
      if [ "$(type -t onSuccess)" == "function" ] && ! $SKIP_BEFORE_EXIT_METHODS; then
        exec_cmd "onSuccess" || true
      fi

      if [ "$(type -t onComplete)" == "function" ] && ! $SKIP_BEFORE_EXIT_METHODS; then
        exec_cmd "onComplete" || true
      fi
    # subshell_exit_code will be set to 1 only when there is a exit 1 command in
    # the onSuccess & onFailure sections. exit 1 in these sections, is
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
    # running onComplete and onFailure inside a subshell to handle the scenario of
    # exit 0/exit 1 in these sections not failing the build
    (
      if [ "$(type -t onFailure)" == "function" ] && ! $SKIP_BEFORE_EXIT_METHODS; then
        exec_cmd "onFailure" || true
      fi

      if [ "$(type -t onComplete)" == "function" ] && ! $SKIP_BEFORE_EXIT_METHODS; then
        exec_cmd "onComplete" || true
      fi
    # adding || true so that the script doesn't exit when onFailure/onComplete
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

  trap before_exit EXIT
  if [ "$cmd_status" != 0 ]; then
    is_success=false
    return $cmd_status;
  fi
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

trap before_exit EXIT
