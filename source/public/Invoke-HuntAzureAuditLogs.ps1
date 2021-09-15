<#
    CYBERNETHUNTER SECURITY OPERATIONS :)
    Author: Diego Perez (@darkquassar)
    Version: 1.1.0
    Module: Hunt-AzureAuditLogs.ps1
    Description: This module contains some utilities to search through Azure and O365 unified audit log.
#>

Function Invoke-HuntAzureAuditLogs {
    <#
    .SYNOPSIS
        A PowerShell function to search the Azure Audit Log
 
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
            Mandatory=$True,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=0,
            HelpMessage='The records to process'
        )]
        [ValidateNotNullOrEmpty()]
        [Object]$Records,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=1,
            HelpMessage='The playbook you would like to run for the current batch of logs'
        )]
        [ValidateNotNullOrEmpty()]
        [String[]]$PlayBooks='AzHunter.Playbook.Exporter',

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=2,
            HelpMessage='Whether we want records returned back to the console'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$PassThru

    )

    BEGIN {

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

        # Initialize Logger
        # $LoggerExists = Get-Variable -Name $Logger -Scope Global -ErrorAction SilentlyContinue
        if(!$Global:Logger){ $Logger = [Logger]::New() }
        $Logger.LogMessage("Initializing HuntAzureAuditLogs", "INFO", $null, $null)
    }

    PROCESS {
        
        # Let's cast records to a [AuditLogSchemaGeneric] Type dropping unnecessary properties
        $Logger.LogMessage("Pre-Processing Records", "INFO", $null, $null)
        [System.Collections.ArrayList]$AzHunterRecords = @()
        $Records | ForEach-Object { 
            $SingleRecord = $_ | Select-Object -Property RecordType, CreationDate, UserIds, Operations, AuditData, ResultIndex, ResultCount, Identity
            $AzHunterRecords.Add($SingleRecord -as [AuditLogSchemaGeneric]) | Out-Null }
        
        # (1) Applying Base Playbook
        $BasePlaybookRecords = [AzHunterBase]::new($AzHunterRecords).DedupRecords("Identity").SortRecords("CreationDate")

        # (2) Applying Remaining Playbooks
        # Let's load playbook files first via dot sourcing scripts
        
        ForEach($Playbook in $PlayBooks) {
            $Logger.LogMessage("Checking Playbooks to be applied to the data...", "INFO", $null, $null)
            # Let's run the Playbooks passing in the records
            $PlaybookFileList | ForEach-Object {
                $PlaybookBaseName = $_.BaseName
                $Logger.LogMessage("Evaluating Playbook $PlaybookBaseName", "INFO", $null, $null)
                if($PlaybookBaseName -eq $Playbook) {
                    try {
                        . $_.FullName
                        if($PassThru) {
                            $ReturnRecords = Start-AzHunterPlaybook -Records $BasePlaybookRecords.AzureHuntersRecordsArray -PassThru
                        }
                        else {
                            Start-AzHunterPlaybook -Records $BasePlaybookRecords.AzureHuntersRecordsArray
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
        if($PassThru){
            return $ReturnRecords
        }
    }

}

Export-ModuleMember -Function 'Invoke-HuntAzureAuditLogs'