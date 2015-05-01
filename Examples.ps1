Import-Module $PSScriptRoot\Set-ARMServicePrincipalCredential.psm1 -Force


$subscriptionIdFile = Join-Path $PSScriptRoot "SubscriptionId.txt"
if (-not (Test-Path $subscriptionIdFile)) {
    Write-Host "Enter subscription id to deploy into: "
    Set-Content -Path $subscriptionIdFile Read-Host
}

$SubscriptionId = Get-Content $subscriptionIdFile

$result = Set-ARMServicePrincipalCredential `
    -SubscriptionId $SubscriptionId `
    -AppName "MySecretApp" `
    -AppEnvironment "Production" `
    -Location "Southeast Asia"
    
Write-Host $result

$result = Set-ARMServicePrincipalCredential `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName "MyResourceGroup" `
    -Location "Southeast Asia"
    
Write-Host $result

$result = Set-ARMServicePrincipalCredential `
    -SubscriptionId $SubscriptionId `
    -AzureADAppName "MyAzureADApp" `
    -Verbose

Write-Host $result