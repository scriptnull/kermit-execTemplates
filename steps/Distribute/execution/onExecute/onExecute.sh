distribute() {
  local curlResponseFile=$step_tmp_dir/response

  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  local distributionUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_distributionUrl)

  if [ -z "$distributionUrl" ]; then
    echo "[Distribute] ERROR: The integration specified doesn't have Distribution"
    echo "[Distribute] URL configured. Please specify a distribution URL for"
    echo "[Distribute] $artifactoryIntegrationName artifactory integration."
    exit 1
  fi

  # get releaseBundleName, releaseBundleVersion
  local releaseBundleName=""
  local releaseBundleVersion=""
  local dryRun=true
  local stepConfiguration=$(cat $step_json_path | jq .step.configuration)
  if [ ! -z "$stepConfiguration" ] && [ "$stepConfiguration" != "null" ]; then
    local configBundleName=$(echo $stepConfiguration | jq -r .releaseBundleName)
    local configBundleVersion=$(echo $stepConfiguration | jq -r .releaseBundleVersion)
    if [ "$configBundleName" != "null" ] && [ ! -z "$configBundleName" ]; then
      releaseBundleName="$configBundleName"
    fi
    if [ "$configBundleVersion" != "null" ] && [ ! -z "$configBundleVersion" ]; then
      releaseBundleVersion="$configBundleVersion"
    fi
    if [ $(echo $stepConfiguration | jq -r .dryRun) == "false" ]; then
      dryRun=false
    fi
  fi
  if [ -z "$releaseBundleName" ]; then
    if [ ! -z "$inputReleaseBundleResourceName" ]; then
       releaseBundleName=$(eval echo "$"res_"$inputReleaseBundleResourceName"_name)
    fi
  fi
  if [ -z "$releaseBundleVersion" ]; then
    if [ ! -z "$inputReleaseBundleResourceName" ]; then
      releaseBundleVersion=$(eval echo "$"res_"$inputReleaseBundleResourceName"_version)
    fi
  fi
  if [ -z "$releaseBundleName" ] || [ -z "$releaseBundleVersion" ]; then
    echo "[Distribute] ERROR: Unable to find a bundle name and bundle number to"
    echo "[Distribute] work with. Please use a input ReleaseBundle resource or"
    echo "[Distribute] specify releaseBundleName and releaseBundleVersion in configuration"
    echo "[Distribute] step of $step_name Distribute step."
    exit 1;
  fi

  # create the payload to be POSTed
  local body="{\"dry_run\": $dryRun, \"distribution_rules\": []}"
  for (( i=0; i<$inputDistributionRuleResourcesCount; i++ )); do
    local distributionRuleResourceName=$(eval echo "$"inputDistributionRuleResourceName"$i")
    local serviceNameVar="res_"$distributionRuleResourceName"_serviceName"
    local serviceName=$(echo "${!serviceNameVar}")
    local cityNameVar="res_"$distributionRuleResourceName"_cityName"
    local cityName=$(echo "${!cityNameVar}")
    local siteNameVar="res_"$distributionRuleResourceName"_siteName"
    local siteName=$(echo "${!siteNameVar}")
    local distributionRuleResourceObject="{\"service_name\": \"$serviceName\", \"site_name\": \"$siteName\", \"city_name\": \"$cityName\", \"country_codes\": []}"
    local countryCodes=$(eval echo "$"res_"$distributionRuleResourceName"_countryCodes)
    local countryCodeCount=$(echo $countryCodes | jq  -r .countryCodeCount)
    for (( j=1; j<=$countryCodeCount; j++ )); do
      local countryCodeIndex="countryCode$j"
      if [ $j -lt 10 ]; then
        countryCodeIndex="countryCode0$j"
      fi
      local countryCode=$(echo $countryCodes | jq -r .$countryCodeIndex)
      distributionRuleResourceObject=$(echo $distributionRuleResourceObject | jq --arg countryCode "$countryCode" '.country_codes += [ $countryCode ]')
    done
    body=$(echo $body | jq --argjson json "$distributionRuleResourceObject" '.distribution_rules += [ $json ]')
  done

  # distribute the release bundle
  echo "[Distribute] Distributing bundle $releaseBundleName/$releaseBundleVersion"
  local status=$(curl --silent --write-out "%{http_code}\n" --output \
    $curlResponseFile -POST \
    "$distributionUrl/api/v1/distribution/$releaseBundleName/$releaseBundleVersion" \
    -d "$body" -u $rtUser:$rtApiKey -H 'Content-Type: application/json')
  local response=$(cat $curlResponseFile)
  if [ $status -gt 299 ]; then
    echo "[Distribute] Distribution failed with status code $statusCode"
    if [ $status -eq 404 ]; then
      echo "[Distribute] Release bundle $releaseBundleName/$releaseBundleVersion not found"
    elif [ $status -eq 400 ]; then
      echo "[Distribute] Release bundle version $releaseBundleVersion must be signed before distribution"
    fi
    exit 1
  elif [ $status -eq 200 ]; then
    echo "[Distribute] Dry run for bundle $releaseBundleName/$releaseBundleVersion finished successfully"
    echo $response | jq .
    return 0
  elif [ $status -eq 202 ]; then
    echo "[Distribute] Successfully scheduled distribution of release bundle $releaseBundleName/$releaseBundleVersion"
  fi
  # sleep before getting distribution status, so that the distribution is
  # started. Distribution's internal interval is 5 seconds. Sleeping for 6
  # just to be safe
  echo "[Distribute] Waiting for scheduled distribution to start"
  sleep 6

  # track the distribution using the tracker id
  # funky logic to get the id as jq can't be used as the id's type is long
  local responeWithoutSpaces=$(echo $response | tr -d '[:space:]')
  local idFromResponse=$(echo $responeWithoutSpaces | grep -o "\"id\":.*")
  local trackerId=$(echo ${idFromResponse:5} | cut -d "," -f 1)
  if [ -z "$trackerId" ] || [ "$trackerId" == "null" ]; then
    echo "[Distribute] tracker id returned from the Distribute api is empty"
    exit 1
  fi
  local checkDistributionStatusCmd="rm -f $curlResponseFile && curl --silent --write-out \"%{http_code}\n\" --output $curlResponseFile -GET \"$distributionUrl/api/v1/release_bundle/$releaseBundleName/$releaseBundleVersion/distribution/$trackerId\" -u $rtUser:$rtApiKey"
  local distributionStatus=$(eval $checkDistributionStatusCmd)
  if [ $distributionStatus -lt 299 ] && [ "$(cat $curlResponseFile | jq -r .status)" == "Not distributed" ]; then
    echo "[Distribute] Distribution of bundle $releaseBundleName/$releaseBundleVersion failed with status: Not distributed"
    exit 1
  fi
  echo "[Distribute] Tracking distribution with tracker id: $trackerId"
  local sleeperCount=2
  while [ $distributionStatus -lt 299 ] && [ "$(cat $curlResponseFile | jq -r .status)" == "In progress" ]; do
    echo "[Distribute] Distribution in progress. Waiting $sleeperCount seconds to check distribution status again"
    sleep $sleeperCount
    sleeperCount=$(($sleeperCount + $sleeperCount))
    if [ $sleeperCount -gt 64 ]; then
      sleeperCount=2
    fi
    distributionStatus=$(eval $checkDistributionStatusCmd)
  done
  if [ "$(cat $curlResponseFile | jq -r .status)" == "Completed" ]; then
    echo "[Distribute] Distributed bundle $releaseBundleName/$releaseBundleVersion successfully"
  else
    echo "[Distribute] Failed to Distribute bundle $releaseBundleName/$releaseBundleVersion with status: $(cat $curlResponseFile | jq -r .status)"
    cat $curlResponseFile | jq .
    exit 1
  fi
}

execute_command distribute
