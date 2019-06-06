#!/bin/bash -e

get_cluster() {
  local resourceName="$1"
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)
  local intMasterName=$(eval echo "$"res_"$resourceName"_int_masterName)

  if [ "$intMasterName" == "kubernetesConfig" ]; then
    local kubeconfig=$(eval echo "$"res_"$resourceName"_int_kubeconfig)

    mkdir -p ~/.kube
    echo "$kubeconfig" > ~/.kube/config
  fi
  echo "Successfully configured"
}

execute_command "get_cluster %%context.resourceName%%"
