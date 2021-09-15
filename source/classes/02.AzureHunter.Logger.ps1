class Logger {

    <#

    .SYNOPSIS
        Function to write message logs from this script in JSON format to a log file. When "LogAsField" is passed it will expect a hashtable of items that will be added to the log as key/value pairs passed as value to the parameter "Dictonary".

    .PARAMETER Message
        The text to be written

    .PARAMETER OutputDir
        The directory where the scan results are stored

    .PARAMETER Dictionary
        It allows you to pass a dictionary (hashtable) where your keys and values will be converted to a json line. Nested keys are not supported.

    #>

    [Hashtable] $Dictionary
    [ValidateSet('DEBUG','ERROR','LOW','INFO','SPECIAL','REMOTELOG')]
    [string] $MessageType
    [string] $CallingModule = $( if(Get-PSCallStack){ $(Get-PSCallStack)[1].FunctionName } else {"NA"} )
    [string] $ScriptPath
    [string] $LogFileJSON
    [string] $LogFileTXT
    [string] $MessageColor
    [string] $BackgroundColor
    $Message
    [string] $LogRecordStdOut
    [string] $strTimeNow
    [bool] $LogToFile

    Logger () {
        $this.LogToFile = $False
        # Write-Host "Logging to Log File is $($this.LogToFile)"
    }

    [Logger] InitLogFile() {

        $this.LogToFile = $True

        # *** Getting a handle to the running script path so that we can refer to it *** #
        $this.ScriptPath = [System.IO.DirectoryInfo]::new($pwd)


        # This function can be chained with new() to instantiate the class and initialize a file
        $this.strTimeNow = (Get-Date).ToUniversalTime().ToString("yyMMdd-HHmmss")
        $this.LogFileJSON = "$($this.ScriptPath)\$($env:COMPUTERNAME)-azurehunter-$($this.strTimeNow).json"
        $this.LogFileTXT = "$($this.ScriptPath)\$($env:COMPUTERNAME)-azurehunter-$($this.strTimeNow).txt"
        return $this
    }

    LogMessage([string]$Message, [string]$MessageType, [Hashtable]$Dictionary, [System.Management.Automation.ErrorRecord]$LogErrorMessage) {
        
        # Capture LogType
        $this.MessageType = $MessageType.ToUpper()
        
        # Generate Data Dict
        $TimeNow = (Get-Date).ToUniversalTime().ToString("yy-MM-ddTHH:mm:ssZ")
        $LogRecord = [Ordered]@{
            "severity"      = $MessageType
            "timestamp"     = $TimeNow
            "hostname"      = $($env:COMPUTERNAME)
            "message"       = "NA"
        }

        # Let's log the dict as key-value pairs if it was passed
        if($null -ne $Dictionary) {
            ForEach ($key in $Dictionary.Keys){
                $LogRecord.Add($key, $Dictionary.Item($key))
            }
        }
        else {
            $LogRecord.message = $Message
        }

        # Should we log an Error?
        if ($null -ne $LogErrorMessage) {
            # Grab latest error namespace
            try {
                $ErrorNameSpace = $Error[0].Exception.GetType().FullName
            }
            catch {
                try {
                    $ErrorNameSpace = $Error.Exception.GetType().FullName
                }
                catch {
                    $ErrorNameSpace = "Undetermined"
                }
            }
            
            # Add Error specific fields
            $LogRecord.Add("error_name_space", $ErrorNameSpace)
            $LogRecord.Add("error_script_line", $LogErrorMessage.InvocationInfo.ScriptLineNumber)
            $LogRecord.Add("error_script_line_offset", $LogErrorMessage.InvocationInfo.OffsetInLine)
            $LogRecord.Add("error_full_line", $($LogErrorMessage.InvocationInfo.Line -replace '[^\p{L}\p{Nd}/(/)/{/}/_/[/]/./\s]', ''))
            $LogRecord.Add("error_message", $($LogErrorMessage.Exception.Message -replace '[^\p{L}\p{Nd}/(/)/{/}/_/[/]/./\s]', ''))
            $LogRecord.Add("error_id", $LogErrorMessage.FullyQualifiedErrorId)
        }

        $this.Message = $LogRecord

        # Convert log line to a readable line
        $this.LogRecordStdOut = ""
        foreach($key in $LogRecord.Keys) {
            $this.LogRecordStdOut += "$($LogRecord.$key) | "
        }
        $this.LogRecordStdOut = $this.LogRecordStdOut.TrimEnd("| ")

        # Converting log line to JSON
        $LogRecord = $LogRecord | ConvertTo-Json -Compress

        # Choosing the right StdOut Colors in case we need them
        Switch ($this.MessageType) {

            "Error" {
                $this.MessageColor = "Red"
                $this.BackgroundColor = "Black"
            }
            "Info" {
                $this.MessageColor = "Yellow"
                $this.BackgroundColor = "Black"
            }
            "Low" {
                $this.MessageColor = "Green"
                $this.BackgroundColor = "Black"
            }
            "Special" {
                $this.MessageColor = "White"
                $this.BackgroundColor = "DarkRed"
            }
            "RemoteLog" {
                $this.MessageColor = "DarkGreen"
                $this.BackgroundColor = "Green"
            }
            "Debug" {
                $this.MessageColor = "Black"
                $this.BackgroundColor = "DarkCyan"
            }

        }

        # Finally emit the logs
        if($this.LogToFile -eq $True) {
            $LogRecord | Out-File $this.LogFileJSON -Append ascii
            $this.LogRecordStdOut | Out-File $this.LogFileTXT -Append ascii
        }
        
        Write-Host $this.LogRecordStdOut -ForegroundColor $this.MessageColor -BackgroundColor $this.BackgroundColor
    }
}