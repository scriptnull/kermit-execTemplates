Function post_webhook_url([string]$resourceName) {
  $resourcePath = $(echo "`$res_${resourceName}_resourcePath")
  $intMasterName = $(echo "`$res_${resourceName}_int_masterName")
  $filePath = $resourcePath/$resourceName.env

  if ($intMasterName -eq "externalWebhook") {
    if (Test-Path $filePath) {
      if ((Get-Item $filePath).length -gt 0kb) {
        $webhookURL = $(echo "`$res_${resourceName}_int_webhookURL")
        $authorization = $(echo "`$res_${resourceName}_int_authorization")
        $data = $(cat $filePath)

        $headers = @{
          'Authorization' = $authorization
          'Content-Type' = 'text/plain'
        }
        Invoke-RestMethod -Method 'Post' -Headers $headers -Body $data
      }
    }
  }
}

execute_command "post_webhook_url %%context.resourceName%%"
