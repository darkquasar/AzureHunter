<#
    CYBERNETHUNTER SECURITY OPERATIONS :)
    Author: Diego Perez (@darkquassar)
    Version: 1.1.0
    Module: Hunt-AzHunterPlaybook.ps1
    Description: This module contains some utilities to run playbooks through Azure, eDiscovery and O365 logs.
#>

Function Invoke-AzHunterPlaybook {
    <#
    .SYNOPSIS
        A PowerShell function to run playbooks over data obtained via AzureHunter
 
    .DESCRIPTION
        This function will perform....
 
    .PARAMETER PlayBookName
        The name of the playbook that will be executed against the dataset passed to this function

    .EXAMPLE
        XXXX

    .NOTES
        Please use this with care and for legitimate purposes. The author does not take responsibility on any damage performed as a result of employing this script.
    #>

    [CmdletBinding(
        SupportsShouldProcess=$False
    )]
    Param (
        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=0,
            HelpMessage='The records to process from a powershell object'
        )]
        [ValidateNotNullOrEmpty()]
        [Object]$Records,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=1,
            HelpMessage='A CSV or JSON file to process instead of providing records'
        )]
        [ValidateNotNullOrEmpty()]
        [String]$FileName,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=2,
            HelpMessage='The type of Azure Log to process. It helps orient the selection of Playbooks. Not a required parameter.'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('UnifiedAuditLog','eDiscoverySummaryReport','AzureAD')]
        [String]$AzureLogType,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=3,
            HelpMessage='The playbook you would like to run for the current batch of logs'
        )]
        [ValidateNotNullOrEmpty()]
        [String[]]$PlayBooks='AzHunter.Playbook.UAL.Exporter',

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=3,
            HelpMessage='The playbook parameters, if required, that will be passed onto the playbook via Splatting. It needs to be a HashTable like: $Params = @{ "Path" = "TestFile.txt", "ExtractDetails" = $True }'

        )]
        [ValidateNotNullOrEmpty()]
        [hashtable]$PlayBookParameters,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=4,
            HelpMessage='Whether we want records returned back to the console'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$PassThru

    )

    BEGIN {

        # Initialize Logger
        if(!$Global:Logger){ $Logger = [Logger]::New() }
        $Logger.LogMessage("Initializing AzHunterPlaybook Module", "INFO", $null, $null)

        # Determine path to Playbooks folder
        # This is required to pre-load the Base Playbook "AzHunterBase" to do initial sanitization of logs
        if ($PSScriptRoot) {
            $ScriptPath = [System.IO.DirectoryInfo]::new($PSScriptRoot)
            if($ScriptPath.FullName -match "AzureHunter\\source"){
                $ScriptPath = $ScriptPath.Parent
                $Script:PlaybooksPath = Join-Path $ScriptPath.FullName "playbooks"
            }
            else {
                $Script:PlaybooksPath = Join-Path $ScriptPath.FullName "playbooks"
            }
        }
        else {
            $ScriptPath = [System.IO.DirectoryInfo]::new($pwd)
            $PlaybooksFolderPresent = Get-ChildItem -Path $ScriptPath.FullName -Directory -Filter "Playbooks"
            if($PlaybooksFolderPresent){
                $Script:PlaybooksPath = Join-Path $ScriptPath "playbooks"
            }
            else {
                $Logger.LogMessage("Could not find Playbooks folder", "ERROR", $null, $_)
                throw "Could not find Playbooks folder"
            }
        }

        # Load Base Playbook
        try {
            . "$Script:PlaybooksPath\AzHunter.Playbook.Base.ps1"
        }
        catch {
            $Logger.LogMessage("Could not load AzHunter.Playbook.Base", "ERROR", $null, $_)
        }

        # Grab List of All Playbook File Paths
        [System.Collections.ArrayList]$PlaybookFileList = @()
        $PlaybookFiles = Get-ChildItem $Script:PlaybooksPath\* -File -Filter "AzHunter.Playbook*.ps1" -Exclude "AzHunter.Playbook.Base*"
        $PlaybookFiles | ForEach-Object { 
            $PlaybookFileList.Add([System.IO.FileInfo]::new($_)) | Out-Null
        }

        # Determine whether we have an object with records or a pointer to a file for the Records parameter
        if($Records.GetType() -eq [System.String]) {
            $Logger.LogMessage("Records parameter points to a file, creating file object.", "INFO", $null, $null)
            $Records = [System.IO.FileInfo]::new($Records)
        }

    }

    PROCESS {

        if(($AzureLogType -eq "UnifiedAuditLog") -or ($Playbook -contains "UAL")) {
            if($Records.GetType() -ne [System.Object[]]) {
                $Logger.LogMessage("Sorry we have not yet implemented the processing of UAL records from files. You need to load the UAL CSV file into an array first using Import-Csv", "ERROR", $null, $_)
                break
            }
            # Let's cast UAL records to a [AuditLogSchemaGeneric] Type dropping unnecessary properties
            $Logger.LogMessage("Pre-Processing Records", "INFO", $null, $null)
            [System.Collections.ArrayList]$AzHunterRecords = @()
            $Records | ForEach-Object { 
                $SingleRecord = $_ | Select-Object -Property RecordType, CreationDate, UserIds, Operations, AuditData, ResultIndex, ResultCount, Identity
                $AzHunterRecords.Add($SingleRecord -as [AuditLogSchemaGeneric]) | Out-Null }

            $Records = $AzHunterRecords.AzureHuntersRecordsArray
        }

        # (1) Applying Base Playbook
        # Don't apply sorting first since it can be very slow for big datasets
        # $BasePlaybookRecords = [AzHunterBase]::new($AzHunterRecords).DedupRecords("Identity").SortRecords("CreationDate")

        # (2) Applying Remaining Playbooks
        
        ForEach($Playbook in $PlayBooks) {
            $Logger.LogMessage("Checking Playbooks to be applied to the data...", "INFO", $null, $null)

            # Let's run the Playbooks passing in the records
            $PlaybookFileList | ForEach-Object {
                $PlaybookBaseName = $_.BaseName
                
                if($PlaybookBaseName -eq $Playbook) {
                    try {

                        $Logger.LogMessage("Loading Playbook $PlaybookBaseName", "INFO", $null, $null)

                        . $_.FullName # Load Playbook file in the current session

                        if($PassThru) {
                            if($PlayBookParameters) {
                                $ProcessedRecords = Start-AzHunterPlaybook @PlayBookParameters -Records $Records -PassThru
                            }
                            else {
                                $ProcessedRecords = Start-AzHunterPlaybook -Records $Records -PassThru
                            }
                            return $ProcessedRecords
                        }
                        else {
                            if($PlayBookParameters) {
                                Start-AzHunterPlaybook @PlayBookParameters -Records $Records 
                            }
                            else {
                                Start-AzHunterPlaybook -Records $Records
                            }
                        }
                    }
                    catch {
                        $Logger.LogMessage("Could not load Playbook $Playbook", "ERROR", $null, $_)
                    }
                }
            }
        }
    }

    END {
        $Logger.LogMessage("Finished running Playbooks", "SPECIAL", $null, $null)
    }

}

Export-ModuleMember -Function 'Invoke-AzHunterPlaybook'