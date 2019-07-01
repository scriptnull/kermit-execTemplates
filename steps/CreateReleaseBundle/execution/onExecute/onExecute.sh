authenticate() {
  resourceName=$1
  local integrationAlias=$(eval echo "$"res_"$resourceName"_integrationAlias)
  local rtUrl=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_url)
  local rtUser=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_user)
  local rtApiKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_apikey)

  retry_command jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false
}

getArtifactoryServiceId() {
  local artifactoryServiceId=$(retry_command jfrog rt curl -XGET /api/system/service_id)
  echo $artifactoryServiceId
}

constructQueryForBuildInfoResources() {
  local aqlWrapperTemplate='items.find(QUERY).include("sha256","updated","modified_by","created","id","original_md5","depth","actual_sha1","property.value","modified","property.key","actual_md5","created_by","type","name","repo","original_sha1","size","path")'
  local aqlTemplate='{
    "$and": AQL_QUERY
  }
  '

  local repoFragmentsTemplate='{
    "$or": [
      REPO_FRAGMENTS
    ]
  }'

  local buildFragmentsTemplate='{
    "$or": [
      BUILD_FRAGMENTS
    ]
  }'

  local repoFragmentTemplate='{
    "repo": { "$eq": "REPO_NAME" }
  }'

  local buildFragmentTemplate='{
    "$and": [
      {
        "@build.name": {
          "$eq": "BUILD_NAME"
        }
      },
      {
        "@build.number": {
          "$eq": "BUILD_NUMBER"
        }
      }
    ]
  }
  '

  local buildFragments=""
  local repoFragments=""
  local buildFragmentsForAql=""
  local repoFragmentsForAql=""
  for ((i=0; i<$buildInfoCount; i++))
  do
    local resName=$(eval echo "$"buildInfo$i)
    local buildName=$(eval echo "$"res_"$resName"_buildName)
    local buildNumber=$(eval echo "$"res_"$resName"_buildNumber)
    local targetRepo=$(eval echo '$'res_"$resName"_targetRepo)

    local buildFragment=$(echo "${buildFragmentTemplate/BUILD_NAME/$buildName}")
    local buildFragment=$(echo "${buildFragment/BUILD_NUMBER/$buildNumber}")

    # TODO: add logic to add buildFragments only if buildName & buildNumber are
    # present, when required.
    if [ ! -z "$buildFragments" ]; then
      buildFragments+=', '
    fi
    buildFragments+="$buildFragment"

    if [ ! -z "$targetRepo" ]; then
      if [ ! -z "$repoFragments" ]; then
        repoFragments+=', '
      fi
      repoFragment=$(echo "${repoFragmentTemplate/REPO_NAME/$targetRepo}")
      repoFragments+="$repoFragment"
    fi
  done

  if [ ! -z "$buildFragments" ]; then
    buildFragmentsForAql=$(echo "${buildFragmentsTemplate/BUILD_FRAGMENTS/$buildFragments}")
  fi
  if [ ! -z "$repoFragments" ]; then
    repoFragmentsForAql=$(echo "${repoFragmentsTemplate/REPO_FRAGMENTS/$repoFragments}")
  fi

  local aqlQuery='[]'
  if [ ! -z "$buildFragmentsForAql" ]; then
    aqlQuery=$(echo $aqlQuery | jq --argjson json "$buildFragmentsForAql" '. += [ $json ]')
  fi
  if [ ! -z "$repoFragmentsForAql" ]; then
    aqlQuery=$(echo $aqlQuery | jq --argjson json "$repoFragmentsForAql" '. += [ $json ]')
  fi

  aqlQuery=$(echo "${aqlTemplate/AQL_QUERY/$aqlQuery}")

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

  addedProperties=$(jq -r ".resources."$aqlResName".resourceVersionContentPropertyBag.addedProperties" $step_json_path)
  if [ ! -z "$addedProperties" ] && [ "$addedProperties" != "null" ]; then
    local keys=$(echo $addedProperties | jq 'keys')
    local keyCount=$(echo $keys | jq '. | length')
    if [ $keyCount -ne 0 ]; then
      for i in $(seq 1 $keyCount); do
        local key=$(echo $keys | jq '.['"$i-1"']')
        local values=$(echo $addedProperties | jq '.'"$key"'')
        property='{}'
        property=$(echo $property | jq --argjson json "$key" '.key = $json')
        property=$(echo $property | jq --argjson json "$values" '.values = [ $json ]')
        aqlQuery=$(echo $aqlQuery | jq --argjson json "$property" '.added_props += [ $json ]')
      done
    fi
  fi

  mappingsLen=$(eval echo "$"res_"$aqlResName"_mappings_len)
  if [ ! -z "$mappingsLen" ]; then
    for i in $(seq 0 $(( mappingsLen -  1 ))); do
      local mappingValue='{"input": "", "output": ""}'
      local mappingInput=$(eval echo "$"res_"$aqlResName"_mappings_"$i"_input)
      mappingValue=$(echo $mappingValue | jq '.input = "'$mappingInput'"')
      local mappingOutput=$(eval echo "$"res_"$aqlResName"_mappings_"$i"_output)
      mappingValue=$(echo $mappingValue | jq '.output = "'$mappingOutput'"')
      aqlQuery=$(echo $aqlQuery | jq --argjson json "$mappingValue" '.mappings += [ $json ]')
    done
  fi

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

  sign=$(jq -r ".step.configuration.sign" $step_json_path)
  if [ ! -z "$sign" ] && [ "$sign" != "null" ]; then
    payload=$(echo $payload | jq --arg sign_immediately $sign '. + {sign_immediately: $sign_immediately|test("true")}')
  fi

  if [ -z "$dryRun" ]; then
    dryRun=$(jq -r ".step.configuration.dryRun" $step_json_path)
  fi
  if [ ! -z "$dryRun" ] && [ "$dryRun" != "null" ]; then
    payload=$(echo $payload | jq --arg dry_run $dryRun '. + {dry_run: $dry_run|test("true")}')
  fi

  storeAtSourceArtifactory=$(jq -r ".step.configuration.storeAtSourceArtifactory" $step_json_path)
  if [ ! -z "$storeAtSourceArtifactory" ] && [ "$storeAtSourceArtifactory" != "null" ]; then
    payload=$(echo $payload | jq --arg store_at_source_artifactory $storeAtSourceArtifactory '. + {store_at_source_artifactory: $store_at_source_artifactory|test("true")}')
  fi

  description=$(jq -r ".step.configuration.description" $step_json_path)
  if [ ! -z "$description" ] && [ "$description" != "null" ]; then
    payload=$(echo $payload | jq --arg description "$description" '. + {description: $description}')
  fi

  releaseNotesContent=$(jq -r ".step.configuration.releaseNotes.content" $step_json_path)
  if [ ! -z "$releaseNotesContent" ] && [ "$releaseNotesContent" != "null" ]; then
    releaseNotes='{}'
    releaseNotes=$(echo $releaseNotes | jq --arg content "$releaseNotesContent" '. + {content: $content}')
    releaseNotesSyntax=$(jq -r ".step.configuration.releaseNotes.syntax" $step_json_path)
    if [ ! -z "$releaseNotesSyntax" ] && [ "$releaseNotesSyntax" != "null" ]; then
      releaseNotes=$(echo $releaseNotes | jq --arg syntax "$releaseNotesSyntax" '. + {syntax: $syntax}')
    fi
    payload=$(echo $payload | jq --argjson json "$releaseNotes" '.release_notes = $json')
  fi

  echo $payload
}

postRelease() {
  payloadPath=$1
  resourceName=$2
  local integrationAlias=$(eval echo "$"res_"$resourceName"_integrationAlias)
  local distUrl=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_url)
  local rtUser=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_user)
  local rtApiKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_apikey)

  if [ ! -z "$SIGNING_KEY_PASSPHRASE" ]; then
    STATUS=$(curl -o >(cat > $step_tmp_dir/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      -H "X-GPG-PASSPHRASE: $SIGNING_KEY_PASSPHRASE" \
      "$distUrl/api/v1/release_bundle" -T $payloadPath)
  else
    STATUS=$(curl -o >(cat > $step_tmp_dir/curl_res_body) -w '%{http_code}' -XPOST -u $rtUser:$rtApiKey \
      -H "Content-Type: application/json" \
      "$distUrl/api/v1/release_bundle" -T $payloadPath)
  fi

  jq . $step_tmp_dir/curl_res_body > $step_tmp_dir/"$step_name"_response.json
  add_run_files $step_tmp_dir/"$step_name"_response.json .
  if [ $STATUS -ge 200 ] && [ $STATUS -lt 300 ]; then
    echo -e "\n[CreateReleaseBundle] Successfully created release bundle."
    echo -e "\n[CreateReleaseBundle] Download run state and check "$step_name"_response.json to check the complete response."
  else
    echo -e "\n[CreateReleaseBundle] Failed to create release bundle with error: "
    cat $step_tmp_dir/"$step_name"_response.json
    exit 1
  fi
}

CreateReleaseBundle() {
  local payloadFile="createReleaseBundlePayload.json"

  local integrationAlias=$(eval echo "$"res_"$buildInfo0"_integrationAlias)
  local integrationName=$(eval echo "$"res_"$buildInfo0"_"$integrationAlias"_name)

  echo "[CreateReleaseBundle] Authenticating with integration: $integrationName"
  # Use the first input BuildInfo resource for authenticating
  # since all input BuildInfo resources are supposed to have the same artifactory integration
  authenticate $buildInfo0

  echo -e "\n[CreateReleaseBundle] Getting Artifactory service id"
  local artifactoryServiceId=$(getArtifactoryServiceId)

  # TODO: fix this when setup section gets exported as envs
  releaseBundleNameVar=$(jq -r ".step.configuration.releaseBundleName" $step_json_path)
  releaseBundleVersionVar=$(jq -r ".step.configuration.releaseBundleVersion" $step_json_path)
  releaseBundleName=$(eval echo "$releaseBundleNameVar")
  releaseBundleVersion=$(eval echo "$releaseBundleVersionVar")
  echo -e "\n[CreateReleaseBundle] Creating payload for release bundle"
  payload=$(createPayload "$releaseBundleName" "$releaseBundleVersion" "$artifactoryServiceId")
  echo $payload | jq . > $step_tmp_dir/$payloadFile

  echo -e "\n[CreateReleaseBundle] Creating Release Bundle with name: "$releaseBundleName" and version: "$releaseBundleVersion""
  postRelease $step_tmp_dir/$payloadFile $outputReleaseBundleResourceName

  if [ ! -z "$outputReleaseBundleResourceName" ]; then
    echo -e "\n[CreateReleaseBundle] Updating output resource: $outputReleaseBundleResourceName"
    write_output $outputReleaseBundleResourceName name=$releaseBundleName version=$releaseBundleVersion isSigned=$sign
  fi
}

execute_command CreateReleaseBundle
