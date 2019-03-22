#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"

# shellcheck source=macOS_10.12/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=macOS_10.12/resources/common/_logger.sh
source "$LOGGER_PATH"

export RESOURCE_NAME=""
export SCOPE=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scope]
  "
}

cleanup_scope_configure() {
  _log_msg "Cleaning up scope configure"

  local aws_config_path
  aws_config_path=~/.aws
  if [ -d "$aws_config_path" ]; then
    rm -rf $aws_config_path
  fi

  _log_success "Successfully cleaned up scope configure"
}

cleanup_scope_ecr() {
  _log_msg "Cleaning up scope ecr"

  local docker_config_path
  docker_config_path=~/.docker
  if [ -d "$docker_config_path" ]; then
    rm -rf $docker_config_path
  fi

  _log_success "Successfully cleaned up scope ecr"
}

cleanup() {
  RESOURCE_NAME=${ARGS[0]}
  SCOPES=${ARGS[1]}

  _log_grp "Cleaning up resource $RESOURCE_NAME"

  cleanup_scope_configure
  if _csv_has_value "$SCOPES" "ecr"; then
    cleanup_scope_ecr
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
        cleanup
        ;;
    esac
  else
    help
    exit 1
  fi
}

main
