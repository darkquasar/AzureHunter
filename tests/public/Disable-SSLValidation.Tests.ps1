$script:ModuleName = 'AzureHunter'

$here = (Split-Path -Parent $MyInvocation.MyCommand.Path) -replace 'tests', "$script:ModuleName"
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Disable-SSLValidation function for $moduleName" -Tags Build {
    It "Should Return null." {
        Disable-SSLValidation | Should be $true
    }
}

