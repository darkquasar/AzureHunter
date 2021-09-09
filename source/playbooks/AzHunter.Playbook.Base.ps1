
class AzHunterBase {
    <#
    .SYNOPSIS
        The AzHunterBase Class is applied to all records by default to ensure consistency and uniqueness
    #>

    # Public Properties
    [System.Collections.ArrayList] $AzureHuntersRecordsArray
    [int] $ResultCountBeforeDedup
    [int] $ResultCountAfterDedup
    [int] $ResultCountDuplicates
    [String] $PlaybookName = 'AzHunter.Playbook.AzHunterBase'
    $Logger

    # Default, Overloaded Constructor
    AzHunterBase([array] $AzureHuntersRecordsArray) {
        $this.AzureHuntersRecordsArray = $AzureHuntersRecordsArray
        # Initialize Logger
        if(!$Global:Logger) {
            $this.Logger = [Logger]::New()
        }
        else {
            $this.Logger = $Global:Logger
        }
        $this.Logger.LogMessage("[$($this.PlaybookName)] Initializing Playbook", "INFO", $null, $null)
    }

    [AzHunterBase] DedupRecords ([string] $Property) {

        $this.Logger.LogMessage("[$($this.PlaybookName)] Deduplicating Records", "INFO", $null, $null)
        $this.ResultCountBeforeDedup = $this.AzureHuntersRecordsArray.Count
        $TempArray = $this.AzureHuntersRecordsArray | Sort-Object -Property $Property -Unique

        # Run check in case we end up with a single record instead of an array due to it's "Unique" property
        if($TempArray.GetType() -eq [System.Collections.ArrayList]) {
            $this.AzureHuntersRecordsArray = $TempArray
            $this.ResultCountAfterDedup = $this.AzureHuntersRecordsArray.Count 
        }
        else {
            $this.AzureHuntersRecordsArray = @($TempArray)
            $this.ResultCountAfterDedup = 1
        }
        return $this

    }

    [AzHunterBase] SortRecords ([string] $Property) {

        $this.Logger.LogMessage("[$($this.PlaybookName)] Sorting Records", "INFO", $null, $null)
        # Run check in case we end up with a single record instead of an array due to it's "Unique" property
        $TempArray = $this.AzureHuntersRecordsArray | Sort-Object -Property $Property -Descending
        if($TempArray.GetType() -eq [System.Collections.ArrayList]) {
            $this.AzureHuntersRecordsArray = $TempArray
        }
        else {
            $this.AzureHuntersRecordsArray = @($TempArray)
        }

        return $this

    }

}