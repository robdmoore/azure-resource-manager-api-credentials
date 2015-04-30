#Requires -Version 4.0

function Connect-ToAzureSubscription {
    Param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId
    )

    try {
        Select-AzureSubscription -SubscriptionId $SubscriptionId
    }
    catch {
        Add-AzureAccount
        Select-AzureSubscription -SubscriptionId $SubscriptionId
    }
}

function Get-OrCreateAzureADApp {
    Param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$AppName
    )

    $apps = (Get-AzureADApplication -Name $AppName)
    if(-not $apps) {
        return New-AzureADApplication -DisplayName $AppName
    } else {
        return $apps[0]
    }
}

function Update-OrCreateAzureRoleAssignment{
    Param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServicePrincipalName,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$RoleDefinitionName,
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Scope
    )

    $existingAssignment = Get-AzureRoleAssignment -ServicePrincipalName $ServicePrincipalName | Where-Object { (-not $Scope -or $_.Scope -eq $Scope) } | Select-Object -First 1
    if ($existingAssignment -and $existingAssignment.RoleDefinitionName -ne $RoleDefinitionName) {
        Remove-AzureRoleAssignment -ServicePrincipalName $ServicePrincipalName -RoleDefinitionName $existingAssignment.RoleDefinitionName -Scope $existingAssignment.Scope -Force
        $existingAssignment = $null
    }
    if (-not $existingAssignment) {
        if (-not $Scope) {
            return New-AzureRoleAssignment -ServicePrincipalName $ServicePrincipalName -RoleDefinitionName $RoleDefinitionName
        } else {
            return New-AzureRoleAssignment -ServicePrincipalName $ServicePrincipalName -RoleDefinitionName $RoleDefinitionName -Scope $Scope
        }
    } else {
        return $existingAssignment
    }
}


Add-Type -Assembly System.Web 
function Get-GeneratedPassword() {
    return [Web.Security.Membership]::GeneratePassword(26, 10)
}

function Set-ARMServicePrincipalCredential {
    Param(
        [string]
        [Parameter(Mandatory=$true, ParameterSetName = "RestrictedToAppResourceGroup")]
        [Parameter(Mandatory=$true, ParameterSetName = "RestrictedToResourceGroup")]
        [Parameter(Mandatory=$true, ParameterSetName = "EntireSubscription")]
        $SubscriptionId,
        [string]
        [Parameter(Mandatory=$true, ParameterSetName = "RestrictedToResourceGroup")]
        $ResourceGroupName,
        [string]
        [Parameter(Mandatory=$true, ParameterSetName = "EntireSubscription")]
        $AzureADAppName,
        [string]
        [Parameter(Mandatory=$true, ParameterSetName = "RestrictedToAppResourceGroup")]
        $AppName,
        [string]
        [Parameter(Mandatory=$true, ParameterSetName = "RestrictedToAppResourceGroup")]
        $AppEnvironment,
        [string]
        [Parameter(Mandatory=$true, ParameterSetName = "RestrictedToAppResourceGroup")]
        [Parameter(Mandatory=$true, ParameterSetName = "RestrictedToResourceGroup")]
        $Location
    )

    $result = @{
        ClientId = "";
        TenantId = "";
        Password = "";
    };

    if ($AppName) {
        $ResourceGroupName = "$AppName-$AppEnvironment-Resources"
    }

    if ($ResourceGroupName) {
        $AzureADAppName = "$ResourceGroupName-ApiManagement";
    }

    $ErrorActionPreference = "Stop"

    Import-Module (Join-Path $PSScriptRoot "AADGraph.ps1") -Force
    Import-Module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1" -Force
    Switch-AzureMode AzureResourceManager

    Write-Verbose "Connect to Azure subscription"
    Connect-ToAzureSubscription $SubscriptionId

    Write-Verbose "Getting tenant id for subscription"
    $AzureTenantId = (Get-AzureSubscription -Current).TenantId
    Write-Verbose "Tenant Id: $AzureTenantId"
    $result.TenantId = $AzureTenantId

    Write-Verbose "Creating Azure AD app to act as service principal for management API"
    try {
        if (-not $global:authenticationResult) {
         throw "Not authenticated"
        }
        $ADApp = Get-OrCreateAzureADApp -AppName $AzureADAppName
    } catch {
        # If there was an error we probably need to connect to Azure AD
        Connect-AzureAD -DomainName $AzureTenantId
        $ADApp = Get-OrCreateAzureADApp -AppName $AzureADAppName
    }
    Write-Verbose "Client Id:" $ADApp.appId
    $result.ClientId = $ADApp.appId

    Write-Verbose "Creating a password to authenticate as the Azure AD app"
    $ServicePrincipalPassword = Get-GeneratedPassword
    Add-AzureADApplicationCredential -ObjectId $ADApp.objectId -Password $ServicePrincipalPassword | Out-Null
    Write-Verbose "Password:" $ServicePrincipalPassword
    $result.Password = $ServicePrincipalPassword

    Write-Verbose "Idempotently creating the resource group"
    if ($ResourceGroupName) {
        New-AzureResourceGroup -Location $Location -Name $ResourceGroupName -Force | Out-Null
    }

    Write-Verbose "Giving API access for the Azure AD app"
    if ($ResourceGroupName) {
        Update-OrCreateAzureRoleAssignment -ServicePrincipalName $ADApp.appId -RoleDefinitionName "Contributor" -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" | Out-Null
    } else {
        Update-OrCreateAzureRoleAssignment -ServicePrincipalName $ADApp.appId -RoleDefinitionName "Contributor" | Out-Null
    }

    return $result;
}

Export-ModuleMember -Function Set-ARMServicePrincipalCredential
