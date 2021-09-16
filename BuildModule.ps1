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

Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Starting build"

# Install Powershell dependencies if not available
$RequiredModules = @('InvokeBuild', 'ModuleBuilder', 'PSScriptAnalyzer', 'Coveralls', 'Pester')
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

# Attempt to import modules first, if already installed this will haste the build process
# Those modules that cannot be imported should be flagged for installation
Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Import Dependent Modules"
[System.Collections.ArrayList]$UninstalledModules = @()

ForEach($Module in $RequiredModules){
    $ModuleImported = Get-Module $Module -ErrorAction SilentlyContinue
    if(!$ModuleImported){
        
        try {
            Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Attempting to Import Module $Module"
            Import-Module $Module
        }
        catch {
            Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Module $Module not installed. Marked for installation"
            $UninstalledModules.add($Module)
        }
    }
}

Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Install Dependent Modules if not already deployed in the current environment"
ForEach($Module in $UninstalledModules){
    Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Checking availability of $Module"
    $ModulePresent = Get-InstalledModule $Module -ErrorAction SilentlyContinue

    if(!$ModulePresent){
        Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Installing Module $Module"
        Install-Module $Module -Force -Scope CurrentUser
        Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Importing Module $Module"
        Import-Module $Module
    }
    else {
        Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Module $Module already available"
    }
}

Write-Output "`e[7;32m[AzureHunter][Build][+]`e[0m Invoking Build Tasks"
Invoke-Build $BuildTask -Result Result

if ($Result.Error)
{
    exit 1
}
else 
{
    exit 0
}