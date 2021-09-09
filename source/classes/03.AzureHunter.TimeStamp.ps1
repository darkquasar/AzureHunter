using namespace System.IO

class TimeStamp {

    # Public Properties
    [float] $Interval
    [float] $IntervalInMinutes
    [bool] $IntervalAdjusted
    [System.Globalization.CultureInfo] $Culture
    [DateTime] $StartTime
    [DateTime] $EndTime
    [DateTime] $StartTimeSlice
    [DateTime] $EndTimeSlice
    [DateTime] $StartTimeUTC
    [DateTime] $EndTimeUTC
    [DateTime] $StartTimeSliceUTC
    [DateTime] $EndTimeSliceUTC

    # Default, Overloaded Constructor
    TimeStamp([String] $StartTime, [String] $EndTime) {
        $this.Culture = New-Object System.Globalization.CultureInfo("en-AU")
        $this.StartTime = $this.ParseDateString($StartTime)
        $this.EndTime = $this.ParseDateString($EndTime)
        $this.UpdateUTCTimestamp()
    }

    # Default, Parameterless Constructor
    TimeStamp() {
        $this.Culture = New-Object System.Globalization.CultureInfo("en-AU")
    }

    # Constructor
    [DateTime]ParseDateString ([String] $TimeStamp) {
        return [DateTime]::ParseExact($TimeStamp, $this.Culture.DateTimeFormat.SortableDateTimePattern, $null)
    }

    Reset() {
        $this.StartTimeSlice = [DateTime]::new(0)
        $this.EndTimeSlice = [DateTime]::new(0)
    }

    IncrementTimeSlice ([float] $HourlySlice) {

        $this.Interval = $HourlySlice

        # if running method for the first time, set $StartTimeSlice to $StartTime
        if(($this.StartTimeSlice -le $this.StartTime) -and ($this.EndTimeSlice -lt $this.StartTime)) {
            $this.StartTimeSlice = $this.StartTime
            $this.EndTimeSlice = $this.StartTime.AddHours($HourlySlice)
        }
        else {
            $this.StartTimeSlice = $this.EndTimeSlice
            $this.EndTimeSlice = $this.StartTimeSlice.AddHours($HourlySlice)
        }

        $this.UpdateUTCTimestamp()
    }

    [void]UpdateUTCTimestamp () {
        $this.StartTimeUTC = $this.StartTime.ToUniversalTime()
        $this.EndTimeUTC = $this.EndTime.ToUniversalTime()
        $this.StartTimeSliceUTC = $this.StartTimeSlice.ToUniversalTime()
        $this.EndTimeSliceUTC = $this.EndTimeSlice.ToUniversalTime()
    }
}