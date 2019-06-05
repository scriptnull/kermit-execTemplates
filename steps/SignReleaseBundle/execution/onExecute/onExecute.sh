signReleaseBundle() {
  local distUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_distributionUrl)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  local releaseBundleName=$(eval echo "$"res_"$inputReleaseBundleResourceName"_name)
  local releaseBundleVersion=$(eval echo "$"res_"$inputReleaseBundleResourceName"_version)

  echo "[SignReleaseBundle] Signing Release Bundle with name: "$releaseBundleName" and version: "$releaseBundleVersion""
  if [ ! -z "$SIGNING_KEY_PASSPHRASE" ]; then
    STATUS=$(curl -o >(cat > $STEP_TMP_DIR/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      -H "X-GPG-PASSPHRASE: $SIGNING_KEY_PASSPHRASE" \
      "$distUrl/api/v1/release_bundle/$releaseBundleName/$releaseBundleVersion/sign")
  else
    STATUS=$(curl -o >(cat > $STEP_TMP_DIR/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      "$distUrl/api/v1/release_bundle/$releaseBundleName/$releaseBundleVersion/sign")
  fi

  jq . $STEP_TMP_DIR/curl_res_body > $STEP_TMP_DIR/"$STEP_NAME"_response.json
  save_run_state $STEP_TMP_DIR/"$STEP_NAME"_response.json .
  if [ $STATUS -ge 200 ] && [ $STATUS -lt 300 ]; then
    echo -e "\n[SignReleaseBundle] Successfully signed release bundle."
    echo -e "\n[SignReleaseBundle] Download run state and check the content of "$STEP_NAME"_response.json to check the complete response."
  else
    echo -e "\n[SignReleaseBundle] Failed to sign release bundle with error: "
    cat $STEP_TMP_DIR/"$STEP_NAME"_response.json
    exit 1
  fi

  if [ ! -z "$outputReleaseBundleResourceName" ]; then
    echo -e "\n[SignReleaseBundle] Updating output resource: $outputReleaseBundleResourceName"
    write_output $outputReleaseBundleResourceName name=$releaseBundleName version=$releaseBundleVersion isSigned=true
  fi
}

execute_command signReleaseBundle
