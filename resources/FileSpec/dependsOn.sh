#!/bin/bash -e

get_file() {
  local resourceName="$1"
  local integrationAlias=$(eval echo "$"res_"$resourceName"_integrationAlias)
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)
  local intMasterName=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_masterName)
  local autoPull=$(eval echo "$"res_"$resourceName"_autoPull)

  if [ -z "$autoPull" ] || "$autoPull" == "true" ; then

    if [ "$intMasterName" == "artifactory" ]; then
      local rtUrl=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_url)
      local rtUser=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_user)
      local rtApiKey=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_apikey)

      jfrog rt config --url $rtUrl --user $rtUser --apikey $rtApiKey --interactive=false

      local pattern=$(eval echo "$"res_"$resourceName"_pattern)
      local aql=$(eval echo "$"res_"$resourceName"_aql)
      local target=$(eval echo "$"res_"$resourceName"_target)
      local props=$(eval echo "$"res_"$resourceName"_props)
      local recursive=$(eval echo "$"res_"$resourceName"_recursive)
      local flat=$(eval echo "$"res_"$resourceName"_flat)
      local excludePatterns=$(eval echo "$"res_"$resourceName"_excludePatterns)
      local archiveEntries=$(eval echo "$"res_"$resourceName"_archiveEntries)
      local build=$(eval echo "$"res_"$resourceName"_build)
      local sortBy=$(eval echo "$"res_"$resourceName"_sortBy)
      local sortOrder=$(eval echo "$"res_"$resourceName"_sortOrder)
      local limit=$(eval echo "$"res_"$resourceName"_limit)
      local offset=$(eval echo "$"res_"$resourceName"_offset)

      specs='{}'
      if [ ! -z "$pattern" ]; then
        specs=$(echo $specs | jq --arg pattern $pattern '. + {pattern: $pattern}')
      fi

      if [ ! -z "$aql" ]; then
        specs=$(echo $specs | jq --arg aql $aql '. + {aql: $aql}')
      fi

      if [ ! -z "$target" ]; then
        specs=$(echo $specs | jq --arg target $target '. + {target: $target}')
      fi

      if [ ! -z "$props" ]; then
        specs=$(echo $specs | jq --arg props $props '. + {props: $props}')
      fi

      if [ ! -z "$recursive" ]; then
        specs=$(echo $specs | jq --arg recursive $recursive '. + {recursive: $recursive}')
      fi

      if [ ! -z "$flat" ]; then
        specs=$(echo $specs | jq --arg flat $flat '. + {flat: $flat}')
      fi

      if [ ! -z "$excludePatterns" ]; then
        specs=$(echo $specs | jq --arg excludePatterns $excludePatterns '. + {excludePatterns: $excludePatterns}')
      fi

      if [ ! -z "$archiveEntries" ]; then
        specs=$(echo $specs | jq --arg archiveEntries $archiveEntries '. + {archiveEntries: $archiveEntries}')
      fi

      if [ ! -z "$build" ]; then
        specs=$(echo $specs | jq --arg build $build '. + {build: $build}')
      fi

      if [ ! -z "$sortBy" ]; then
        specs=$(echo $specs | jq --arg sortBy $sortBy '. + {sortBy: $sortBy}')
      fi

      if [ ! -z "$sortOrder" ]; then
        specs=$(echo $specs | jq --arg sortOrder $sortOrder '. + {sortOrder: $sortOrder}')
      fi
      if [ ! -z "$limit" ]; then
        specs=$(echo $specs | jq --arg limit $limit '. + {limit: $limit|tonumber}')
      fi

      if [ ! -z "$offset" ]; then
        specs=$(echo $specs | jq --arg offset $offset '. + {offset: $offset|tonumber}')
      fi

      fileSpecs='{"files": []}'
      fileSpecs=$(echo $fileSpecs | jq --argjson json "$specs" '.files += [ $json ]')
      echo $fileSpecs | jq . > $step_tmp_dir/fileSpecs.json
      pushd $resourcePath
      jfrog rt dl --build-name=$pipeline_name --build-number=$run_number --spec $step_tmp_dir/fileSpecs.json
      popd
    fi
    echo "Successfully fetched file"
  fi
}

execute_command "get_file %%context.resourceName%%"
