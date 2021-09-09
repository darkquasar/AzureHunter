Function Start-AzHunterPlaybook {
    <#
    .SYNOPSIS
        A PowerShell function to run a hunting playbook
 
    .DESCRIPTION
        This playbook will export UnifiedAuditLog records to CSV files on disk.
 
    .PARAMETER Records
        An array of records to apply different data transformations to. Each individual record needs to be of type [AzHunterBase]

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
            HelpMessage='AzureHunter Records'
        )]
        [ValidateNotNullOrEmpty()]
        $Records,

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
        # *** BEGIN: GENERAL *** #
        # *** Getting a handle to the running script path so that we can refer to it *** #
        if ($PSScriptRoot) { 
            $ScriptPath = [System.IO.DirectoryInfo]::new($PSScriptRoot)
            if($ScriptPath.FullName -match "source"){
                $ScriptPath = $ScriptPath.Parent.Parent
            }
        } 
        else {
            $ScriptPath = [System.IO.DirectoryInfo]::new($pwd)
        }

        $PlaybookName = 'AzHunter.Playbook.Exporter'

        # Initialize Logger
        if(!$Global:Logger){ $Logger = [Logger]::New() }
        $Logger.LogMessage("[$PlaybookName] Loading Playbook", "INFO", $null, $null)
        # *** END: GENERAL *** #

        # Configure Output File
        $strTimeNow = (Get-Date).ToUniversalTime().ToString("yyMMdd-HHmmss")
        if(!$Global:AzExporterExportFileName) {
            if($Global:Logger) {
                $ExportFileNameBaseDir = ([System.IO.FileInfo]::new($Global:Logger.LogFileJSON)).Directory.FullName
                $Global:AzExporterExportFileName = "$ExportFileNameBaseDir\$($env:COMPUTERNAME)-azhunter-exporter-$strTimeNow.csv"
            }
            else {
                $Global:AzExporterExportFileName = "$($ScriptPath.Parent.FullName)\$($env:COMPUTERNAME)-azhunter-exporter-$strTimeNow.csv"
            }
            $Logger.LogMessage("[$PlaybookName] Export File Name set to: $Global:AzExporterExportFileName", "INFO", $null, $null)
        }
        else {
            $Logger.LogMessage("[$PlaybookName] Found Handle to open Export File: $Global:AzExporterExportFileName", "INFO", $null, $null)
        }
        
        
    }

    PROCESS {
        $Logger.LogMessage("[$PlaybookName] Exporting records to file $Global:AzExporterExportFileName", "INFO", $null, $null)
        $Records | Export-Csv $Global:AzExporterExportFileName -NoTypeInformation -NoClobber -Append
    }

    END {
        $Logger.LogMessage("[$PlaybookName] Finished running playbook", "INFO", $null, $null)
        if($PassThru){
            return $Records
        }
        
    }

}