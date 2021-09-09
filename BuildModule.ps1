<#
.Description
    This Script is meant to facilitate installing or load all the required modules for the build.
    Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
Param (
        [Parameter( 
            Mandatory=$True,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=0,
            HelpMessage='The Build Task to run as specified in your .build.ps1 file'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$BuildTask = "Default"
)

Write-Output "[AzureHunter][Build][+] Starting build"

# Install Powershell dependencies if not available
$RequiredModules = @('InvokeBuild', 'ModuleBuilder', 'PSScriptAnalyzer', 'Coveralls', 'Pester')
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

# Attempt to import modules first, if already installed this will haste the build process
# Those modules that cannot be imported should be flagged for installation
Write-Output "[AzureHunter][Build][+] Import Dependent Modules"
[System.Collections.ArrayList]$UninstalledModules = @()

ForEach($Module in $RequiredModules){
    $ModuleImported = Get-Module $Module -ErrorAction SilentlyContinue
    if(!$ModuleImported){
        
        try {
            Write-Output "[AzureHunter][Build][+] Attempting to Import Module $Module"
            Import-Module $Module
        }
        catch {
            Write-Output "[AzureHunter][Build][+] Module $Module not installed. Marked for installation"
            $UninstalledModules.add($Module)
        }
    }
}

Write-Output "[AzureHunter][Build][+] Install Dependent Modules if not already deployed in the current environment"
ForEach($Module in $UninstalledModules){
    Write-Output "[AzureHunter][Build][+] Checking availability of $Module"
    $ModulePresent = Get-InstalledModule $Module -ErrorAction SilentlyContinue

    if(!$ModulePresent){
        Write-Output "[AzureHunter][Build][+] Installing Module $Module"
        Install-Module $Module -Force -Scope CurrentUser
        Write-Output "[AzureHunter][Build][+] Importing Module $Module"
        Import-Module $Module
    }
    else {
        Write-Output "[AzureHunter][Build][+] Module $Module already available"
    }
}

Write-Output "[AzureHunter][Build][+] Invoking Build Tasks"
Invoke-Build $BuildTask -Result Result

if ($Result.Error)
{
    exit 1
}
else 
{
    exit 0
}