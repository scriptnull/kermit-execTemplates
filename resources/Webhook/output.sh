post_webhook_url() {
  local resourceName="$1"
  local integrationAlias=$(eval echo "$"res_"$resourceName"_integrationAlias)
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)
  local intMasterName=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_masterName)
  local filePath=$resourcePath/$resourceName.env

  if [ "$intMasterName" == "externalWebhook" ]; then
    if [ -s $filePath ]; then
      local webhookURL=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_webhookURL)
      local authorization=$(eval echo "$"res_"$resourceName"_"$integrationAlias"_authorization)
      local data=$(cat $filePath)

      curl -X POST \
        -H  "Authorization: $authorization" \
        -H "Content-Type: text/plain" --data "$data" \
        $webhookURL
    fi
  fi
}

execute_command "post_webhook_url %%context.resourceName%%"
