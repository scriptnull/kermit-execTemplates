#!/bin/bash -e

kubernetesConfig_configure() {
  local integrationName="$1"
  local intMasterName=$(eval echo "$"int_"$integrationName"_masterName)

  if [ "$intMasterName" == "kubernetesConfig" ]; then
    local kubeconfigVar="int_""$integrationName""_kubeconfig"
    local kubeconfig=$(echo "${!kubeconfigVar}")

    mkdir -p $step_workspace_dir/$integrationName
    export KUBECONFIG=$step_workspace_dir/$integrationName/config

    echo "$kubeconfig" > $KUBECONFIG
  fi
}

execute_command "kubernetesConfig_configure %%context.name%%"
