Function Start-AzHunterPlaybook {
    <#
    .SYNOPSIS
        A PowerShell function to run a hunting playbook
 
    .DESCRIPTION
        This playbook will analyze UserLoggedIn Operations.
 
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

        $PlaybookName = 'AzHunter.Playbook.UAL.LogonAnalyser'

        # Initialize Logger
        if(!$Global:Logger){ $Logger = [Logger]::New() }
        $Logger.LogMessage("[$PlaybookName] Loading Playbook", "INFO", $null, $null)
        # *** END: GENERAL *** #

        # Configure Output File
        # Create output folder for Playbook inside default parent output folder for this session
        $PlaybookOutputFolder = New-OutputFolder -FolderName $PlaybookName
        $AzPlaybookFileName = "$PlaybookOutputFolder\AzHunter.UAL.LogonAnalyser.csv"
        $Logger.LogMessage("[$PlaybookName] Export File Name set to: $AzPlaybookFileName", "INFO", $null, $null)
    }

    PROCESS {
        $AzUserLoggedInRecords = $Records | Where-Object -Property Operations -eq "UserLoggedIn" | Select-Object -ExpandProperty AuditData | ConvertFrom-Json
        # Define Log Record Schema
        $UserLoggedInLogRecord = [Ordered]@{
            "ResultStatus"                  = ""
            "UserKey"                       = ""
            "UserType"                      = ""
            "Version"                       = ""
            "Workload"                      = ""
            "ClientIP"                      = ""
            "ObjectId"                      = ""
            "UserId"                        = ""
            "UserAgent"                     = ""
            "UserAuthenticationMethod"      = ""
            "AzureActiveDirectoryEventType" = ""
            "Target"                        = ""
            "TargetContextId"               = ""
            "ApplicationId"                 = ""
            "DevicePropertiesId"            = ""
            "DevicePropertiesDisplayName"   = ""
            "DevicePropertiesOS"            = ""
            "DevicePropertiesBrowserType"   = ""
            "ErrorNumber"                   = ""
        }

        [System.Collections.ArrayList]$AzUserLoggedInRecordsFlattened = @()
        ForEach($Entry in $AzUserLoggedInRecords) {

            $UserLoggedInLogRecord.ResultStatus = $Entry.ResultStatus
            $UserLoggedInLogRecord.UserKey = $Entry.UserKey
            $UserLoggedInLogRecord.UserType = $Entry.UserType
            $UserLoggedInLogRecord.Version = $Entry.Version
            $UserLoggedInLogRecord.Workload = $Entry.Workload
            $UserLoggedInLogRecord.ClientIP = $Entry.ClientIP
            $UserLoggedInLogRecord.ObjectId = $Entry.ObjectId
            $UserLoggedInLogRecord.UserId = $Entry.UserId
            $UserLoggedInLogRecord.UserAgent = $Entry.ExtendedProperties | Where-Object Name -eq UserAgent | Select-Object -ExpandProperty Value
            $UserLoggedInLogRecord.UserAuthenticationMethod = $Entry.ExtendedProperties | Where-Object Name -eq UserAuthenticationMethod | Select-Object -ExpandProperty Value
            $UserLoggedInLogRecord.AzureActiveDirectoryEventType = $Entry.AzureActiveDirectoryEventType
            $UserLoggedInLogRecord.Target = $Entry.Target.ID
            $UserLoggedInLogRecord.TargetContextId = $Entry.TargetContextId
            $UserLoggedInLogRecord.ApplicationId = $Entry.ApplicationId
            $UserLoggedInLogRecord.DevicePropertiesId = $Entry.DeviceProperties | Where-Object Name -eq Id | Select-Object -ExpandProperty Value
            $UserLoggedInLogRecord.DevicePropertiesDisplayName = $Entry.DeviceProperties | Where-Object Name -eq DisplayName | Select-Object -ExpandProperty Value
            $UserLoggedInLogRecord.DevicePropertiesOS = $Entry.DeviceProperties | Where-Object Name -eq OS | Select-Object -ExpandProperty Value
            $UserLoggedInLogRecord.DevicePropertiesBrowserType = $Entry.DeviceProperties | Where-Object Name -eq BrowserType | Select-Object -ExpandProperty Value
            $UserLoggedInLogRecord.ErrorNumber = $Entry.ErrorNumber

            $TempObj = New-Object -TypeName PSObject -Property $UserLoggedInLogRecord
            $AzUserLoggedInRecordsFlattened.Add($TempObj) | Out-Null

        }

        $Logger.LogMessage("[$PlaybookName] Exporting records to file $AzPlaybookFileName", "INFO", $null, $null)
        $AzUserLoggedInRecordsFlattened | Export-Csv $AzPlaybookFileName -NoTypeInformation -NoClobber -Append
    }

    END {
        $Logger.LogMessage("[$PlaybookName] Finished running playbook", "INFO", $null, $null)
        if($PassThru) {
            return $AzUserLoggedInRecordsFlattened
        }
        
    }

}