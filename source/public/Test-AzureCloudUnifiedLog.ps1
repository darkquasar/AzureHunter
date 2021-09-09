using namespace AzureHunter.CloudInit

Function Test-AzureCloudUnifiedLog {
    
    Invoke-HuntAzureAuditLogs -Records @(1,2,3,4,5,6,7,8,9,10)
    $TestArray = @(1,2,3,4,5)
    $Exporter = [Exporter]::new($TestArray)
    Write-Host $Exporter.RecordArray
}

Function Test-CloudInitClass {
    
    # This should print the initialization output message
    # Then check module availability
    # Then finally connect to exchange online
    $CloudInit = [AzCloudInit]::new()
    $CloudInit.InitializePreChecks($null)
    # Authenticate to ExchangeOnline
    $GetPSSessions = Get-PSSession | Select-Object -Property State, Name
    $ExOConnected = (@($GetPSSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0
    if($ExOConnected -ne "True") {
        Connect-ExchangeOnline -UseMultithreading $True -ShowProgress $True
    }
}

Function Test-SearchUnifiedAuditLog {

    $StartDate = [DateTime]::UtcNow.AddDays(-0.045)
    $EndDate = [DateTime]::UtcNow
    $Results = Search-UnifiedAuditLog -StartDate $StartDate -EndDate $EndDate -ResultSize 100
    return $Results
}

Function Test-AzHunterSearchLogWithTestData {

    Search-AzureCloudUnifiedLog -StartDate "2020-03-06T10:00:00" -EndDate "2020-03-09T12:40:00" -TimeInterval 12 -UserIDs "test.user@contoso.com" -AggregatedResultsFlushSize 100 -RunTestOnly -Verbose
}