#!/bin/bash -e

kubernetesConfig_cleanup() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "kubernetesConfig" ]; then
    unset KUBECONFIG

    if [ -f $step_workspace_dir/$integrationName/config ]; then
      echo "Removing configuration file"
      rm $step_workspace_dir/$integrationName/config
    fi
  fi
}

echo "kubernetesConfig_cleanup %%context.name%%"
kubernetesConfig_cleanup "%%context.name%%"
