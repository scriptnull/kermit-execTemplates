promote() {
  echo "[promote] Authenticating with integration: $artifactoryIntegrationName"
  local rtUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_url)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  if [ -z "$buildName " ] && [ -z "$buildNumber" ]; then
    if [ ! -z "$inputBuildInfoResourceName" ]; then
      echo "[promote] Using build name and number from buildInfo resource: $inputBuildInfoResourceName"
      buildName=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildName)
      buildNumber=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildNumber)
    fi
  fi

  echo "[promote] Promoting build $buildName/$buildNumber to $targetRepo"
  retry_command jfrog rt build-promote $buildName $buildNumber $targetRepo

  if [ ! -z "$outputPromoteInfoResourceName" ]; then
    echo "[promote] Updating output resource $outputPromoteInfoResourceName"
    write_output $outputPromoteInfoResourceName buildName=$buildName buildNumber=$buildNumber targetRepo=$targetRepo
  fi
}

execute_command promote
