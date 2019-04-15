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
    echo "Usage: read_json JSON_PATH FIELD" >&2
    exit 99
  fi
  if [ -f "$1" ]; then
    cat "$1" | jq -r '.'"$2"
  else
    echo "$1: No such file present in this directory" >&2
    exit 99
  fi
}

decrypt_file() {
  local source_file=""
  local key_file=""
  local dest_file=""
  local temp_dest='/tmp/shippable/decrypt'

  if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
      ARGUMENT="$1"

      case $ARGUMENT in
        --key)
          key_file=$2
          shift
          shift
          ;;
        --output)
          dest_file=$2
          shift
          shift
          ;;
        *)
          source_file=$1
          shift
          ;;
      esac
    done
  fi

  echo "decrypt_file: Decrypting $source_file using key $key_file"

  if [ ! -f "$key_file" ]; then
    echo "decrypt_file: ERROR - Key file $key_file not found" >&2
    exit 100
  fi

  if [ ! -f "$source_file" ]; then
    echo "decrypt_file: ERROR - Source file $source_file not found" >&2
    exit 100
  fi

  if [ -d "$temp_dest" ]; then
    rm -r ${temp_dest:?}
  fi
  mkdir -p $temp_dest/fragments

  base64 --decode < "$source_file" > $temp_dest/encrypted.raw
  split -b 256 "$temp_dest/encrypted.raw" $temp_dest/fragments/
  local fragments
  fragments=$(ls -b $temp_dest/fragments)
  for fragment in $fragments; do
    openssl rsautl -decrypt -inkey "$key_file" -oaep < "$temp_dest/fragments/$fragment" >> "$dest_file"
  done;

  rm -r ${temp_dest:?}/*
  echo "decrypt_file: Decrypted $source_file to $dest_file"
}

encrypt_file() {
  local source_file=""
  local key_file=""
  local dest_file=""
  local temp_dest='/tmp/shippable/encrypt'

  if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
      ARGUMENT="$1"

      case $ARGUMENT in
        --key)
          key_file=$2
          shift
          shift
          ;;
        --output)
          dest_file=$2
          shift
          shift
          ;;
        *)
          source_file=$1
          shift
          ;;
      esac
    done
  fi

  echo "encrypt_file: Encrypting $source_file using key $key_file"

  if [ ! -f "$key_file" ]; then
    echo "encrypt_file: ERROR - Key file $key_file not found" >&2
    exit 100
  fi

  if [ ! -f "$source_file" ]; then
    echo "encrypt_file: ERROR - Source file $source_file not found" >&2
    exit 100
  fi

  if [ -d "$temp_dest" ]; then
    rm -r ${temp_dest:?}
  fi
  mkdir -p $temp_dest/fragments

  split -b 256 "$source_file" $temp_dest/fragments/
  local fragments
  fragments=$(ls -b $temp_dest/fragments)

  for fragment in $fragments; do
    openssl rsautl -encrypt -inkey $key_file -pubin -oaep < "$temp_dest/fragments/$fragment" >> $temp_dest/encrypted
  done;

  base64 < "$temp_dest/encrypted" > $dest_file

  rm -r ${temp_dest:?}/*
  echo "encrypt_file: Encrypted $source_file to $dest_file"
}

decrypt_string() {
  local source_string=""
  local key_file=""
  local dest_file=""
  local temp_dest='/tmp/shippable/decrypt'

  if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
      ARGUMENT="$1"

      case $ARGUMENT in
        --key)
          key_file=$2
          shift
          shift
          ;;
        *)
          source_string="$1"
          shift
          ;;
      esac
    done
  fi

  if [ ! -f "$key_file" ]; then
    echo "decrypt_string: ERROR - Key file $key_file not found" >&2
    exit 100
  fi

  if [ -d "$temp_dest" ]; then
    rm -r ${temp_dest:?}
  fi
  mkdir -p $temp_dest/fragments

  echo "$source_string" >> $temp_dest/input

  base64 --decode < "$temp_dest/input" > $temp_dest/encrypted.raw

  split -b 256 "$temp_dest/encrypted.raw" $temp_dest/fragments/
  local fragments
  fragments=$(ls -b $temp_dest/fragments)
  for fragment in $fragments; do
    openssl rsautl -decrypt -inkey "$key_file" -oaep < "$temp_dest/fragments/$fragment" >> "$temp_dest/output"
  done;

  cat $temp_dest/output

  rm -r ${temp_dest:?}/*
}

encrypt_string() {
  local source_string=""
  local key_file=""
  local dest_file=""
  local temp_dest='/tmp/shippable/encrypt'

  if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
      ARGUMENT="$1"

      case $ARGUMENT in
        --key)
          key_file=$2
          shift
          shift
          ;;
        *)
          source_string=$1
          shift
          ;;
      esac
    done
  fi

  if [ ! -f "$key_file" ]; then
    echo "encrypt_string: ERROR - Key file $key_file not found" >&2
    exit 100
  fi

  if [ -d "$temp_dest" ]; then
    rm -r ${temp_dest:?}
  fi
  mkdir -p $temp_dest/fragments

  echo $source_string >> $temp_dest/input

  split -b 256 "$temp_dest/input" $temp_dest/fragments/
  local fragments
  fragments=$(ls -b $temp_dest/fragments)

  for fragment in $fragments; do
    openssl rsautl -encrypt -inkey $key_file -pubin -oaep < "$temp_dest/fragments/$fragment" >> $temp_dest/encrypted
  done;

  base64 < "$temp_dest/encrypted" > $temp_dest/output

  cat $temp_dest/output

  rm -r ${temp_dest:?}/*
}

replace_tags() {
  # prereqs:
  #  - envsubst (via gettext)
  #  - step.json path set in variable STEP_JSON_PATH
  #  - jq
  #  - sed
  #  - grep
  local TAGS_ONLY=false
  local ENVS_ONLY=false
  local STDIN=false
  local file_array=()
  for arg in "$@"; do
    case $arg in
      --tags-only)
        TAGS_ONLY=true
        shift
        ;;
      --envs-only)
        ENVS_ONLY=true
        shift
        ;;
      --stdin)
        STDIN=true
        shift
        ;;
      *)
        file_array+=($arg)
        ;;

    esac
  done
  if [ "$STDIN" == "false" ] && [ "${#file_array[@]}" -eq 0 ]; then
    echo "Error: Missing --stdin option or file list." >&2
    exit 82
  fi
  if [ "$STDIN" == "true" ]; then
    local stdin_contents=$(IFS="" cat /dev/stdin)
    _replace_stdin "$stdin_contents" "$TAGS_ONLY" "$ENVS_ONLY"
    local stdin_rc="$?"
    if [ "$stdin_rc" -ne 0 ]; then
      exit $stdin_rc
    fi
  else
    mkdir -p /tmp/replace_tags
    for file in "${file_array[@]}"; do
      _replace_file "$file" "$TAGS_ONLY" "$ENVS_ONLY"
      local replace_rc="$?"
      if [ "$replace_rc" -ne 0 ]; then
        exit $replace_rc
      fi
    done
  fi
}

_replace_stdin() {
  local contents="$1"
  local TAGS_ONLY="$2"
  local ENVS_ONLY="$3"

  if [ "$ENVS_ONLY" == "false" ]; then
    local isValid=$(jq type "$STEP_JSON_PATH" || true)
    if [ -z "$isValid" ]; then
      echo "Error: step.json is not valid JSON" >&2
      return 82
    fi
    local token_list=($(grep "%%[A-Za-z0-9_\-\.]*%%" -o <<< $contents))
    for token in "${token_list[@]}"; do
      local json_path="${token//%%/}"
      local json_result=$(_search_stepjson "$json_path")
      if [ -z "$json_result" ]; then
        echo "Error: match not found in step.json for pattern: $token. Skipping." >&2
        continue
      fi
      local sed_result=$((echo $json_result|sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'|sed 's/[]]/\[]]/g')>&1)
      local sed_token=$((echo $token|sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'|sed 's/[]]/\[]]/g')>&1)
      contents=$((echo "$contents"|sed "s/$sed_token/$sed_result/g")>&1)
    done
  fi
  if [ "$TAGS_ONLY" == "false" ]; then
    contents=$(envsubst <<< "$contents")
  fi
  echo "$contents"
}

_replace_file() {
  local target_file="$1"
  local TAGS_ONLY="$2"
  local ENVS_ONLY="$3"
  if [ -d "$target_file" ]; then
    echo "Error: replace_tags is not supported for directories" >&2
    return 82
  fi
  if [ ! -f "$target_file" ]; then
    echo "Error: $target_file is not a valid file path." >&2
    return 82
  fi
  local path=$(dirname "$1")
  if [ "$path" != '.' ]; then
    mkdir -p "/tmp/replace_tags/$path"
  fi
  local temp_file="/tmp/replace_tags/$target_file"
  cp $target_file $temp_file
  if [ "$TAGS_ONLY" == "false" ]; then
    envsubst < "$target_file" > "$temp_file"
  fi
  if [ "$ENVS_ONLY" == "false" ]; then
    local isValid=$(jq type "$STEP_JSON_PATH" || true)
    if [ -z "$isValid" ]; then
      echo "Error: step.json is not valid JSON" >&2
      return 82
    fi
    local token_list=($(grep "%%[A-Za-z0-9_\-\.]*%%" -o $temp_file))
    for token in "${token_list[@]}"; do
      local json_path="${token//%%/}"
      local json_result=$(_search_stepjson "$json_path")
      if [ -z "$json_result" ]; then
        echo "Error: match not found in step.json for pattern: $token. Skipping." >&2
        continue
      fi
      local sed_result=$((echo $json_result|sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'|sed 's/[]]/\[]]/g')>&1)
      local sed_token=$((echo $token|sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'|sed 's/[]]/\[]]/g')>&1)
      sed -i "s/$sed_token/$sed_result/g" $temp_file
    done
  fi
  mv "$temp_file" "$path"
}

_search_stepjson() {
  local raw_path="$1"
  tmp_ifs=$IFS
  IFS='.' tokenized_json=(${raw_path})
  IFS=$tmp_ifs

  local type=${tokenized_json[0]}
  local name=${tokenized_json[1]}
  local key=${tokenized_json[2]}
  local count=${#tokenized_json[@]}
  if [ -z "$type" ] || [ -z "$name" ]; then
    return
  fi
  # general parsing logic:
  #  if there are 3 tokens, attempt to directly get the path
  #  if result is null, and it's a resource, check all property bags
  #  otherwise directly get the raw_path.

  local result=$(jq -r ".${raw_path}" "$STEP_JSON_PATH")
  if [ "$count" -eq "3" ] && [ "$type" == "resources" ]; then
    # check main path, then check each property bag.
    # 1. resourceVersionContentPropertyBag
    # 2. resourceConfigPropertyBag
    # 3. systemPropertyBag

    if [ "$result" == "null" ]; then
      result=$(jq -r ".${type}.${name}.resourceVersionContentPropertyBag.${key}" "$STEP_JSON_PATH")
      if [ "$result" == "null" ]; then
        result=$(jq -r ".${type}.${name}.resourceConfigPropertyBag.${key}" "$STEP_JSON_PATH")
        if [ "$result" == "null" ]; then
          result=$(jq -r ".${type}.${name}.systemPropertyBag.${key}" "$STEP_JSON_PATH")
          if [ "$result" == "null" ]; then
            result=""
          fi
        fi
      fi
    fi
  fi
  if [ "$result" != "null" ]; then
    echo -n "$result"
  fi
}

git_changes() {
  if [[ $# -le 0 ]]; then
    echo "Usage: git_changes [--path | --resource]" >&2
    exit 99
  fi

  # declare options
  local opt_path=""
  local opt_resource=""
  local opt_depth=0
  local opt_directories_only=false
  local opt_commit_range=""

  for arg in "$@"
  do
    case $arg in
      --path)
      opt_path="$2"
      shift
      shift
      ;;
      --resource)
      opt_resource="$2"
      shift
      shift
      ;;
      --depth)
      opt_depth="$2"
      shift
      shift
      ;;
      --directories-only)
      opt_directories_only=true
      shift
      ;;
      --commit-range)
      opt_commit_range="$2"
      shift
      shift
      ;;
    esac
  done

  # obtain the path of git repository
  if [[ "$opt_path" == "" ]] && [[ "$opt_resource" == "" ]]; then
    echo "Usage: get_git_changes [--path|--resource]" >&2
    exit 99
  fi

  # set file path of git repository
  local git_repo_path="$opt_path"
  if [[ "$git_repo_path" == "" ]]; then
    local dependency_type=$(cat "$STEP_JSON_PATH" | jq -r '.'"$2")
    git_repo_path="$STEP_DEPENDENCY_STATE_DIR/resources/$opt_resource/gitRepo"
  fi

  if [[ ! -d "$git_repo_path/.git" ]]; then
    echo "git repository not found at path: $git_repo_path" >&2
    exit 99
  fi

  # set default commit range
  # for CI
  local commit_range

  # for runSh with IN: gitRepo
  if [[ "$opt_resource" != "" ]]; then
    # for runSh with IN: gitRepo commits
    local current_commit_sha=$(cat "$STEP_JSON_PATH" | jq -r ."resources.$opt_resource.resourceVersionContentPropertyBag.shaData.commitSha")
    local before_commit_sha=$(cat "$STEP_JSON_PATH" | jq -r ."resources.$opt_resource.resourceVersionContentPropertyBag.shaData.beforeCommitSha")
    commit_range="$before_commit_sha..$current_commit_sha"

    # for runSh with IN: gitRepo pull requests
    local is_pull_request=local current_commit_sha=$(cat "$STEP_JSON_PATH" | jq -r ."resources.$opt_resource.resourceVersionContentPropertyBag.shaData.isPullRequest")
    if [[ "$is_pull_request" == "true" ]]; then
      local current_commit_sha=$(cat "$STEP_JSON_PATH" | jq -r ."resources.$opt_resource.resourceVersionContentPropertyBag.shaData.commitSha")
      local base_branch=$(cat "$STEP_JSON_PATH" | jq -r ."resources.$opt_resource.resourceVersionContentPropertyBag.shaData.pullRequestBaseBranch")
      commit_range="origin/$base_branch...$current_commit_sha"
    fi
  fi

  if [[ "$opt_commit_range" != "" ]]; then
    commit_range="$opt_commit_range"
  fi
  if [[ "$commit_range" == "" ]]; then
    echo "Unknown commit range. use --commit-range." >&2
    exit 99
  fi

  local result=""
  pushd $git_repo_path > /dev/null
    result=$(git diff --name-only $commit_range)

    if [[ "$opt_directories_only" == true ]]; then
      result=$(git diff --dirstat $commit_range | awk '{print $2}')
    fi

    if [[ $opt_depth -gt 0 ]]; then
      if [[ result != "" ]]; then
        result=$(echo "$result" | awk -F/ -v depth=$opt_depth '{print $depth}')
      fi
    fi
  popd > /dev/null

  echo "$result" | uniq
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
