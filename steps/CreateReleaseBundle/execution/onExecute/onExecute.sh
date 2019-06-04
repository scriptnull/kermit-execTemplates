authenticate() {
  integrationName=$1
  local rtUrl=$(eval echo "$"int_"$integrationName"_url)
  local rtUser=$(eval echo "$"int_"$integrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$integrationName"_apikey)
  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
}

getArtifactoryServiceId() {
  local artifactoryServiceId=$(retry_command jfrog rt curl /api/system/service_id)
  echo $artifactoryServiceId
}

constructQueryForBuildInfoResources() {
  local aqlWrapperTemplate='items.find(QUERY).include("sha256","updated","modified_by","created","id","original_md5","depth","actual_sha1","property.value","modified","property.key","actual_md5","created_by","type","name","repo","original_sha1","size","path")'
  local aqlTemplate='{
    "$and": [
      {
        "$or": [
          REPO_FRAGMENTS
        ]
      },
      {
        "$or": [
          BUILD_FRAGMENTS
        ]
      }
    ]
  }
  '

  local repoFragmentTemplate='{
    "repo": { "$eq": "REPO_NAME" }
  }'

  local buildFragmentTemplate='{
    "$and": [
      {
        "artifact.module.build.name": {
          "$eq": "BUILD_NAME"
        }
      },
      {
        "artifact.module.build.number": {
          "$eq": "BUILD_NUMBER"
        }
      }
    ]
  }
  '

  local buildFragments=""
  local repoFragments=""
  for ((i=0; i<$buildInfoCount; i++))
  do
    local resName=$(eval echo "$"buildInfo$i)
    local buildName=$(eval echo "$"res_"$resName"_buildName)
    local buildNumber=$(eval echo "$"res_"$resName"_buildNumber)
    local targetRepo=$(eval echo '$'res_"$resName"_targetRepo)

    local buildFragment=$(echo "${buildFragmentTemplate/BUILD_NAME/$buildName}")
    local buildFragment=$(echo "${buildFragment/BUILD_NUMBER/$buildNumber}")

    if [ $i -gt 0 ]; then
      buildFragments+=', '
    fi
    buildFragments+="$buildFragment"

    repoFragment=$(echo "${repoFragmentTemplate/REPO_NAME/$targetRepo}")
    repoFragments+="$repoFragment"
  done

  aqlQuery=$(echo "${aqlTemplate/BUILD_FRAGMENTS/$buildFragments}")
  aqlQuery=$(echo "${aqlQuery/REPO_FRAGMENTS/$repoFragments}")

  aql=$(echo "${aqlWrapperTemplate/QUERY/$aqlQuery}")
  echo $aql
}

constructQueryForAqlResource() {
  aqlResName=$1

  local queryTemplate='{
    "aql": $aql,
    "query_name": $aqlResName,
    "mappings": [],
    "added_props": []
  }'

  local aql=$(eval echo "$"res_"$aqlResName"_query)
  aqlQuery=$(jq -n \
    --arg aql "$aql" \
    --arg aqlResName "$aqlResName" \
    "$queryTemplate")

  echo $aqlQuery
}

createPayload() {
  releaseBundleName=$1
  releaseBundleVersion=$2
  sourceArtifactoryId=$3

  local template='{
    "name": $releaseBundleName,
    "version": $releaseBundleVersion,
    "spec": {
      "source_artifactory_id": $sourceArtifactoryId,
      "queries": []
    }
  }'

  local queryTemplate='{
    "aql": $aql
  }'

  payload=$(jq -n \
    --arg releaseBundleName "$releaseBundleName" \
    --arg releaseBundleVersion "$releaseBundleVersion" \
    --arg sourceArtifactoryId "$sourceArtifactoryId" \
    "$template")

  if [ ! -z "$buildInfoCount" ]; then
    buildInfoAql=$(constructQueryForBuildInfoResources)
    buildInfoQuery=$(jq -n \
      --arg aql "$buildInfoAql" \
      "$queryTemplate")
    payload=$(echo $payload | jq --argjson json "$buildInfoQuery" '.spec.queries += [ $json ]')
  fi

  if [ ! -z "$aqlCount" ]; then
    for ((i=0; i<$aqlCount; i++))
    do
      aqlResName=$(eval echo "$"aql$i)
      aqlQuery=$(constructQueryForAqlResource "$aqlResName")
      payload=$(echo $payload | jq --argjson json "$aqlQuery" '.spec.queries += [ $json ]')
    done
  fi

  signed=$(jq -r ".step.configuration.signed" $STEP_JSON_PATH)
  if [ ! -z "$signed" ] && [ "$signed" != "null" ]; then
    payload=$(echo $payload | jq --arg sign_immediately $signed '. + {sign_immediately: $sign_immediately|test("true")}')
  fi

  if [ -z "$dryRun" ]; then
    dryRun=$(jq -r ".step.configuration.dryRun" $STEP_JSON_PATH)
  fi
  if [ ! -z "$dryRun" ] && [ "$dryRun" != "null" ]; then
    payload=$(echo $payload | jq --arg dry_run $dryRun '. + {dry_run: $dry_run|test("true")}')
  fi

  storeAtSourceArtifactory=$(jq -r ".step.configuration.storeAtSourceArtifactory" $STEP_JSON_PATH)
  if [ ! -z "$storeAtSourceArtifactory" ] && [ "$storeAtSourceArtifactory" != "null" ]; then
    payload=$(echo $payload | jq --arg store_at_source_artifactory $storeAtSourceArtifactory '. + {store_at_source_artifactory: $store_at_source_artifactory|test("true")}')
  fi

  description=$(jq -r ".step.configuration.description" $STEP_JSON_PATH)
  if [ ! -z "$description" ] && [ "$description" != "null" ]; then
    payload=$(echo $payload | jq --arg description $description '. + {description: $description}')
  fi

  releaseNotesContent=$(jq -r ".step.configuration.releaseNotes.content" $STEP_JSON_PATH)
  if [ ! -z "$releaseNotesContent" ] && [ "$releaseNotesContent" != "null" ]; then
    releaseNotes='{}'
    releaseNotes=$(echo $releaseNotes | jq --arg content $releaseNotesContent '. + {content: $content}')
    releaseNotesSyntax=$(jq -r ".step.configuration.releaseNotes.syntax" $STEP_JSON_PATH)
    if [ ! -z "$releaseNotesSyntax" ] && [ "$releaseNotesSyntax" != "null" ]; then
      releaseNotes=$(echo $releaseNotes | jq --arg syntax $releaseNotesSyntax '. + {syntax: $syntax}')
    fi
    payload=$(echo $payload | jq --argjson json "$releaseNotes" '.release_notes = $json')
  fi

  echo $payload
}

postRelease() {
  payloadPath=$1
  integrationName=$2
  local distUrl=$(eval echo "$"int_"$integrationName"_distributionUrl)
  local rtUser=$(eval echo "$"int_"$integrationName"_user)
  local rtApiKey=$(eval echo "$"int_"$integrationName"_apikey)

  if [ ! -z "$SIGNING_KEY_PASSPHRASE" ]; then
    STATUS=$(curl -o >(cat > $STEP_TMP_DIR/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      -H "X-GPG-PASSPHRASE: $SIGNING_KEY_PASSPHRASE" \
      "$distUrl/api/v1/release_bundle" -T $payloadPath)
  else
    STATUS=$(curl -o >(cat > $STEP_TMP_DIR/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      "$distUrl/api/v1/release_bundle" -T $payloadPath)
  fi

  res_body=$(cat $STEP_TMP_DIR/curl_res_body)
  if [ $STATUS -ge 200 ] && [ $STATUS -lt 300 ]; then
    echo $res_body | jq .
  else
    echo -e "\n[CreateReleaseBundle] Failed to create release bundle with error: "
    echo $res_body | jq .
    exit 1
  fi
}

createReleaseBundle() {
  local payloadFile="createReleaseBundlePayload.json"

  echo "[CreateReleaseBundle] Authenticating with integration: $artifactoryIntegrationName"
  authenticate $artifactoryIntegrationName

  echo -e "\n[CreateReleaseBundle] Getting Artifactory service id"
  local artifactoryServiceId=$(getArtifactoryServiceId)

  releaseBundleName=$(jq -r ".step.configuration.releaseBundleName" $STEP_JSON_PATH)
  releaseBundleVersion=$(jq -r ".step.configuration.releaseBundleVersion" $STEP_JSON_PATH)
  echo -e "\n[CreateReleaseBundle] Creating payload for release bundle"
  payload=$(createPayload "$releaseBundleName" "$releaseBundleVersion" "$artifactoryServiceId")
  echo $payload | jq . > $STEP_TMP_DIR/$payloadFile
  # TODO: remove this after testing
  cat $STEP_TMP_DIR/$payloadFile

  echo -e "\n[CreateReleaseBundle] Creating Release Bundle with name: "$releaseBundleName" and version: "$releaseBundleVersion""
  postRelease $STEP_TMP_DIR/$payloadFile $artifactoryIntegrationName

  if [ ! -z "$outputReleaseBundleResourceName" ]; then
    echo -e "\n[CreateReleaseBundle] Updating output resource: $outputReleaseBundleResourceName"
    write_output $outputReleaseBundleResourceName name=$releaseBundleName version=$releaseBundleVersion isSigned=$signed
  fi
}

execute_command createReleaseBundle
