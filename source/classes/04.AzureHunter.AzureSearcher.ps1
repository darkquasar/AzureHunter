using namespace System.IO

class AzureSearcher {

    # Public Properties
    [String[]] $Operations
    [String] $RecordType
    [String[]] $UserIds
    [String] $FreeText
    [DateTime] $StartTimeUTC
    [DateTime] $EndTimeUTC
    [String] $SessionId
    [TimeStamp] $TimeSlicer
    [int] $ResultSizeUpperThreshold
    [int] $ResultCountEstimate = 0

    [AzureSearcher] SetOperations([String[]] $Operations) {
        $this.Operations = $Operations
        return $this
    }

    [AzureSearcher] SetRecordType([AuditLogRecordType] $RecordType) {
        $this.RecordType = $RecordType.ToString()
        return $this
    }

    [AzureSearcher] SetUserIds([String[]] $UserIds) {
        $this.UserIds = $UserIds
        return $this
    }

    [AzureSearcher] SetFreeText([String] $FreeText) {
        $this.FreeText = $FreeText
        return $this
    }

    # Default, Overloaded Constructor
    AzureSearcher([TimeStamp] $TimeSlicer, [int] $ResultSizeUpperThreshold) {
        $this.TimeSlicer = $TimeSlicer
        $this.StartTimeUTC = $TimeSlicer.StartTimeSliceUTC
        $this.EndTimeUTC = $TimeSlicer.EndTimeSliceUTC
        $this.ResultSizeUpperThreshold = $ResultSizeUpperThreshold
    }

    [Array] SearchAzureAuditLog([String] $SessionId) {

        # Update Variables
        $this.StartTimeUTC = $this.TimeSlicer.StartTimeSliceUTC
        $this.EndTimeUTC = $this.TimeSlicer.EndTimeSliceUTC
        $this.SessionId = $SessionId

        try {
            if($this.Operations -and -not $this.RecordType) {
                throw "You must specify a RecordType if selecting and Operation"
            }
            elseif($this.RecordType -and ($this.RecordType -ne "All")) {
                
                if($this.Operations) {

                    if($this.FreeText){
                        # RecordType, Operations & FreeText parameters provided
                        $Results = Search-UnifiedAuditLog -StartDate $this.StartTimeUTC -EndDate $this.EndTimeUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $this.SessionId -RecordType $this.RecordType -Operations $this.Operations -FreeText $this.FreeText -ErrorAction Stop
                        return $Results
                    }
                    else {
                        #  Only RecordType & Operations parameters provided
                        $Results = Search-UnifiedAuditLog -StartDate $this.StartTimeUTC -EndDate $this.EndTimeUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $this.SessionId -RecordType $this.RecordType -Operations $this.Operations -ErrorAction Stop
                        return $Results
                    }

                }
                
                else {
                    if($this.FreeText){
                        # Only RecordType & FreeText parameters provided
                        $Results = Search-UnifiedAuditLog -StartDate $this.StartTimeUTC -EndDate $this.EndTimeUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $this.SessionId -RecordType $this.RecordType -FreeText $this.FreeText -ErrorAction Stop
                        return $Results
                    }
                    else {
                        # Only RecordType parameter provided, no Operations or FreeText
                        $Results = Search-UnifiedAuditLog -StartDate $this.StartTimeUTC -EndDate $this.EndTimeUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $this.SessionId -RecordType $this.RecordType -ErrorAction Stop
                        return $Results
                    }
                }
                
            }
            elseif($this.UserIds -or $this.FreeText) {

                if($this.FreeText){
                    # Fetch all data matching a particular string and a given User
                    $Results = Search-UnifiedAuditLog -StartDate $this.StartTimeUTC -EndDate $this.EndTimeUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $this.SessionId -UserIds $this.UserIds -FreeText $this.FreeText -ErrorAction Stop
                    return $Results
                }
                else {
                    # Fetch all data for a given User only
                    $Results = Search-UnifiedAuditLog -StartDate $this.StartTimeUTC -EndDate $this.EndTimeUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $this.SessionId -UserIds $this.UserIds -ErrorAction Stop
                    return $Results
                }
            }
            else {
                # Fetch all data for everything
                $Results = Search-UnifiedAuditLog -StartDate $this.StartTimeUTC -EndDate $this.EndTimeUTC -ResultSize 5000 -SessionCommand ReturnLargeSet -SessionId $this.SessionId -ErrorAction Stop
                return $Results
            }
        }
        catch {
            throw $_
        }
    }

    AdjustTimeInterval([String] $AdjustmentMode, [String] $AzureLogSearchSessionName, [Int] $ResultCount) {

        # AdjustmentType: whether we should adjust time interval by increasing it or reducing it
        # AdjustmentMode: whether we should adjust time interval based on proportion or percentage

        # Run initial check of actions to perform
        $NeedToFetchLogs = $false
        if($ResultCount) {
            $NeedToFetchLogs = $false
            $this.ResultCountEstimate = $ResultCount
        }
        else {
            $NeedToFetchLogs = $true
        }

        # **** START: TIME WINDOW FLOW CONTROL ROUTINE **** #
        # ************************************************* #
        # This routine performs a series of checks to determine whether the time window 
        # used for log extraction needs to be adjusted or not, in order to extract the 
        # highest density of logs within a specified time interval

        # Only run this block if SkipAutomaticTimeWindowReduction is not set.
        # Determine initial optimal time interval (likely to be less than 30 min anyway) or whenever required by downstream log extractors
        $TimeWindowAdjustmentNumberOfAttempts = 1
        $ToleranceBeforeIncrementingTimeSlice = 3 # This controls how many cycles we will run before increasing the TimeSlice after getting ZERO results (I said zero, not null or empty)
        $ToleranceCounter = 1

        while(($TimeWindowAdjustmentNumberOfAttempts -le 3) -and ($NeedToFetchLogs -eq $true)) {



            # Run initial query to estimate results and adjust time intervals
            try {
                $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Initial TimeSlice in local time: [StartDate] $($this.TimeSlicer.StartTimeSlice.ToString($this.TimeSlicer.Culture)) - [EndDate] $($this.TimeSlicer.EndTimeSlice.ToString($this.TimeSlicer.Culture))", "INFO", $null, $null)
                $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Extracting data from Azure to estimate initial result size", "INFO", $null, $null)

                $Results = $this.SearchAzureAuditLog($AzureLogSearchSessionName)

                
            }
            catch [System.Management.Automation.RemoteException] {
                $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Failed to query Azure API during initial ResultCountEstimate. Please check passed parameters and Azure API error", "ERROR", $null, $_)
                break
            }
            catch {
                Write-Host "ERROR ON: $_"
                if($TimeWindowAdjustmentNumberOfAttempts -lt 3) {
                    $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Failed to query Azure API during initial ResultCountEstimate: Attempt $TimeWindowAdjustmentNumberOfAttempts of 3. Trying again", "ERROR", $null, $_)
                    $TimeWindowAdjustmentNumberOfAttempts++
                    continue
                }
                else {
                    $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Failed to query Azure API during initial ResultCountEstimate: Attempt $TimeWindowAdjustmentNumberOfAttempts of 3. Exiting...", "ERROR", $null, $null)
                    break
                }
            }

            # Now check whether we got ANY RESULTS BACK AT ALL, if not, then there are no results for this particular timewindow. We need to increase timewindow and start again.
            try {
                $this.ResultCountEstimate = $Results[0].ResultCount
                $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Initial Result Size estimate: $($this.ResultCountEstimate)", "INFO", $null, $null)
            }
            catch {
                $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] No results were returned with the current parameters within the designated time window. Increasing timeslice.", "LOW", $null, $null)
                $this.TimeSlicer.IncrementTimeSlice($this.TimeSlicer.UserDefinedInitialTimeInterval)
                continue
            }

            # If we get to this point then it means we have at least received SOME results back.
            # Check if the ResultEstimate is within expected limits.
            # If it is, then break from Time Window Flow Control routine and proceed to log extraction process with new timeslice
            if($this.ResultCountEstimate -le $this.ResultSizeUpperThreshold) {

                if($this.ResultCountEstimate -eq 0) {

                    if($ToleranceCounter -le $ToleranceBeforeIncrementingTimeSlice) {
                        # Probably an error, we need to do it again
                        $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Query to Azure API during initial ResultCountEstimate returned ZERO results. This could be an API error. Attempting to retrieve results again BEFORE INCREMENTING TIMESLICE: Attempt $ToleranceCounter of $ToleranceBeforeIncrementingTimeSlice.", "LOW", $null, $null)
                        $ToleranceCounter++
                        continue
                    }
                    else {
                        $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Query to Azure API during initial ResultCountEstimate returned ZERO results after too many attempts. There are no logs within current time interval. Increasing it by user defined $($this.TimeSlicer.UserDefinedInitialTimeInterval).", "ERROR", $null, $null)
                        $this.TimeSlicer.IncrementTimeSlice($this.TimeSlicer.UserDefinedInitialTimeInterval)
                        # Reset $ToleranceCounter
                        $ToleranceCounter = 1
                    }
                    
                }
                else {
                    # Results are not ZERO and are within the expected Threshold. Great news!

                    $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Result Size estimate of $($this.ResultCountEstimate) in current time interval within expected threshold of $($this.ResultSizeUpperThreshold). No need to perform further time adjustments. Proceeding...", "INFO", $null, $null)

                    # Set control flags
                    $this.TimeSlicer.InitialIntervalAdjusted = $true
                    # Results within appettite, no need to adjust interval again
                    return
                }

                
            }
            else {
                break # break and go into TimeAdjustment routine below
            }
        }

        # This OptimalTimeIntervalCheck helps shorten the time it takes to arrive to a proper time window within the expected ResultSize window
        # Perform optimal time interval calculation via proportional estimation
        if($AdjustmentMode -eq "ProportionalAdjustment") {
            
            $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Size of results is too big. Estimating Optimal Hourly Time Interval...", "DEBUG", $null, $null)
            $OptimalTimeSlice = ($this.ResultSizeUpperThreshold * $this.TimeSlicer.UserDefinedInitialTimeInterval) / $this.ResultCountEstimate
            $OptimalTimeSlice = [math]::Round($OptimalTimeSlice, 3)
            $IntervalInMinutes = $OptimalTimeSlice * 60
            $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Estimated Optimal Hourly Time Interval: $OptimalTimeSlice ($IntervalInMinutes minutes). Reducing interval to this value...", "DEBUG", $null, $null)

            $this.TimeSlicer.UserDefinedInitialTimeInterval = $OptimalTimeSlice
            $this.TimeSlicer.Reset()
            $this.TimeSlicer.IncrementTimeSlice($OptimalTimeSlice)
            $this.TimeSlicer.InitialIntervalAdjusted = $true

            return
        }
        # Perform time interval adjustment based on IntevalReductionRate
        # if requested by downstream data processors
        elseif($AdjustmentMode -eq "PercentageAdjustment") {
            $TimeIntervalReductionRate = 0.2

            $AdjustedHourlyTimeInterval = $this.TimeSlicer.UserDefinedInitialTimeInterval - ($this.TimeSlicer.UserDefinedInitialTimeInterval * $TimeIntervalReductionRate)
            $AdjustedHourlyTimeInterval = [math]::Round($AdjustedHourlyTimeInterval, 3)
            $IntervalInMinutes = $AdjustedHourlyTimeInterval * 60
            $Global:Logger.LogMessage("[INTERVAL FLOW CONTROL] Size of results is too big. Reducing Hourly Time Interval by $TimeIntervalReductionRate to $AdjustedHourlyTimeInterval hours ($IntervalInMinutes minutes)", "INFO", $null, $null)
            
            $this.TimeSlicer.UserDefinedInitialTimeInterval = $AdjustedHourlyTimeInterval
            $this.TimeSlicer.Reset()
            $this.TimeSlicer.IncrementTimeSlice($AdjustedHourlyTimeInterval)

            return
        }
    }
}
