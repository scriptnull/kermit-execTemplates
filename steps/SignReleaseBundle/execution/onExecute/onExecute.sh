signReleaseBundle() {
  echo "[SignReleaseBundle] Signing Release Bundle with name: "$bundleName" and version: "$bundleVersion""
  local distUrl=$(eval echo "$"int_"$artifactoryIntegrationName"_distributionUrl)
  local rtUser=$(eval echo "$"int_"$artifactoryIntegrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$artifactoryIntegrationName"_apikey)
  local releaseBundleName=$(eval echo "$"res_"$inputReleaseBundleResourceName"_name)
  local releaseBundleVersion=$(eval echo "$"res_"$inputReleaseBundleResourceName"_version)

  if [ ! -z "$SIGNING_KEY_PASSPHRASE" ]; then
    curl -XPOST -u $rtUser:$rtApiKey -H "Content-Type: application/json" \
      -H "X-GPG-PASSPHRASE: $SIGNING_KEY_PASSPHRASE" \
      "$distUrl/api/v1/release_bundle/$releaseBundleName/$releaseBundleVersion/sign"
  else
    curl -XPOST -u $rtUser:$rtApiKey -H "Content-Type: application/json" \
      "$distUrl/api/v1/release_bundle/$releaseBundleName/$releaseBundleVersion/sign"
  fi

  if [ ! -z "$outputReleaseBundleResourceName" ]; then
    echo "[CreateReleaseBundle] Updating output resource: $outputReleaseBundleResourceName"
    write_output $outputReleaseBundleResourceName name=$releaseBundleName version=$releaseBundleVersion isSigned=true
  fi
}

execute_command signReleaseBundle
