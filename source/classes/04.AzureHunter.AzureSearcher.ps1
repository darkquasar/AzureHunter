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
    AzureSearcher([TimeStamp] $TimeSlicer) {
        $this.TimeSlicer = $TimeSlicer
        $this.StartTimeUTC = $TimeSlicer.StartTimeSliceUTC
        $this.EndTimeUTC = $TimeSlicer.EndTimeSliceUTC
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
}
