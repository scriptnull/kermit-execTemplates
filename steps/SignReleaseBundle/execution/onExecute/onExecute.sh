signReleaseBundle() {
  local integrationAlias=$(eval echo "$"res_"$inputReleaseBundleResourceName"_integrationAlias)
  local distUrl=$(eval echo "$"res_"$inputReleaseBundleResourceName"_"$integrationAlias"_distributionUrl)
  local rtUser=$(eval echo "$"res_"$inputReleaseBundleResourceName"_"$integrationAlias"_user)
  local rtApiKey=$(eval echo "$"res_"$inputReleaseBundleResourceName"_"$integrationAlias"_apikey)
  local releaseBundleName=$(eval echo "$"res_"$inputReleaseBundleResourceName"_name)
  local releaseBundleVersion=$(eval echo "$"res_"$inputReleaseBundleResourceName"_version)

  echo "[SignReleaseBundle] Signing Release Bundle with name: "$releaseBundleName" and version: "$releaseBundleVersion""
  if [ ! -z "$SIGNING_KEY_PASSPHRASE" ]; then
    STATUS=$(curl -o >(cat > $step_tmp_dir/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      -H "X-GPG-PASSPHRASE: $SIGNING_KEY_PASSPHRASE" \
      "$distUrl/api/v1/release_bundle/$releaseBundleName/$releaseBundleVersion/sign")
  else
    STATUS=$(curl -o >(cat > $step_tmp_dir/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      "$distUrl/api/v1/release_bundle/$releaseBundleName/$releaseBundleVersion/sign")
  fi

  jq . $step_tmp_dir/curl_res_body > $step_tmp_dir/"$step_name"_response.json
  save_run_state $step_tmp_dir/"$step_name"_response.json .
  if [ $STATUS -ge 200 ] && [ $STATUS -lt 300 ]; then
    echo -e "\n[SignReleaseBundle] Successfully signed release bundle."
    echo -e "\n[SignReleaseBundle] Download run state and check the content of "$step_name"_response.json to check the complete response."
  else
    echo -e "\n[SignReleaseBundle] Failed to sign release bundle with error: "
    cat $step_tmp_dir/"$step_name"_response.json
    exit 1
  fi

  if [ ! -z "$outputReleaseBundleResourceName" ]; then
    echo -e "\n[SignReleaseBundle] Updating output resource: $outputReleaseBundleResourceName"
    write_output $outputReleaseBundleResourceName name=$releaseBundleName version=$releaseBundleVersion isSigned=true
  fi
}

execute_command signReleaseBundle
