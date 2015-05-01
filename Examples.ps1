Import-Module $PSScriptRoot\Set-ARMServicePrincipalCredential.psm1 -Force


$subscriptionIdFile = Join-Path $PSScriptRoot "SubscriptionId.txt"
if (-not (Test-Path $subscriptionIdFile)) {
    Write-Host "Enter subscription id to deploy into: "
    Read-Host | Set-Content -Path $subscriptionIdFile
}

$SubscriptionId = Get-Content $subscriptionIdFile

$result = Set-ARMServicePrincipalCredential `
    -SubscriptionId $SubscriptionId `
    -AppName "MySecretApp" `
    -AppEnvironment "Production" `
    -Location "Southeast Asia"
    
$result
Write-Output "----"

$result = Set-ARMServicePrincipalCredential `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName "MyResourceGroup" `
    -Location "Southeast Asia"
    
$result
Write-Output "----"

$result = Set-ARMServicePrincipalCredential `
    -SubscriptionId $SubscriptionId `
    -AzureADAppName "MyAzureADApp"

$result
Write-Output "----"