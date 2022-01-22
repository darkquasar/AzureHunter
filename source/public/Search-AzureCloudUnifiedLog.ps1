<#
    CYBERNETHUNTER SECURITY OPERATIONS :)
    Author: Diego Perez (@darkquassar)
    Version: 1.1.0
    Module: Search-AzureCloudUnifiedLog.ps1
    Description: This module contains some utilities to search through Azure and O365 unified audit log.
#>

using namespace AzureHunter.AzureSearcher
using namespace AzureHunter.Logger
using namespace AzureHunter.TimeStamp
using namespace AzureHunter.AzCloudInit

try {
    Get-Command Invoke-AzHunterPlaybook
}
catch {
    # Need to Import Module Invoke-AzHunterPlaybook
    . .\Invoke-AzHunterPlaybook.ps1
}

$AzureHunterLogo = @'
                                                                                                                     
                                       `           -r????]nnnnnnnnnnn}=                                              
                                       r~`         z6EOOOONQ#@@@@@@@@#g:                                             
                                       .Uh=`      ?@BREEOEOEOE8#@@@@@##E_                                            
                                        'tBZv,   .w8B#g6ObZHPhoVVsHbd%q%]`                                           
                                          *R##Rwi^:```----'```.--_____,-'`                                           
                                            :V0####@@###BQEZOOOEOOO0B#@@#BQgEqec(!-                        `._:>r(=  
                                              `=iXE#@@@@@@@#NOEOERQ####@@@#BBBBBBQQdl<.              ^]Ve560gQQ8s!`  
                                             .Vn*"`-:^r(i}lVz]]}VKZd0Q#@@@@@#BBBBBBBQB0z~`           ,tB###QQ8m!     
                                            `j####QWaznn}]v?r*!::,_'``_~|z6#@@#BBBBBBBBQQq^`     `,?tg####Q8m>`      
                                            ]##########@@@@@@#EEQ##B8R5zx<'`<Vg@##QBBBBBBQQe_`:?z%Q#8X]>6QK>`        
                                          `i8QQQBB#######@@@BEEOEN#######@@BP?'-i8@#BBBBBBBQ88QOwv~-   -}:           
                                          r8QQQQQQQQQBB###@BE66EEEE######@@@@@#v``(Q@#QBBBBBBQEr`                    
                                         >$QQQQQQQQQQQQQQ8QgRbOEEEEEQ#####@8av:`_rz8@@@#BBBBBBQ$:                    
                                        :EQQQQQQQQQQQQQgDR8Qh!HEEEEO68QZn*_`:|a8@@8q@@@@@#BBBBQd-                    
                                       _ZQQQQQQQQQQQ80EEE0QH- ~NgNZcr=..!xaQ@#6Jr,:G@@@@@@@#BQQQi                    
                             ```      _ZQQQQQQQQQQ8REEEER8H-   :<-`=?lmb6m]^=^lH8#@@@@@@@@@@@@#QN_                   
                         ,ihO80$6m(, `i8QQQQQQQ80REEEEEO$5,   `=(z%NK}<,_~n6#@@@@@@@8]rN@@@@@@@@#<                   
                       :sQ####QQQQQgV,`(8QQQQ8NEOOOOZti<,`_^]aRRa]^'`:vmD$$B@@@@@@8]`  ]@@@@@@@@@(                   
                      ^$Q####BQQQQQQQw``j880REEEZti='`,rnq0ZV?=-,<|zb8QQQQQgB@@#m^`,a^ (########B>                   
                     `GQQ####BQQQQQQQQt_`^X6Gn?!'`,?nKqh]<=!?nKRQQQQQQQQQ###Dt^''rPB#= n#######Q%-                   
                     `zQQQ###QQQQQQQQ80di``.`"^}hPV?=,~iXRQQQQQQQQQQ###8P]~.'<z8####t _8#####BQ8r                    
                      _hQQB##QQQQQQgREOG>!?nmh}r:'_*n6QQQQQQQQQQ####%]:`,?nh$#@@@@#B_`o#####QQQn`                    
                       `^GQ#BQQQQgREEEO6Pz|>__=*]sbOR8QQQQQ###@@#b}' -t8@@BQQB@@@@@i`]####QQQQn`                     
                       `,*qBBQ80EOOOEEEZ=`!lmdEOOOEO0QQ##@@@8ai!`    `z@@BQQQQ@@@#( }###BQQQN?`                      
                 `:*}aRB@@@#B8ggg88888m!`lg8Q8QQQQQQB#@#0jr_`:*r******(B#QQQQQ#@Q~ r@@@QQQ8o,                        
         `,>?]ns5g@@@@@@@@@gsU5dEOZe]:_]8##########Rtr,`-^cZB#####@@@@@#QQQQQQg]`_%@@@BQR},`.                        
     .>}K6EOEEOOOOg@@@@#Wv:=*(ii*=:>imQ########B%}~`-<lZQ##############QQQQQ8V_`x#@@@#6|-.*PZ,                       
  'regQBBBQ8$EOEEEO0@#o!rH##QQQ#############Qhr_`=vqQ############@@@@#BQQQQ$r`,E@@@@0?.-i6QQQb-                      
  }QQBBBBBBBBQ8DE6m}??wB@@@QQQQQB#######BWc^_!iUg############@@@@@@#BBBBBB0<`!O#@@@K.-]$QQQQQ@b.                     
  'qQBBBBBBBQ$WUzl]JqN#@@@@QQQQQQB###dn^,!]K8###########@@@@@@@@@@#BBBBBBB] ,OQ#@8^`?RBBBQQQ#@@a`                    
   ,EBBBBBBBBBBBBBQ8D6R#@@#QQQQQ$h(=:?jN###########@@@@@@@@@@@@@@#QBBBBBBE- zQQ8l`,sQBBBBQQQ@@@@a`             a      
    ~s5bERRREbHUtn}]cz%R#@BQ0U]~,>n%###########@@@@@@@@@@@@@@@@#BBBBBBBBBU``WB$^ !OBBBBBBQQ#@@@@@n                   
                      _KNb]<:>]K0QQQQ#####@#bb%%%%b%%%%%%%%%%%qXXXXeXXhXXi `WQ? !NQBBBBBBQQ#@@@@@@|                  
                       -:^cqQ#######B8#@@@#r                                jG`.HQQQQQQBBBB@@@@@@@#^                 
                     `r5Q#########BgRgQQ##]                                 !] .UQQQQQQQQQ#####@@@@B=                
                     iQ#########Q0EORQQQ8?                                   `  .XQQQQQQB####BBBBBBQR`               
                    r8#######BQDOEEE0QQQ]`                                       _qQQQQ#######BBBBBBQV`              
                   ~g######B8ROEEEOE8QQV`                                         :OQQ##########BBBBBQx              
                  :R#####Q0EEEEEEEONQQU'                                           ~Q############BQBBBQr             
                 _d####QDOEEEEEEEEEgQq_                                             h##############QBBB8>            
                `E##Q0EEEEEEEEEEEEDQq_                                              `h##############BB##Q<           
                _]]v??????????????|i,                                                'i]}}}}]]]]]]]]}}]]}r`          
                                                                                                                     
                                                                                                                     
                                                                                                                       
                                                                                                                     
                                                           _    _             _            
                                 /\                       | |  | |           | |           
                                /  \    _____   _ _ __ ___| |__| |_   _ _ __ | |_ ___ _ __ 
                               / /\ \  |_  / | | | '__/ _ \  __  | | | | '_ \| __/ _ \ '__|
                              / ____ \  / /| |_| | | |  __/ |  | | |_| | | | | ||  __/ |   
                             /_/    \_\/___|\__,_|_|  \___|_|  |_|\__,_|_| |_|\__\___|_|   
                                                                                        
                                a powershell framework to run threat hunting playbooks on Azure data
                        
                                                ╰(⇀︿⇀)つ-]═───> by Diego Perez (@darkquassar)                                                                                                                                          
                                                                                                                     
                                                                                                                     

'@

Function Search-AzureCloudUnifiedLog {
    <#
    .SYNOPSIS
        A PowerShell function to search the Azure Unified Audit Log (UAL)
 
    .DESCRIPTION
        This function will allow you to retrieve UAL logs iteratively implementing some safeguards to ensure the maximum log density is exported, avoiding flaky mistakes produced by the powershell ExchangeOnline API.
 
    .PARAMETER StartDate
        Start Date in the form: year-month-dayThour:minute:seconds

    .PARAMETER EndDate
        End Date in the form: year-month-dayThour:minute:seconds

    .PARAMETER TimeInterval
        Time Interval in hours. This represents the interval windows that will be queried between StartDate and EndDate. This is a sliding window.

    .PARAMETER AggregatedResultsFlushSize
        The ammount of logs that need to be accumulated before deduping and exporting. Logs are accumulated in batches, setting it to 0 (zero) gets rid of this requirement and exports all batches individually. It is recommended to set this value to 50000 for long searches (i.e. extended in time). The higher the value, the more RAM it will consume but the fewer duplicates you will find in your final results.

    .PARAMETER ResultSizeUpperThreshold
        Maximum amount of records we want returned within our current time slice and Azure session. It is recommended this is left with the default 20k.

    .PARAMETER AuditLogRecordType
        The record type that you would like to return. For a list of available ones, check API documentation: https://docs.microsoft.com/en-us/office/office-365-management-api/office-365-management-activity-api-schema#auditlogrecordtype. The default value is "All"

    .PARAMETER AuditLogOperations
        Based on the record type, there are different kinds of operations associated with them. Specify them here separated by commas, each value enclosed within quotation marks.

    .PARAMETER UserIDs
        The users you would like to investigate. If this parameter is not provided it will default to all users. Specify them here separated by commas, each value enclosed within quotation marks.

    .PARAMETER FreeText
        You can search the log using FreeText strings, matches are performed based on a "contains" method (i.e. no RegEx)

    .PARAMETER SkipAutomaticTimeWindowReduction
        This parameter will skip automatic adjustment of the TimeInterval windows between your Start and End Dates.
 
    .EXAMPLE
        Search-AzureCloudUnifiedLog -StartDate "2021-03-06T10:00:00" -EndDate "2021-06-09T12:40:00" -TimeInterval 12 -AggregatedResultsFlushSize 5000 -Verbose

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
            HelpMessage='Start Date in the form: year-month-dayThour:minute:seconds'
        )]
        [ValidatePattern("\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")]
        [ValidateNotNullOrEmpty()]
        [string]$StartDate,

        [Parameter( 
            Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            Position=1,
            HelpMessage='End Date in the form: year-month-dayThour:minute:seconds'
        )]
        [ValidatePattern("\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")]
        [ValidateNotNullOrEmpty()]
        [string]$EndDate,

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            Position=2,
            HelpMessage='Time Interval in hours. This represents the interval windows that will be queried between StartDate and EndDate'
        )]
        [ValidateNotNullOrEmpty()]
        [float]$TimeInterval=12,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=4,
            HelpMessage='The ammount of logs that need to be accumulated before deduping and exporting, setting it to 0 (zero) gets rid of this requirement and exports all batches individually. It is recommended to set this value to 50000 for long searches. The higher the value, the more RAM it will consume but the fewer duplicates you will find in your final results.'
        )]
        [ValidateNotNullOrEmpty()]
        [int]$AggregatedResultsFlushSize=0,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=5,
            HelpMessage='Maximum amount of records we want returned within our current time slice and Azure session. It is recommended this is left with the default 20k'
        )]
        [ValidateNotNullOrEmpty()]
        [int]$ResultSizeUpperThreshold=20000,

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=6,
            HelpMessage='The record type that you would like to return. For a list of available ones, check API documentation: https://docs.microsoft.com/en-us/office/office-365-management-api/office-365-management-activity-api-schema#auditlogrecordtype'
        )]
        [string]$AuditLogRecordType="All",

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=7,
            HelpMessage='Based on the record type, there are different kinds of operations associated with them. Specify them here separated by commas, each value enclosed within quotation marks'
        )]
        [string[]]$AuditLogOperations,

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=8,
            HelpMessage='The users you would like to investigate. If this parameter is not provided it will default to all users. Specify them here separated by commas, each value enclosed within quotation marks'
        )]
        [string]$UserIDs,

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=9,
            HelpMessage='You can search the log using FreeText strings'
        )]
        [string]$FreeText,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=10,
            HelpMessage='This parameter will skip automatic adjustment of the TimeInterval windows between your Start and End Dates.'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$SkipAutomaticTimeWindowReduction,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=11,
            HelpMessage='Whether to run this module with fake data'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$RunTestOnly
    )

    BEGIN {

        # Show Logo mofo
        Write-Host -ForegroundColor Green $AzureHunterLogo

        # *** Getting a handle to the running script path so that we can refer to it *** #
        if ($PSScriptRoot) {
            $ScriptPath = [System.IO.DirectoryInfo]::new($PSScriptRoot)
        } 
        else {
            $ScriptPath = [System.IO.DirectoryInfo]::new($pwd)
        }

        # Initialize Logger
        $Global:Logger = [Logger]::New().InitLogFile()
        $Logger.LogMessage("Logs will be written to: $($Logger.ScriptPath)", "DEBUG", $null, $null)
        # Initialize Pre Checks
        if(!$RunTestOnly) {
            $CloudInit = [AzCloudInit]::new()
            $CloudInit.InitializePreChecks($null)
            # Authenticate to Exchange Online   
            $GetPSSessions = Get-PSSession | Select-Object -Property State, Name
            $ExOConnected = (@($GetPSSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0
            if($ExOConnected -ne "True") {
                try {
                    Connect-ExchangeOnline -UseMultithreading $True -ShowProgress $True
                }
                catch {
                    $Logger.LogMessage("Could not connect to Exchange Online. Please run Connect-ExchangeOnline before running AzureHunter", "ERROR", $null, $_)
                    break
                }
            }
        }
    }

    PROCESS {

        # Grab Start and End Timestamps
        $TimeSlicer = [TimeStamp]::New($StartDate, $EndDate, $TimeInterval)
        $TimeSlicer.IncrementTimeSlice($TimeInterval)

        # Initialize Azure Searcher
        $AzureSearcher = [AzureSearcher]::new($TimeSlicer, $ResultSizeUpperThreshold)
        $AzureSearcher.SetRecordType([AuditLogRecordType]::$AuditLogRecordType).SetOperations($AuditLogOperations).SetUserIds($UserIds).SetFreeText($FreeText) | Out-Null
        $Logger.LogMessage("AzureSearcher Settings | RecordType: $($AzureSearcher.RecordType) | Operations: $($AzureSearcher.Operations) | UserIDs: $($AzureSearcher.UserIds) | FreeText: $($AzureSearcher.FreeText)", "SPECIAL", $null, $null)

        # Records Counter
        $TotalRecords = 0

        # Flow Control
        $TimeWindowAdjustmentNumberOfAttempts = 1  # How many times the TimeWindowAdjustmentNumberOfAttempts should be attempted before proceeding to the next block
        $NumberOfAttempts = 1   # How many times a call to the API should be attempted before proceeding to the next block
        $ResultCountEstimate = 0 # Start with a value that triggers the time window reduction loop
        # $ResultSizeUpperThreshold --> Maximum amount of records we want returned within our current time slice and Azure session
        $ShouldExportResults = $true # whether results should be exported or not in a given loop, this flag helps determine whether export routines should run when there are errors or no records provided
        $TimeIntervalReductionRate = 0.2 # the percentage by which the time interval is reduced until returned results is within $ResultSizeUpperThreshold
        $FirstOptimalTimeIntervalCheckDone = $false # whether we should perform the initial optimal timeslice check when looking for automatic time window reduction, it's initial value is $false because it means it hasn't yet been performed
        [System.Collections.ArrayList]$Script:AggregatedResults = @()

        $Logger.LogMessage("Upper Log ResultSize Threshold for each Batch: $ResultSizeUpperThreshold", "SPECIAL", $null, $null)
        $Logger.LogMessage("Aggregated Results Max Size: $AggregatedResultsFlushSize", "SPECIAL", $null, $null)

        # **** CHECK IF RUNNING TEST ONLY ****
        if($RunTestOnly) {
            $TestRecords = Get-Content ".\tests\test-data\test-auditlogs.json" | ConvertFrom-Json
            Invoke-AzHunterPlaybook -Records $TestRecords -Playbooks "AzHunter.Playbook.UAL.Exporter"
            break
        }

        # Search audit log between $TimeSlicer.StartTimeSlice and $TimeSlicer.EndTimeSlice
        while($TimeSlicer.StartTimeSlice -le $TimeSlicer.EndTime) {

            # **** START: TIME WINDOW FLOW CONTROL ROUTINE **** #
            # ************************************************* #
            if($FirstOptimalTimeIntervalCheckDone -eq $false) {
                # $AdjustmentMode = ProportionalAdjustment
                # $AzureLogSearchSessionName = RandomSessionName
                # $ResultCount = $null
                $RandomSessionName = "azurehunter-$(Get-Random)"
                $AzureSearcher.AdjustTimeInterval("ProportionalAdjustment", $RandomSessionName, $null)
                if($TimeSlicer.InitialIntervalAdjusted -eq $True) {
                    $FirstOptimalTimeIntervalCheckDone = $true
                }
                
            }
            # **** END: TIME WINDOW FLOW CONTROL ROUTINE **** #
            # *********************************************** #

            # **** START: DATA MINING FROM AZURE ROUTINE **** #
            # *********************************************** #

            # Setup block variables
            $RandomSessionName = "azurehunter-$(Get-Random)"
            $NumberOfAttempts = 1

            # We need the result cumulus to keep track of the batch of ResultSizeUpperThreshold logs (20k by default)
            # These logs will then get sort by date and the last date used as the new $StartTimeSlice value
            [System.Collections.ArrayList]$Script:ResultCumulus = @()

            # ***  RETURN LARGE SET LOOP ***
            # Loop through paged results and extract all of them sequentially, before going into the next TimeSlice cycle

            while(
                    ($Script:Results.Count -ne 0) -or 
                    ($ShouldRunReturnLargeSetLoop -eq $true) -or 
                    ($NumberOfAttempts -le 3)
                ) {
                # NOTE: when the ShouldRunReturnLargeSetLoop variable is set, it means we need to continue requesting logs within the same session until we have exhausted all available logs in the Azure Session. This means that for large datasets, the AggregatedResultsFlushSize parameter won't count unless we reduce the size of ResultSizeUpperThreshold below that of AggregatedResultsFlushSize

                # Run for this loop
                $Logger.LogMessage("Fetching next batch of logs. Session: $RandomSessionName", "LOW", $null, $null)
                $Script:Results = $AzureSearcher.SearchAzureAuditLog($RandomSessionName)

                # Test whether we got any results at all
                # If we got results, we need to determine wether the ResultSize is too big and run additional Data Consistency Checks
                if($Script:Results.Count -eq 0) {
                    $Logger.LogMessage("No more logs remaining in session $RandomSessionName. Exporting results and going into the next iteration...", "LOW", $null, $null)
                    $ShouldExportResults = $true
                    break
                }
                # We DID GET RESULTS. Let's run Data Consistency Checks before proceeding
                else {

                    $ResultCountEstimate = $Script:Results[0].ResultCount
                    $Logger.LogMessage("Batch Result Size: $ResultCountEstimate | Session: $RandomSessionName", "LOW", $null, $null)

                    # *** DATA CONSISTENCY CHECK 01: Log density within threshold *** #
                    # *************************************************************** #

                    # Test whether result size is within threshold limits
                    # Since a particular TimeInterval does not guarantee it will produce the desired log density for
                    # all time slices (log volume varies in the enterprise throught the day)
                    # This check should not matter if the user selected to Skip Automatic TimeWindow Reduction.
                    if(-not $SkipAutomaticTimeWindowReduction) {

                        if($ResultCountEstimate -eq 0) {
                            $Logger.LogMessage("Result density is ZERO. We need to try again. Attempt $NumberOfAttempts of 3", "DEBUG", $null, $null)
                            # Set results export flag
                            $ShouldExportResults = $false
                            $NumberOfAttempts++
                            continue
                        }
                        if($ResultCountEstimate -gt $ResultSizeUpperThreshold) {
                            $Logger.LogMessage("Result density is HIGHER THAN THE THRESHOLD of $ResultSizeUpperThreshold. We need to adjust time intervals.", "DEBUG", $null, $null)
                            $Logger.LogMessage("Time Interval prior to running adjustment: $($TimeSlicer.UserDefinedInitialTimeInterval)", "DEBUG", $null, $null)
                            # Set results export flag
                            $ShouldExportResults = $false
                            
                            $RandomSessionName = "azurehunter-$(Get-Random)"
                            $AzureSearcher.AdjustTimeInterval("PercentageAdjustment", $RandomSessionName, $ResultCountEstimate)
                            $Logger.LogMessage("Time Interval after running adjustment: $($TimeSlicer.UserDefinedInitialTimeInterval)", "DEBUG", $null, $null)
                            break
                        }
                        # Else if results within Threshold limits
                        else {
                            $ShouldExportResults = $true
                        }
                    }
                    
                    
                    # *** DATA CONSISTENCY CHECK 02: Sequential data consistency *** #
                    # ************************************************************** #

                    # PROBLEM WE TRIED TO SOLVE HERE: at some point Azure may start returning result indices that are not sequential and thus the results will (a) be inconsistent and (b) mess up with any script. However, using the ReturnLargeSet switch is the best way to export the highest amount of logs within a given timespan. So the solution was to implement a check and abort log exporting when result index stops being sequential.

                    # Tracking session and results for current and previous sessions
                    # This will aid in checks below for log index integrity
                    if($CurrentSession){ $FormerSession = $CurrentSession } else {$FormerSession = $RandomSessionName}
                    $CurrentSession = $RandomSessionName
                    if($HighestEndResultIndex){ $FormerHighestEndResultIndex = $HighestEndResultIndex } else {$FormerHighestEndResultIndex = $EndResultIndex}
                    $StartResultIndex = $Script:Results[0].ResultIndex
                    $HighestEndResultIndex = $Script:Results[($Script:Results.Count - 1)].ResultIndex

                    # Check for Azure API and/or Powershell crazy behaviour when it goes back and re-exports duplicated results
                    # Check (1): Is the current End Record Index lower than the previous End Record Index? --> YES --> then crazy shit, abort cycle and proceed with next iteration
                    # Check (2): Is the current End Record Index lower than the current Start Record Index? --> YES --> then crazy shit, abort cycle and proceed with next iteration

                    # Only run this check within the same session (since comparing these parameters between different sessions will return erroneous checks of course)
                    if($FormerSession -eq $CurrentSession) {
                        if (($HighestEndResultIndex -lt $FormerHighestEndResultIndex) -or ($StartResultIndex -gt $HighestEndResultIndex)) {

                            $Logger.LogMessage("Azure API or Search-UnifiedAuditLog behaving weirdly and going back in time... Need to abort this cycle and try again | CurrentSession = $CurrentSession | FormerSession = $FormerSession | FormerHighestEndResultIndex = $FormerHighestEndResultIndex | CurrentHighestEndResultIndex = $HighestEndResultIndex | StartResultIndex = $StartResultIndex |  Result Count = $($Script:Results.Count)", "ERROR", $null, $null)
                            
                            if($NumberOfAttempts -lt 3) {
                                $RandomSessionName = "azurehunter-$(Get-Random)"
                                $Logger.LogMessage("Failed to query Azure API: Attempt $NumberOfAttempts of 3. Trying again in new session: $RandomSessionName", "ERROR", $null, $null)
                                $NumberOfAttempts++
                                continue
                            }
                            else {
                                $Logger.LogMessage("Failed to query Azure API: Attempt $NumberOfAttempts of 3. Exporting collected partial results so far and increasing timeslice", "SPECIAL", $null, $null)
                                $ShouldExportResults = $true
                                break
                            }
                        }
                    }
                }

                # Collate Results
                # Append partial results to the ResultCumulus
                # in preparation for deduping and sorting
                $StartingResultIndex = $Script:Results[0].ResultIndex
                $EndResultIndex = $Script:Results[($Script:Results.Count - 1)].ResultIndex
                $Logger.LogMessage("Adding records $StartingResultIndex to $EndResultIndex", "INFO", $null, $null)
                $Script:Results | ForEach-Object { $Script:ResultCumulus.add($_) | Out-Null }

            }
            # **** END: DATA MINING FROM AZURE ROUTINE **** #
            # ********************************************* #

            # **** START: DATA POST-PROCESSING ROUTINE **** #
            # ********************************************* #
            # If available results are bigger than the Threshold, then don't export logs
            if($ShouldExportResults -eq $false) {
                continue
            }
            else {

                # Exporting logs. Run additional check for Results.Count
                try {
                    if($Script:ResultCumulus.Count -ne 0) {
                        # Sorting and Deduplicating Results
                        # DEDUPING
                        $Logger.LogMessage("Sorting and Deduplicating current batch Results", "LOW", $null, $null)
                        $ResultCountBeforeDedup = $Script:ResultCumulus.Count
                        $DedupedResults = $Script:ResultCumulus | Sort-Object -Property Identity -Unique
                        # For some reason when assigning to $DedupedResults PSOBJECT, the .Count property does not return a value when there's only a single record, so we found a workaround
                        if($Script:ResultCumulus.Count -eq 1) {$ResultCountAfterDedup = 1} else {$ResultCountAfterDedup = $DedupedResults.Count}
                        $ResultCountDuplicates = $ResultCountBeforeDedup - $ResultCountAfterDedup

                        $Logger.LogMessage("Removed $ResultCountDuplicates Duplicate Records from current batch", "SPECIAL", $null, $null)

                        # SORTING by TimeStamp
                        $SortedResults = $DedupedResults | Sort-Object -Property CreationDate
                        $Logger.LogMessage("Current batch Result Size = $($SortedResults.Count)", "SPECIAL", $null, $null)
                        
                        if($AggregatedResultsFlushSize -eq 0){
                            $Logger.LogMessage("No Aggregated Results parameter configured. Exporting current batch of records to $ExportFileName", "DEBUG", $null, $null)
                            #$SortedResults | Export-Csv $ExportFileName -NoTypeInformation -NoClobber -Append
                            Invoke-AzHunterPlaybook -Records $SortedResults -Playbooks "AzHunter.Playbook.UAL.Exporter"

                            # Count total records so far
                            $TotalRecords = $TotalRecords + $SortedResults.Count
                            $FirstCreationDateRecord = $SortedResults[0].CreationDate
                            $LastCreationDateRecord = $SortedResults[($SortedResults.Count -1)].CreationDate
                            # Report total records
                            $Logger.LogMessage("Total Records exported so far: $TotalRecords ", "SPECIAL", $null, $null)
                        }
                        elseif($Script:AggregatedResults.Count -ge $AggregatedResultsFlushSize) {

                            # Need to add latest batch of results before exporting
                            $Logger.LogMessage("AGGREGATED RESULTS | Reached maximum Aggregated Batch Threshold of $AggregatedResultsFlushSize", "INFO", $null, $null)
                            $Logger.LogMessage("AGGREGATED RESULTS | Adding current batch results to Aggregated Results", "SPECIAL", $null, $null)
                            $SortedResults | ForEach-Object { $Script:AggregatedResults.add($_) | Out-Null }

                            $AggResultCountBeforeDedup = $Script:AggregatedResults.Count
                            $Script:AggregatedResults = $Script:AggregatedResults | Sort-Object -Property Identity -Unique
                            $AggResultCountAfterDedup = $Script:AggregatedResults.Count
                            $AggResultCountDuplicates = $AggResultCountBeforeDedup - $AggResultCountAfterDedup
                            $Logger.LogMessage("AGGREGATED RESULTS | Removed $AggResultCountDuplicates Duplicate Records from Aggregated Results", "SPECIAL", $null, $null)
                            Invoke-AzHunterPlaybook -Records $Script:AggregatedResults -Playbooks "AzHunter.Playbook.UAL.Exporter"

                            # Count records so far
                            $TotalRecords = $TotalRecords + $Script:AggregatedResults.Count
                            $FirstCreationDateRecord = $SortedResults[0].CreationDate
                            $LastCreationDateRecord = $SortedResults[($SortedResults.Count -1)].CreationDate
                            # Report total records
                            $Logger.LogMessage("Total Records EXPORTED so far: $TotalRecords ", "SPECIAL", $null, $null)

                            # Reset $Script:AggregatedResults
                            [System.Collections.ArrayList]$Script:AggregatedResults = @()
                        }
                        else {
                            $Logger.LogMessage("AGGREGATED RESULTS | Adding current batch results to Aggregated Results", "SPECIAL", $null, $null)
                            $SortedResults | ForEach-Object { $Script:AggregatedResults.add($_) | Out-Null }

                            # Count records so far
                            $TotalAggregatedBatchRecords = $Script:AggregatedResults.Count
                            $FirstCreationDateRecord = $SortedResults[0].CreationDate
                            $LastCreationDateRecord = $SortedResults[($SortedResults.Count -1)].CreationDate
                            # Report total records
                            $Logger.LogMessage("AGGREGATED RESULTS | Total Records aggregated in current batch: $TotalAggregatedBatchRecords", "SPECIAL", $null, $null)
                        }

                        $Logger.LogMessage("TimeStamp of first received record in local time: $($FirstCreationDateRecord.ToLocalTime().ToString($TimeSlicer.Culture))", "SPECIAL", $null, $null)
                        $Logger.LogMessage("TimeStamp of latest received record in local time: $($LastCreationDateRecord.ToLocalTime().ToString($TimeSlicer.Culture))", "SPECIAL", $null, $null)

                        # Let's add an extra second so we avoid exporting logs that match the latest exported timestamps
                        # there is a risk we can loose a few logs by doing this, but it reduces duplicates significatively
                        $TimeSlicer.EndTimeSlice = $LastCreationDateRecord.AddSeconds(1).ToLocalTime()

                        # INCREASE TIME INTERVAL FOR NEXT CYCLE
                        $TimeSlicer.IncrementTimeSlice($TimeSlicer.UserDefinedInitialTimeInterval)

                        $Logger.LogMessage("INCREMENTED TIMESLICE | Next TimeSlice in local time: [StartDate] $($TimeSlicer.StartTimeSlice.ToString($TimeSlicer.Culture)) - [EndDate] $($TimeSlicer.EndTimeSlice.ToString($TimeSlicer.Culture))", "INFO", $null, $null)

                        # Set flag to run ReturnLargeSet loop next time
                        $ShouldRunReturnLargeSetLoop = $true
                        $SortedResults = $null
                        [System.Collections.ArrayList]$Script:ResultCumulus = @()
                    }
                    else {
                        $Logger.LogMessage("No logs found in current timewindow. Sliding to the next timeslice", "DEBUG", $null, $null)
                        # Let's add an extra second so we avoid exporting logs that match the latest exported timestamps
                        # there is a risk we can loose a few logs by doing this, but it reduces duplicates significatively

                        # INCREASE TIME INTERVAL FOR NEXT CYCLE
                        $TimeSlicer.IncrementTimeSlice($TimeSlicer.UserDefinedInitialTimeInterval)

                        $Logger.LogMessage("INCREMENTED TIMESLICE | Next TimeSlice in local time: [StartDate] $($TimeSlicer.StartTimeSlice.ToString($TimeSlicer.Culture)) - [EndDate] $($TimeSlicer.EndTimeSlice.ToString($TimeSlicer.Culture))", "INFO", $null, $null)

                        # NOTE: We are missing here a routine to capture when $TimeSlicer.StartTimeSlice -ge $TimeSlicer.EndTime and we have results in the Aggregated Batch that have not reached the export threshold. Will need to move the exporting routine to a nested function so it can be invoked here to export the last batch before the end of the timespan.
                        continue # try again
                    }
                }
                catch {
                    Write-Host $_
                    $Logger.LogMessage("GENERIC ERROR", "ERROR", $null, $_)
                }
            }
            # **** END: DATA POST-PROCESSING ROUTINE **** #
            # ********************************************* #
        }
    }
    END {
        $Logger.LogMessage("AZUREHUNTER | FINISHED EXTRACTING RECORDS", "SPECIAL", $null, $null)
    }
}

Export-ModuleMember -Function 'Search-AzureCloudUnifiedLog'