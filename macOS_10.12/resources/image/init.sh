#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"
readonly CLICONFIG_SCRIPT_DIR="$ROOT_DIR/resources/cliConfig"

# shellcheck source=macOS_10.12/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=macOS_10.12/resources/common/_logger.sh
source "$LOGGER_PATH"

export IMAGE_NAME=""
export IMAGE_TAG=""
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

  IMAGE_NAME="$( shipctl get_json_value "$RESOURCE_META_PATH/version.json" "version.propertyBag.sourceName" )"
  IMAGE_TAG="$( shipctl get_json_value "$RESOURCE_META_PATH/version.json" "version.versionName" )"

  if _is_empty "$IMAGE_NAME"; then
    _log_err "Missing 'sourceName' value in version for $RESOURCE_NAME."
    exit 1
  fi

  if _is_empty "$IMAGE_TAG"; then
    _log_err "Missing 'versionName' value in version for $RESOURCE_NAME."
    exit 1
  fi

  _log_success "Successfully checked params"
}

pull_image() {
  _log_msg "Starting image pull"

  docker pull "$IMAGE_NAME:$IMAGE_TAG"

  _log_success "Successfully pulled image"
}

init() {
  RESOURCE_NAME=${ARGS[0]}
  RESOURCE_META_PATH="$( shipctl get_resource_meta "$RESOURCE_NAME" )"

  IS_PULL_TRUE="$( shipctl get_json_value "$RESOURCE_META_PATH/version.json" "versionDependencyPropertyBag.pull" )"
  INT_MASTER_NAME=""
  if [ -e "$RESOURCE_META_PATH/integration.json" ]; then
    INT_MASTER_NAME="$( shipctl get_json_value "$RESOURCE_META_PATH/integration.json" "masterName" )"
  fi

  if [ "$IS_PULL_TRUE" == "true" ]; then
    check_params
    if [ ! -z "$INT_MASTER_NAME" ]; then
      if [ "$INT_MASTER_NAME" == "amazonKeys" ]; then
        "$CLICONFIG_SCRIPT_DIR/$INT_MASTER_NAME/init.sh" "$RESOURCE_NAME" "ecr"
      elif [ "$INT_MASTER_NAME" == "gcloudKey" ]; then
        "$CLICONFIG_SCRIPT_DIR/$INT_MASTER_NAME/init.sh" "$RESOURCE_NAME" "gcr"
      else
        "$CLICONFIG_SCRIPT_DIR/$INT_MASTER_NAME/init.sh" "$RESOURCE_NAME"
      fi
    fi
    pull_image
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
