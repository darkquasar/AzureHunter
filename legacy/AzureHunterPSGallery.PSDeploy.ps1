# Generic module deployment.

# Nuget key in $env:PSGalleryAPIKey
$CurrentScriptPath = [System.IO.DirectoryInfo]::new($(Split-Path -Parent $MyInvocation.MyCommand.Definition))
$BuildSource = [System.IO.DirectoryInfo]::new($env:ModuleBuildRoot)

# Set-BuildEnvironment from BuildHelpers module has populated ENV:BHProjectName

# *** Deploying to PowershellGallery ***
if ($env:DeployToPSGallery -eq $True)
{
    Deploy Module {
        By PSGalleryModule {
            FromSource $BuildSource.FullName
            To PSGallery
            WithOptions @{
                ApiKey = $env:PSGalleryAPIKey
            }
        }
    }
}

