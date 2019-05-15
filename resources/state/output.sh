upload_resource_state() {
  local resourceName="$1"
  local resourceId=$(eval echo "$"res_"$resourceName"_resourceId)
  local artifactName=$(date "+%Y%m%d-%H%M%S")".tar.gz"
  local archiveFile="$STEP_TMP_DIR/$resourceName/$artifactName"
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)

  mkdir -p $(dirname $archiveFile)
  tar -czf $archiveFile -C $resourcePath .

  local get_artifact_url="curl \
    -s \
    --connect-timeout 60 \
    --max-time 120 \
    -XGET '$SHIPPABLE_API_URL/resources/$resourceId/artifactUrl?artifactName=$artifactName' \
    -H 'Authorization: apiToken $BUILDER_API_TOKEN' \
    -H 'Content-Type: application/json'"

  local artifact_url=$(eval $get_artifact_url | jq -r '.put')
  local artifact_opts=$(eval $get_artifact_url | jq -r '.putOpts')
  echo "Received a short lived upload url for resource"

  if [ -z "$artifact_opts" ]; then
    curl \
      -s \
      --connect-timeout 60 \
      --max-time 120 \
      -XPUT "$artifact_url" \
      -T "$archiveFile"
  else
    curl \
      -s \
      "$artifact_opts" \
      --connect-timeout 60 \
      --max-time 120 \
      -XPUT "$artifact_url" \
      -T "$archiveFile"
  fi

  write_output $resourceName "artifactName=$artifactName"

  rm $archiveFile

  echo 'Saved resource state'
}

execute_command "upload_resource_state %%context.resourceName%%"
