#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"
readonly CLICONFIG_SCRIPT_DIR="$ROOT_DIR/resources/cliConfig"

# shellcheck source=Ubuntu_16.04/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=Ubuntu_16.04/resources/common/_logger.sh
source "$LOGGER_PATH"

export FILE_URI=""
export IS_PULL_TRUE=""
export RESOURCE_META_PATH=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name>
  "
}

check_params() {
  _log_msg "Checking params"

  FILE_URI="$( shipctl get_json_value "$RESOURCE_META_PATH/version.json" "version.propertyBag.sourceName" )"

  if _is_empty "$FILE_URI"; then
    _log_err "Missing 'sourceName' value in version for $RESOURCE_NAME."
    exit 1
  fi

  _log_success "Successfully checked params"
}

get_file() {
  if _is_empty "$1"; then
    _log_err "A path to save file to is required."
    exit 1
  fi

  _log_msg "Starting to fetch file"

  wget "$FILE_URI" -P "$1"

  _log_success "Successfully fetched file"
}

init() {
  RESOURCE_NAME=${ARGS[0]}
  RESOURCE_META_PATH="$( shipctl get_resource_meta "$RESOURCE_NAME" )"
  RESOURCE_STATE_PATH="$( shipctl get_resource_state "$RESOURCE_NAME" )"

  IS_PULL_TRUE="$( shipctl get_json_value "$RESOURCE_META_PATH/version.json" "versionDependencyPropertyBag.pull" )"
  INT_MASTER_NAME=""
  if [ -e "$RESOURCE_META_PATH/integration.json" ]; then
    INT_MASTER_NAME="$( shipctl get_json_value "$RESOURCE_META_PATH/integration.json" "masterName" )"
  fi

  if [ "$IS_PULL_TRUE" == "true" ]; then
    check_params
    if [ ! -z "$INT_MASTER_NAME" ]; then
      echo "TODO: add file resource with int handling in next pm"
    else
      get_file "$RESOURCE_STATE_PATH"
    fi
  fi
}

main() {
  if [[ "${#ARGS[@]}" -gt 0 ]]; then
    case "${ARGS[0]}" in
      --help)
        help
        exit 0
        ;;
      *)
        init
        ;;
    esac
  else
    help
    exit 1
  fi
}

main
