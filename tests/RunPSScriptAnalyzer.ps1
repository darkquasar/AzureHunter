# Need to import all the files first of course.

Set-Location $PSScriptRoot\..
$script:ModuleName = 'AzureHunter'

$FoundError = $false

$Directories = ("private", "public")
foreach ($Directory in $Directories)
{
    $AnalyzerResults = Invoke-ScriptAnalyzer -Path .\$script:ModuleName\$Directory -IncludeDefaultRules
    if ($null -eq $AnalyzerResults)
    {
        Write-Output "No Code issues found in directory: $Directory"
    }
    else
    {
        $FoundError = $true
        Write-Output "Error found in Directory: $Directory"
        Write-Output $AnalyzerResults
    }
}
if ($FoundError -eq $true)
{
    # Script Analyzer found something. Oh No!
    Write-Error "An error has been found with PSScriptAnalyzer. Please review them before commiting the code."
} 
else
{
    # No Script Analyzer findings, Hooray!
    Write-Output "Nothing found with PSScriptAnalyzer! Hooray!"
}
