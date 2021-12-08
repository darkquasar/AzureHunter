#Requires -Modules @{ModuleName='InvokeBuild';ModuleVersion='3.2.1'}
#Requires -Modules @{ModuleName='PowerShellGet';ModuleVersion='1.6.0'}
#Requires -Modules @{ModuleName='Pester';ModuleVersion='4.1.1'}
#Requires -Modules @{ModuleName='ModuleBuilder';ModuleVersion='1.0.0'}

$script:ModuleName = 'AzureHunter' # Name of the module, it will be used to place our build module inside a SemVer directory
$script:RelativeSourcePathName = 'Source' # Relative name of the directory where our module manifest and files are sourced from
$script:SourcePath = Join-Path $BuildRoot $RelativeSourcePathName # Where to source our module manifest and files from
$script:BuildOutputFolder = Join-Path $BuildRoot Output # Folder where the output of all build & release tasks will be placed
$script:ReleaseDir = Join-Path $script:BuildOutputFolder Release # Folder where the release package or zip will be placed
$script:BuildDestinationFolder = Join-Path $BuildOutputFolder $ModuleName # Folder inside $BuildOutputFolder where we will place our built artefacts or final Module
$script:ExcludedDirs = ( 'private', 'public', 'classes', 'enums' )

# Let's provide stdout output with information on relevant environment context
Task ContextAwareness {
    Write-Build Yellow ":robot: `e[7;32m[AzureHunter][Build]`e[0m ModuleName is $ModuleName"
    Write-Build Yellow ":robot: `e[7;32m[AzureHunter][Build]`e[0m Relative name of Source files: .\$RelativeSourcePathName"
    Write-Build Yellow ":robot: `e[7;32m[AzureHunter][Build]`e[0m Full Source Path: $SourcePath"
    Write-Build Yellow ":robot: `e[7;32m[AzureHunter][Build]`e[0m CI/CD Output Folder: $BuildOutputFolder"
    Write-Build Yellow ":robot: `e[7;32m[AzureHunter][Build]`e[0m BuildRoot Directory is $BuildRoot"
    Write-Build Yellow ":robot: `e[7;32m[AzureHunter][Build]`e[0m Module Build Directory inside BuildRoot is $BuildDestinationFolder"
    Write-Build Yellow ":robot: `e[7;32m[AzureHunter][Build]`e[0m Release Directory is $ReleaseDir"
}

# Let's clean the Output Directory so that it can host a new Build
Task PreCleanBuildFolder {
    Write-Build Yellow "`e[6;36m`n[AzureHunter][Build] Deleting Folder $BuildOutputFolder`e[0m"
    $null = Remove-Item $BuildOutputFolder -Recurse -ErrorAction Ignore
    $null = New-Item -Type Directory -Path $BuildDestinationFolder
    # Unregister repository
    Unregister-PSRepository AzureHunterDemoRepo -Verbose -ErrorAction SilentlyContinue
}

# This task will compile all of the PS1 files into a cohesive PSM1 module file
# that is referenced by the module manifest (your main .psd1 file)
Task CompilePSM {

    Write-Build Yellow "`e[6;36m`n[AzureHunter][Build] Compiling all code into a single PSM1`e[0m"

    # Configure Build Params for Build-Module
    $BuildParams = @{}
    try {
        if($env:GitVersionTag) {
            $BuildParams['SemVer'] = $GitVersion
            Write-Build Yellow "`n[AzureHunter][Build] Found GITVERSION Environment Variable"
            Write-Build Yellow "`e[0;35m`n[AzureHunter][Build] Build Version according to GitVersion Environment Variable: $($BuildParams["SemVer"]). THIS IS THE VERSION THAT WILL BE PUBLISHED TO POWERSHELLGALLERY`e[0m"
        }
        else {
            $GitVersion = gitversion | ConvertFrom-Json | Select-Object -Expand SemVer
            $BuildParams['SemVer'] = $GitVersion
            Write-Build Yellow "`e[0;35m`n[AzureHunter][Build] Build Version according to GitVersion: $($BuildParams["SemVer"]). THIS IS THE VERSION THAT WILL BE PUBLISHED TO POWERSHELLGALLERY`e[0m"
        }
    }
    catch {
        Write-Build Yellow "`e[6;36m`n[AzureHunter][Build] Gitversion Raw Output: `e[0m"
        gitversion
        Write-Host $Error[0]
        Write-Warning -Message '`e[0;35mGitVersion not found, keeping the current version`e[0m'
    }

    

    Push-Location -Path "$BuildRoot\Source" -StackName 'InvokeBuildTask'
    $Global:CompileResult = Build-Module @BuildParams -Passthru

    Get-ChildItem -Path "$BuildRoot\license*" | Copy-Item -Destination $Global:CompileResult.ModuleBase
    Pop-Location -StackName 'InvokeBuildTask'

    # Set Output for Github Action
    Write-Output "::set-output name=BuildModuleRoot::$($Global:CompileResult.ModuleBase)"

    Write-Build Yellow "`n[AzureHunter][Build] Build Module Metadata to StdOut"
    $CompileMetadata = $Global:CompileResult | Format-List -Property * | Out-String
    Write-Build Green "`n$CompileMetadata`n"
}

Task ZipOutput {

    $BuildDir = $Global:CompileResult.ModuleBase
    $ZipDestinationPath = Join-Path $script:ReleaseDir "$($Global:CompileResult.Name)-v$($Global:CompileResult.Version).zip" 
    Write-Build Green "`e[6;36m`n[AzureHunter][Release] Release Zip Destination Path $ZipDestinationPath`e[0m"
    

    if(!(Test-Path $script:ReleaseDir)) {
        New-Item -Type Directory -Path $script:ReleaseDir
    }

    Write-Build Green "`n[AzureHunter][Release] Zipping $BuildDir for release"
    $ZipParams = @{
        Path = Join-Path $BuildDir "\*"
        CompressionLevel = "Fastest"
        DestinationPath = $ZipDestinationPath
    }

    Compress-Archive @ZipParams
    
}

# This task will Tag the current commit according to GitVersion and
# the latest commit locally made
# RUN: locally after commiting and before pushing if you want to tag your commits before pushing
Task GitTag {

    Write-Build Yellow "`e[6;36m`n[AzureHunter][Build] Tagging latest commit`e[0m"
    try {
        $BuildParams = @{}
        if((Get-Command -ErrorAction Stop -Name gitversion)) {
            $GitVersion = gitversion | ConvertFrom-Json | Select-Object -Expand SemVer
            $BuildParams['SemVer'] = $GitVersion
        }
    }
    catch{
        Write-Warning -Message 'GitVersion not found, keeping the current version'
    }

    git tag $BuildParams['SemVer']
}

# After building our PSM1, if our Module has any dependencies on libraries or binaries
# this task will take care of placing them in the output directory
Task CopyDependenciesToOutput {

    Write-Build Yellow "`e[6;36m`n[AzureHunter][Build] Copying any package dependencies to build directory $($Global:CompileResult.ModuleBase)`e[0m"

    Get-ChildItem -Path $SourcePath -File |
        Where-Object Name -NotMatch "$ModuleName\.ps[dm]1" |
        Copy-Item -Destination $Global:CompileResult.ModuleBase -Force -PassThru |
        ForEach-Object { 
            $FullTargetPath = $_.Fullname.Replace($PSScriptRoot, '')
            Write-Build Yellow "[AzureHunter][Build] Creating $FullTargetPath"
        }

    Get-ChildItem -Path $SourcePath -Directory | 
        Where-Object name -NotIn $ExcludedDirs | 
        Copy-Item -Destination $Global:CompileResult.ModuleBase -Recurse -Force -PassThru | 
        ForEach-Object { 
            $FullTargetPath = $_.Fullname.Replace($PSScriptRoot, '')
            Write-Build Yellow "[AzureHunter][Build] Creating $FullTargetPath"
        }
}

Task TestBuild {
    Write-Build Magenta "`n[AzureHunter][Test] Testing compiled module"

    $Script =  @{Path="$PSScriptRoot\test\Unit"; Parameters=@{ModulePath=$Global:CompileResult.ModuleBase}}
    $CodeCoverage = (Get-ChildItem -Path $Global:CompileResult.ModuleBase -Filter *.psm1).FullName
    $TestResult = Invoke-Pester -Script $Script -CodeCoverage $CodeCoverage -Show None -PassThru

    if($TestResult.FailedCount -gt 0) {
        Write-Warning -Message "Failing Tests:"
        $TestResult.TestResult.Where{$_.Result -eq 'Failed'} | ForEach-Object -Process {
            Write-Warning -Message $_.Name
            Write-Verbose -Message $_.FailureMessage -Verbose
        }
        throw '[AzureHunter][Test] Tests Failed'
    }

    $CodeCoverageResult = $TestResult | Convert-CodeCoverage -SourceRoot "$PSScriptRoot\Source" -Relative
    $CodeCoveragePercent = $TestResult.CodeCoverage.NumberOfCommandsExecuted/$TestResult.CodeCoverage.NumberOfCommandsAnalyzed*100 -as [int]
    Write-Verbose -Message "CodeCoverage is $CodeCoveragePercent%" -Verbose
    $CodeCoverageResult | Group-Object -Property SourceFile | Sort-Object -Property Count | Select-Object -Property Count, Name -Last 10
}

Task PublishUnitTestsCoverage {
    $TestResults = Invoke-Pester -Path Tests\*\* -CodeCoverage $ModuleName\*\* -PassThru -Tag Build -ExcludeTag Slow
    $Coverage = Format-Coverage -PesterResults $TestResults -CoverallsApiToken $ENV:Coveralls_Key -BranchName $ENV:APPVEYOR_REPO_BRANCH
    Publish-Coverage -Coverage $Coverage
}

Task PublishLocalTestPackage {
    # This task will register a local folder as a destination for a NuGet package and publish
    # The current build to it so that it can be tested locally

    $RepositoryName = "AzureHunterDemoRepo"
    $RepositoryPath = Join-Path $script:BuildOutputFolder $RepositoryName
    Write-Build Green "`e[6;36m`n[AzureHunter][Test] Nugget Test Repo Destination Path $RepositoryPath`e[0m"

    if(!(Test-Path $RepositoryPath)) {
        New-Item -Type Directory -Path $RepositoryPath
    }
    Register-PSRepository -Name $RepositoryName -SourceLocation $RepositoryPath -PublishLocation $RepositoryPath -InstallationPolicy Trusted
    Publish-Module -Path $script:BuildDestinationFolder -Repository $RepositoryName -NuGetApiKey "TEST"

    # To Test the package simply uninstall from previous locations and re-install from the local repository
    # Install-Module AzureHunter -Repository AzureHunterDemoRepo -Scope CurrentUser
    # Get-Module AzureHunter | fl
}

# This task will update the source Manifest File with the newly built one
Task UpdateSource {
    Copy-Item $Global:CompileResult.Path -Destination "$SourcePath\$ModuleName.psd1"
}

# Task to publish this module to the right gallery
Task PublishPackage {
    # Gate deployment

    # Set Environment Variables that are required by PSDeploy
    $env:ModuleBuildRoot = $Global:CompileResult.ModuleBase

    Write-Verbose -Message "CodeCoverage is $CodeCoveragePercent%"
    
    if (
        $env:PSGalleryNugetAPIKey
    )
    {
        Publish-Module -Path "./Output/AzureHunter" -NuGetApiKey $env:PSGalleryNugetAPIKey
    }
    else
    {
        Write-Output "Could Not Deploy Powershell Package. No API Key available."
    }
}

Task Default ContextAwareness, PreCleanBuildFolder, CompilePSM, CopyDependenciesToOutput, ZipOutput
Task UpdateSourceManifest ContextAwareness, UpdateSource
Task PublishModule ContextAwareness, PublishPackage
Task TestBuildAndPublishModule Default, PublishLocalTestPackage
Task TagLatestGitCommit GitTag
