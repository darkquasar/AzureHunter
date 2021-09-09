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
    Get-Command Invoke-HuntAzureAuditLogs
}
catch {
    # Need to Import Module Invoke-HuntAzureAuditLogs
    . .\Invoke-HuntAzureAuditLogs.ps1
    # Need to load base playbook
    . ".\AzHunter.Playbook.Base.ps1"
}

Function Search-AzureCloudUnifiedLog {
    <#
    .SYNOPSIS
        A PowerShell function to search the Azure Audit Log
 
    .DESCRIPTION
        This function will perform....
 
    .PARAMETER InputFile
        XXXXXX

    .PARAMETER InputString
        XXXXX

    .PARAMETER InputByteArray
        XXXXX
 
    .EXAMPLE
        XXXX
 
    .EXAMPLE
        XXX

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
            HelpMessage='The record type that you would like to return. For a list of available ones, check API documentation: https://docs.microsoft.com/en-us/office/office-365-management-api/office-365-management-activity-api-schema#auditlogrecordtype'
        )]
        [string]$AuditLogRecordType="All",

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=6,
            HelpMessage='Based on the record type, there are different kinds of operations associated with them. Specify them here separated by commas, each value enclosed within quotation marks'
        )]
        [string[]]$AuditLogOperations,

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=7,
            HelpMessage='The users you would like to investigate. If this parameter is not provided it will default to all users. Specify them here separated by commas, each value enclosed within quotation marks'
        )]
        [string]$UserIDs,

        [Parameter(
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=8,
            HelpMessage='You can search the log using FreeText strings'
        )]
        [string]$FreeText,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=9,
            HelpMessage='This parameter will skip automatic adjustment of the TimeInterval windows between your Start and End Dates.'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$SkipAutomaticTimeWindowReduction,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=10,
            HelpMessage='Whether to run this module with fake data'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$RunTestOnly
    )

    BEGIN {

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
                Connect-ExchangeOnline -UseMultithreading $True -ShowProgress $True
            }
        }

        

    }

    PROCESS {

        # Grab Start and End Timestamps
        $TimeSlicer = [TimeStamp]::New($StartDate, $EndDate)
        $TimeSlicer.IncrementTimeSlice($TimeInterval)

        # Initialize Azure Searcher
        $AzureSearcher = [AzureSearcher]::new($TimeSlicer)
        $AzureSearcher.SetRecordType([AuditLogRecordType]::$AuditLogRecordType).SetOperations($AuditLogOperations).SetUserIds($UserIds).SetFreeText($FreeText) | Out-Null
        $Logger.LogMessage("AzureSearcher Settings | RecordType: $($AzureSearcher.RecordType) | Operations: $($AzureSearcher.Operations) | UserIDs: $($AzureSearcher.UserIds) | FreeText: $($AzureSearcher.FreeText)", "SPECIAL", $null, $null)

        # Records Counter
        $TotalRecords = 0

        # Flow Control
        $TimeWindowAdjustmentNumberOfAttempts = 1  # How many times the TimeWindowAdjustmentNumberOfAttempts should be attempted before proceeding to the next block
        $NumberOfAttempts = 1   # How many times a call to the API should be attempted before proceeding to the next block
        $ResultCountEstimate = 0 # Start with a value that triggers the time window reduction loop
        $ResultSizeUpperThreshold = 20000 # Maximum amount of records we want returned within our current time slice
        $ShouldExportResults = $true # whether results should be exported or not in a given loop, this flag helps determine whether export routines should run when there are errors or no records provided
        $TimeIntervalReductionRate = 0.2 # the percentage by which the time interval is reduced until returned results is within $ResultSizeUpperThreshold
        $FirstOptimalTimeIntervalCheck = $false # whether we should perform the initial optimal timeslice check when looking for automatic time window reduction
        [System.Collections.ArrayList]$Script:AggregatedResults = @()

        $Logger.LogMessage("Upper Log ResultSize Threshold for each Batch: $ResultSizeUpperThreshold", "SPECIAL", $null, $null)
        $Logger.LogMessage("Aggregated Results Max Size: $AggregatedResultsFlushSize", "SPECIAL", $null, $null)

        # **** CHECK IF RUNNING TEST ONLY ****
        if($RunTestOnly) {
            $TestRecords = Get-Content ".\tests\test-data\test-auditlogs.json" | ConvertFrom-Json
            Invoke-HuntAzureAuditLogs -Records $TestRecords
            break
        }

        while($TimeSlicer.StartTimeSlice -le $TimeSlicer.EndTime) {

            # Setup block variables
            $RandomSessionName = "azurehunter-$(Get-Random)"
            $NumberOfAttempts = 1

            # Search audit log between $TimeSlicer.StartTimeSlice and $TimeSlicer.EndTimeSlice
            # Only run this block once to determine optimal time interval (likely to be less than 30 min anyway)
            # We need to avoid scenarios where the time interval initially setup by the user is less than 30 min
            if((($ResultCountEstimate -eq 0) -xor ($ResultCountEstimate -gt $ResultSizeUpperThreshold)) -and -not $SkipAutomaticTimeWindowReduction -and -not ($TimeSlicer.IntervalAdjusted -eq $true)) {

                # Run initial query to estimate results and adjust time intervals
                try {
                    $Logger.LogMessage("Initial TimeSlice in local time: [StartDate] $($TimeSlicer.StartTimeSlice.ToString($TimeSlicer.Culture)) - [EndDate] $($TimeSlicer.EndTimeSlice.ToString($TimeSlicer.Culture))", "INFO", $null, $null)
                    $Logger.LogMessage("Querying Azure to estimate initial result size", "INFO", $null, $null)

                    $Script:Results = $AzureSearcher.SearchAzureAuditLog($RandomSessionName)
                }
                catch [System.Management.Automation.RemoteException] {
                    $Logger.LogMessage("Failed to query Azure API during initial ResultCountEstimate. Please check passed parameters and Azure API error", "ERROR", $null, $_)
                    break
                }
                catch {
                    Write-Host "ERROR ON: $_"
                    if($TimeWindowAdjustmentNumberOfAttempts -lt 3) {
                        $Logger.LogMessage("Failed to query Azure API during initial ResultCountEstimate: Attempt $TimeWindowAdjustmentNumberOfAttempts of 3. Trying again", "ERROR", $null, $_)
                        $TimeWindowAdjustmentNumberOfAttempts++
                        continue
                    }
                    else {
                        $Logger.LogMessage("Failed to query Azure API during initial ResultCountEstimate: Attempt $TimeWindowAdjustmentNumberOfAttempts of 3. Exiting...", "ERROR", $null, $null)
                        break
                    }
                }
                
                # Now check whether we got any results back, if not, then there are no results for this particular 
                # timewindow. We need to increase timewindow and start again.
                try {
                    $ResultCountEstimate = $Script:Results[0].ResultCount
                    $Logger.LogMessage("Initial Result Size estimate: $ResultCountEstimate", "INFO", $null, $null)
                }
                catch {
                    $Logger.LogMessage("No results were returned with the current parameters within the designated time window. Increasing timeslice.", "LOW", $null, $null)
                    $TimeSlicer.IncrementTimeSlice($TimeInterval)
                    continue
                }


                # Check if the ResultEstimate is within expected limits.
                # If it is, then break and proceed to log extraction process with new timeslice
                if($ResultCountEstimate -le $ResultSizeUpperThreshold) {
                    $Logger.LogMessage("Result Size estimate with new time interval value: $ResultCountEstimate", "INFO", $null, $null)
                    $TimeSlicer.IntervalAdjusted = $true
                    continue
                }

                # This OptimalTimeIntervalCheck helps shorten the time it takes to arrive to a proper time window 
                # within the expected ResultSize window
                if($FirstOptimalTimeIntervalCheck -eq $false) {
                    $Logger.LogMessage("Estimating Optimal Hourly Time Interval...", "DEBUG", $null, $null)
                    $OptimalTimeSlice = ($ResultSizeUpperThreshold * $TimeInterval) / $ResultCountEstimate
                    $OptimalTimeSlice = [math]::Round($OptimalTimeSlice, 3)
                    $IntervalInMinutes = $OptimalTimeSlice * 60
                    $Logger.LogMessage("Estimated Optimal Hourly Time Interval: $OptimalTimeSlice ($IntervalInMinutes minutes). Reducing interval to this value...", "DEBUG", $null, $null)

                    $TimeInterval = $OptimalTimeSlice
                    $TimeSlicer.Reset()
                    $TimeSlicer.IncrementTimeSlice($TimeInterval)
                    $FirstOptimalTimeIntervalCheck = $true
                    continue
                }
                else {
                    $AdjustedHourlyTimeInterval = $TimeInterval - ($TimeInterval * $TimeIntervalReductionRate)
                    $AdjustedHourlyTimeInterval = [math]::Round($AdjustedHourlyTimeInterval, 3)
                    $IntervalInMinutes = $AdjustedHourlyTimeInterval * 60
                    $Logger.LogMessage("Size of results is too big. Reducing Hourly Time Interval by $TimeIntervalReductionRate to $AdjustedHourlyTimeInterval hours ($IntervalInMinutes minutes)", "INFO", $null, $null)
                    $TimeInterval = $AdjustedHourlyTimeInterval
                    $TimeSlicer.Reset()
                    $TimeSlicer.IncrementTimeSlice($TimeInterval)
                    continue
                } 

            }

            # We need the result cumulus to keep track of the batch of 50k logs
            # These logs will get sort by date and the last date used as the new $StartTimeSlice value
            [System.Collections.ArrayList]$Script:ResultCumulus = @()

            # ***  RETURN LARGE SET LOOP ***
            # Loop through paged results and extract all of them sequentially, before going into the next TimeSlice cycle
            # PROBLEM: the problem with this approach is that at some point Azure would start returning result indices 
            # that were not sequential and thus messing up the script. However this is the best way to export the highest
            # amount of logs within a given timespan. So the 
            # solution should be to implement a check and abort log exporting when result index stops being sequential. 

            while(($Script:Results.Count -ne 0) -or ($ShouldRunReturnLargeSetLoop -eq $true) -or ($NumberOfAttempts -le 3)) {

                # Debug
                #DEBUG $Logger.LogMessage("ResultIndex End: $EndResultIndex", "DEBUG", $null, $null)
                #DEBUG $LastLogJSON = ($Results[($Results.Count - 1)] | ConvertTo-Json -Compress).ToString()
                #DEBUG $Logger.LogMessage($LastLogJSON, "LOW", $null, $null)

                # Run for this loop
                $Logger.LogMessage("Fetching next batch of logs. Session: $RandomSessionName", "LOW", $null, $null)
                $Script:Results = $AzureSearcher.SearchAzureAuditLog($RandomSessionName)
                #$Script:Results = Search-UnifiedAuditLog -StartDate $TimeSlicer.StartTimeSliceUTC -EndDate $TimeSlicer.EndTimeSliceUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $RandomSessionName

                # Test whether we got any results at all
                # If we got results, we need to determine wether the ResultSize is too big
                if($Script:Results.Count -eq 0) {
                    $Logger.LogMessage("No more logs remaining in session $RandomSessionName", "LOW", $null, $null)
                    $ShouldExportResults = $true
                    break
                }
                else {

                    $ResultCountEstimate = $Script:Results[0].ResultCount
                    $Logger.LogMessage("Batch Result Size: $ResultCountEstimate | Session: $RandomSessionName", "INFO", $null, $null)

                    # Test whether result size is within threshold limits
                    # Since a particular TimeInterval does not guarantee it will produce the desired log density for
                    # all time slices (log volume varies in the enterprise throught the day)
                    if((($ResultCountEstimate -eq 0) -or ($ResultCountEstimate -gt $ResultSizeUpperThreshold)) -and $AutomaticTimeWindowReduction) {
                        $Logger.LogMessage("Result density is higher than the threshold of $ResultSizeUpperThreshold. Adjusting time intervals.", "DEBUG", $null, $null)
                        # Reset timer flow control flags
                        $TimeSlicer.IntervalAdjusted = $false
                        $FirstOptimalTimeIntervalCheck = $false
                        # Set results export flag
                        $ShouldExportResults = $false
                        $ShouldRunTimeWindowAdjustment = $true
                        break
                    }
                    # Else if results within Threshold limits
                    else {
                        $ShouldExportResults = $true
                    }

                    # Tracking session and results for current and previous sessions
                    if($CurrentSession){ $FormerSession = $CurrentSession } else {$FormerSession = $RandomSessionName}
                    $CurrentSession = $RandomSessionName
                    if($HighestEndResultIndex){ $FormerHighestEndResultIndex = $HighestEndResultIndex } else {$FormerHighestEndResultIndex = $EndResultIndex}
                    $StartResultIndex = $Script:Results[0].ResultIndex
                    $HighestEndResultIndex = $Script:Results[($Script:Results.Count - 1)].ResultIndex
                    

                    # Check for Azure API and/or Powershell crazy behaviour when it goes back and re-exports duplicated results
                    # Check (1): Is the current end record index lower than the previous end record index? --> YES --> then crazy shit
                    # Check (2): Is the current end record index lower than the current start record index? --> YES --> then crazy shit
                    # Only run this check within the same sessions (since comparing these parameters between different sessions will return erroneous checks)
                    if($FormerSession -eq $CurrentSession) {
                        if (($HighestEndResultIndex -lt $FormerHighestEndResultIndex) -or ($StartResultIndex -gt $HighestEndResultIndex)) {

                            $Logger.LogMessage("Azure API or Search-UnifiedAuditLog behaving weirdly and going back in time... Need to abort this cycle and proceed to next timeslice | CurrentSession = $CurrentSession | FormerSession = $FormerSession | FormerHighestEndResultIndex = $FormerHighestEndResultIndex | CurrentHighestEndResultIndex = $HighestEndResultIndex | StartResultIndex = $StartResultIndex |  Result Count = $($Script:Results.Count)", "ERROR", $null, $null)
                            
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
                $StartingResultIndex = $Script:Results[0].ResultIndex
                $EndResultIndex = $Script:Results[($Script:Results.Count - 1)].ResultIndex
                $Logger.LogMessage("Adding records $StartingResultIndex to $EndResultIndex", "INFO", $null, $null)
                $Script:Results | ForEach-Object { $Script:ResultCumulus.add($_) | Out-Null }

            }

            # If available results are bigger than the Threshold, then don't export logs
            if($ShouldExportResults -eq $false) {

                if ($ShouldRunTimeWindowAdjustment) {
                    # We need to adjust time window and start again
                    continue
                }
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
                        # For some reason when assigning to $DedupedResults PSOBJECT, the .Count property does not return a value when there's only a single record
                        if($Script:ResultCumulus.Count -eq 1) {$ResultCountAfterDedup = 1} else {$ResultCountAfterDedup = $DedupedResults.Count}
                        $ResultCountDuplicates = $ResultCountBeforeDedup - $ResultCountAfterDedup

                        $Logger.LogMessage("Removed $ResultCountDuplicates Duplicate Records from current batch", "SPECIAL", $null, $null)

                        # SORTING by TimeStamp
                        $SortedResults = $DedupedResults | Sort-Object -Property CreationDate
                        $Logger.LogMessage("Current batch Result Size = $($SortedResults.Count)", "SPECIAL", $null, $null)
                        
                        if($AggregatedResultsFlushSize -eq 0){
                            $Logger.LogMessage("No Aggregated Results parameter configured. Exporting current batch of records to $ExportFileName", "DEBUG", $null, $null)
                            #$SortedResults | Export-Csv $ExportFileName -NoTypeInformation -NoClobber -Append
                            Invoke-HuntAzureAuditLogs -Records $SortedResults

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
                            #$Logger.LogMessage("AGGREGATED RESULTS | EXPORTING Aggregated Results to $ExportFileName", "SPECIAL", $null, $null)
                            #$Script:AggregatedResults | Export-Csv $ExportFileName -NoTypeInformation -NoClobber -Append
                            Invoke-HuntAzureAuditLogs -Records $Script:AggregatedResults

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
                        $TimeSlicer.IncrementTimeSlice($TimeInterval)
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
                        $TimeSlicer.IncrementTimeSlice($TimeInterval)
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
        }
    }
    END {
        $Logger.LogMessage("AZUREHUNTER | FINISHED EXTRACTING RECORDS", "SPECIAL", $null, $null)
    }
}

Export-ModuleMember -Function 'Search-AzureCloudUnifiedLog'