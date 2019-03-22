#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"

# shellcheck source=Ubuntu_16.04/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=Ubuntu_16.04/resources/common/_logger.sh
source "$LOGGER_PATH"

export RESOURCE_NAME=""
export SCOPES=""
export AWS_ACCESS_KEY=""
export AWS_SECRET_KEY=""
export RESOURCE_VERSION_PATH=""
export AWS_REGION=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  AWS_ACCESS_KEY="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "aws_access_key_id" )"
  AWS_SECRET_KEY="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "aws_secret_access_key" )"
  RESOURCE_VERSION_PATH="$(shipctl get_resource_meta "$RESOURCE_NAME")/version.json"
  AWS_REGION="$( shipctl get_json_value "$RESOURCE_VERSION_PATH" "version.propertyBag.region" )"

  if _is_empty "$AWS_ACCESS_KEY"; then
    _log_err "Missing 'aws_access_key_id' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$AWS_SECRET_KEY"; then
    _log_err "Missing 'aws_secret_access_key' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$AWS_REGION"; then
    _log_err "Missing 'region' value in pointer section of $RESOURCE_NAME's yml"
    exit 1
  fi

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  aws configure set aws_access_key_id "$AWS_ACCESS_KEY"
  aws configure set aws_secret_access_key "$AWS_SECRET_KEY"
  aws configure set region "$AWS_REGION"

  _log_success "Successfully initialized scope configure"
}

init_scope_ecr() {
  _log_msg "Initializing scope ecr"

  if _is_docker_email_deprecated; then
    docker_login_cmd=$( aws ecr get-login --no-include-email )
  else
    docker_login_cmd=$( aws ecr get-login )
  fi

  $docker_login_cmd

  _log_success "Successfully initialized scope ecr"
}

init() {
  RESOURCE_NAME=${ARGS[0]}
  SCOPES=${ARGS[1]}

  _log_grp "Initializing ECR for resource $RESOURCE_NAME"

  check_params
  init_scope_configure
  init_scope_ecr
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
