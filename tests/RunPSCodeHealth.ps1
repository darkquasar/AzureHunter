# Need to import all the files first of course.

Set-Location $PSScriptRoot\..
$script:ModuleName = 'AzureHunter'

$FoundError = $false

$Directories = ("private", "public")
foreach ($Directory in $Directories)
{
    # Import the functions.
    $HtmlReportPathString = ".\Test_Results\" + "$script:ModuleName" + "_" + "$Directory" + ".html"
    $PSCodeHealthParameters = @{
        Path           = ".\$script:ModuleName\$Directory\"
        TestsPath      = ".\tests\$Directory\"
        HtmlReportPath = "$HtmlReportPathString"
        PassThru       = $true
    }
    $DirectoryResults = Invoke-PSCodeHealth @PSCodeHealthParameters

    if ($DirectoryResults.CommandsMissedTotal -ne 0)
    {
        $MissedCommands = $DirectoryResults.CommandsMissedTotal
        $FoundError = $true
        Write-Output "Missed Commands for Directory: $Directory - ($MissedCommands)"
    }
    if ($DirectoryResults.NumberOfFailedTests -ne 0)
    {
        $FailedTests
        $FoundError = $true
        Write-Output "Failed Tests for Directory: $Directory - ($FailedTests)"
    }
}

if ($FoundError -eq $true)
{
    # An error was found in the Unit tests.
    Write-Error "An error has been found in the unit Tests. Please review them before commiting the code."
} 
else
{
    # No Errors found. Hooray!
    Write-Output "Tests cover 100% and all pass! Hooray!"
}
