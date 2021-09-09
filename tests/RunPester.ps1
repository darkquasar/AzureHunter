# Need to import all the files first of course.
Set-Location $PSScriptRoot\..
$script:ModuleName = 'AzureHunter'

$foundError = $false

$Directories = ("private", "public")
foreach ($Directory in $Directories)
{
    # Import the functions.
    $files = Get-ChildItem .\$script:ModuleName\$Directory
    foreach ($file in $files)
    {
        # Source the file
        $FileName = $file.Name
        Write-Output "Importing file $FileName"
        . .\$script:ModuleName\$Directory\$FileName
    }
    # Execute Pester for the Directory.
    $results = Invoke-pester .\tests\$Directory\*.ps1 -CodeCoverage .\$script:ModuleName\$Directory\*.ps1 -PassThru -ExcludeTag SkipThis

    $MissedCommands = $results.CodeCoverage.NumberOfCommandsMissed
    $FailedCount = $results.FailedCount
    Write-Output "Missed commands: $MissedCommands - Failed Tests: $Failedcount"
    if (($MissedCommands -ne "0") -or ($FailedCount -ne "0"))
    {
        $foundError = $true
        Write-Error "Not at 100% coverage for $Directory Directory, or a test failed. Review results!"
    }
    else
    {
        # No Missed commands.
        Write-Output "No missed commands for $Directory Directory. 100% coverage!"
    }
}
if ($foundError -eq $true)
{
    # An error was found in the Unit tests.
    Write-Error "An error has been found in the unit Tests. Please review them before commiting the code."
} 
else
{
    Write-Output "Tests cover 100% and all pass! Hooray!"
}
