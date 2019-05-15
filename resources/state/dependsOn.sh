download_resource_state() {
  local resourceName="$1"
  local resourceId=$(eval echo "$"res_"$resourceName"_resourceId)
  local artifactName=$(eval echo "$"res_"$resourceName"_artifactName)
  local archiveFile="$STEP_TMP_DIR/$resourceName/$artifactName"
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)

  mkdir -p $(dirname $archiveFile)
  mkdir -p $resourcePath

  if [ ! -z "$artifactName" ]; then
    local get_artifact_url="curl \
      -s \
      --connect-timeout 60 \
      --max-time 120 \
      -XGET '$SHIPPABLE_API_URL/resources/$resourceId/artifactUrl?artifactName=$artifactName' \
      -H 'Authorization: apiToken $BUILDER_API_TOKEN' \
      -H 'Content-Type: application/json'"
    local artifact_urls=$(eval $get_artifact_url)
    local artifact_get_url=$(echo $artifact_urls | jq -r '.get')
    local artifact_get_opts=$(echo $artifact_urls | jq -r '.getOpts')

    echo "Received a short lived download url for resource"
    echo 'Downloading archive'
    if [ -z "$artifact_get_opts" ]; then
      curl \
        -s \
        --connect-timeout 60 \
        --max-time 120 \
        -XGET "$artifact_get_url" \
        -o "$archiveFile"
    else
      curl \
        -s \
        "$artifact_get_opts" \
        --connect-timeout 60 \
        --max-time 120 \
        -XGET "$artifact_get_url" \
        -o "$archiveFile"
    fi

    tar -xzf $archiveFile -C $resourcePath

    rm $archiveFile
    echo 'Downloaded resource state'
  else
    echo 'No artifact to download'
  fi
}

execute_command "download_resource_state %%context.resourceName%%"
