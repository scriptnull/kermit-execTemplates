#!/bin/bash
set -e

export SCRIPT_PATH="$1"
export ENVS_PATH="$2"

# reqExec cannot handle all the responsibilities of a PID 1 which results in
# not-so-easily traceable crashes.
# Use bash to run reqExec, so that reqExec does not run as a PID 1.
main() {
  <%= obj.reqExecCommand %> "$SCRIPT_PATH" "$ENVS_PATH"
}

main
