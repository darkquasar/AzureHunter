Function Start-AzHunterPlaybook {
    <#
    .SYNOPSIS
        A PowerShell function to run a hunting playbook
 
    .DESCRIPTION
        This playbook will break down the UnifiedAuditLog single file export that the Exporter Plugin produces into individual files based on the Operations attribute. Concomitantly, it will expand the AuditData attribute and modify the CreationTime attribute to match your local timezone in a string format that is easily sortable via spreadsheet software.
 
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

        $PlaybookName = 'AzHunter.Playbook.RecordTypeExporter'

        # Initialize Logger
        if(!$Global:Logger){ $Logger = [Logger]::New() }
        $Logger.LogMessage("[$PlaybookName] Loading Playbook", "INFO", $null, $null)
        # *** END: GENERAL *** #

        # Configure Output Folder
		$CurrentFolder = [System.IO.DirectoryInfo]::new($pwd)
        $strTimeNow = (Get-Date).ToUniversalTime().ToString("yyMMdd-HHmmss")
		$PluginOutputFolder = New-Item -Path $CurrentFolder.FullName -Name $PlaybookName -ItemType Directory
        $Logger.LogMessage("[$PlaybookName] Export Folder Name set to: $($PluginOutputFolder.FullName)", "INFO", $null, $null)
    }

    PROCESS {
        
		$AzureCloudOperations = $Records | Sort-Object -Property Operations -Unique | Select-Object -ExpandProperty Operations
		ForEach($OperationType in $AzureCloudOperations) {
			
			$Logger.LogMessage("[$PlaybookName] Exporting $OperationType Records", "INFO", $null, $null)
			$Records |
				Where-Object -Property Operations -eq $OperationType |
				Select-Object -ExpandProperty AuditData |
				ConvertFrom-Json | 
				ForEach-Object { $_.CreationTime = $_.CreationTime.ToDateTime([cultureinfo]::CurrentCulture).ToLocalTime().ToString('dd-MM-yyy hh:mm:ss tt')
				$_ } |
				Export-Csv -NoClobber -NoTypeInformation "$PluginOutputFolder\azhunter-exporter-$OperationType.csv" -Append
		}

    }

    END {
        $Logger.LogMessage("[$PlaybookName] Finished running playbook", "INFO", $null, $null)
        if($PassThru) {
            return $AzUserLoggedInRecordsFlattened
        }
        
    }

}