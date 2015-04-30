Import-Module $PSScriptRoot\Set-ARMServicePrincipalCredential.psm1 -Force

$SubscriptionId = Get-Content (Join-Path $PSScriptRoot "SubscriptionId.txt")

$result = Set-ARMServicePrincipalCredential `
    -SubscriptionId $SubscriptionId `
    -AppName "MySecretApp" `
    -AppEnvironment "Production" `
    -Location "Southeast Asia" `
    -Verbose

Write-Host $result