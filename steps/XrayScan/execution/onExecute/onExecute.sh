scan() {
  local integrationAlias=$(eval echo "$"res_"$inputBuildInfoResourceName"_integrationAlias)
  local integrationName=$(eval echo "$"res_"$inputBuildInfoResourceName"_"$integrationAlias"_name)

  echo "[scan] Authenticating with integration: $integrationName"
  local rtUrl=$(eval echo "$"res_"$inputBuildInfoResourceName"_"$integrationAlias"_url)
  local rtUser=$(eval echo "$"res_"$inputBuildInfoResourceName"_"$integrationAlias"_user)
  local rtApiKey=$(eval echo "$"res_"$inputBuildInfoResourceName"_"$integrationAlias"_apikey)

  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

  local buildName=""
  local buildNumber=""
  if [ ! -z "$inputBuildInfoResourceName" ]; then
    echo "[scan] Using build name and number from BuildInfo resource: $inputBuildInfoResourceName"
    buildName=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildName)
    buildNumber=$(eval echo "$"res_"$inputBuildInfoResourceName"_buildNumber)
  fi

  if [ -z "$buildName" ] && [ -z "$buildNumber" ]; then
    echo "[scan] ERROR: Unable to find a build name and number to work with."
    echo "[scan] Please use an input BuildInfo resource."
    exit 1;
  fi

  echo "[scan] Scanning build $buildName/$buildNumber"
  jfrog rt bs $buildName $buildNumber

  if [ ! -z "$outputBuildInfoResourceName" ]; then
    echo -e "\n[scan] Updating output resource: $outputBuildInfoResourceName"

    replicate_resource $inputBuildInfoResourceName $outputBuildInfoResourceName
  fi
}

execute_command scan
