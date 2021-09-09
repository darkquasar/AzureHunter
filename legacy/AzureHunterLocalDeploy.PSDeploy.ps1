# Generic module deployment.

$CurrentScriptPath = [System.IO.DirectoryInfo]::new($(Split-Path -Parent $MyInvocation.MyCommand.Definition))
$BuildSource = [System.IO.DirectoryInfo]::new($env:ModuleBuildRoot)
$ReleaseDestination = $BuildSource.Parent

# Set-BuildEnvironment from BuildHelpers module has populated ENV:BHProjectName

# *** Deploying to Local Folder ***
Deploy AzureHunter {                        # Deployment name. This needs to be unique. Call it whatever you want
    By Filesystem {                              # Deployment type. See Get-PSDeploymentType
        FromSource $BuildSource.FullName # One or more sources to deploy. Absolute, or relative to deployment.yml parent
        To $ReleaseDestination.FullName          # One or more destinations to deploy the sources to
        Tagged Prod                              # One or more tags you can use to restrict deployments or queries
    }
}