using namespace AzureHunter.Logger

# A module to verify whether the right Cloud Modules are installed
class AzCloudInit {

    # Public Properties

    [array] $ModuleNames
    $Logger

    # Default, Overloaded Constructor
    AzCloudInit() {
        # Initialize Logger
        if(!$Global:Logger) {
            $this.Logger = [Logger]::New()
        }
        else {
            $this.Logger = $Global:Logger
        }
        $this.Logger.LogMessage("Initializing AzCloudInit Checks for AzureHunter", "DEBUG", $null, $null)
        
    }

    [void] InitializePreChecks([string[]] $ModuleNames) {
        $this.CheckModules($ModuleNames)
        $this.CheckBasicAuthentication()
    }

    [void] CheckModules ([string[]] $ModuleNames) {

        [System.Collections.ArrayList]$RequiredModules = @("ExchangeOnlineManagement")
        #$RequiredModules = @("ExchangeOnlineManagement","AzureAD","MSOnline")
        if($ModuleNames) {
            $ModuleNames | ForEach-Object { $RequiredModules.Add($_) | Out-Null }
        }
    
        # Attempt to import modules first, if already installed this will haste the build process
        # Those modules that cannot be imported should be flagged for installation
        $this.Logger.LogMessage("Importing Required Modules", "INFO", $null, $null)
        [System.Collections.ArrayList]$AbsentModules = @()

        ForEach($Module in $RequiredModules){
            $ModuleImported = Get-Module $Module -ErrorAction SilentlyContinue
            if(!$ModuleImported){
                
                try {
                    $this.Logger.LogMessage("Attempting to Import Module $Module", "INFO", $null, $null)
                    Import-Module $Module -ErrorAction Stop
                }
                catch {
                    $this.Logger.LogMessage("Module $Module not installed. Marked for installation", "INFO", $null, $null)
                    $AbsentModules.add($Module)
                }
            }
        }

        $this.Logger.LogMessage("Installing Dependent Modules if not already deployed in the current environment...", "INFO", $null, $null)
        ForEach($Module in $AbsentModules){
            $this.Logger.LogMessage("Checking availability of $Module", "INFO", $null, $null)
            $ModulePresent = Get-InstalledModule $Module -ErrorAction SilentlyContinue

            if(!$ModulePresent){
                $ShouldInstall = Read-Host -Prompt "Module $Module is required for AzureHunter to work, would you like to install it? (y/n)"
                if($ShouldInstall -eq "y") {
                    $this.Logger.LogMessage("Installing Module $Module", "INFO", $null, $null)
                    Install-Module $Module -Force -Scope CurrentUser
                    $this.Logger.LogMessage("Importing Module $Module", "INFO", $null, $null)
                    Import-Module $Module
                }
                else {
                    $this.Logger.LogMessage("Cannot proceed without $Module. Exiting...", "INFO", $null, $null)
                    exit
                }
                
            }
            else {
                $this.Logger.LogMessage("Module $Module already available", "INFO", $null, $null)
            }
        }
    }

    CheckBasicAuthentication() {
        # This routine will check whether Basic Auth is enabled on the system to be able to import all required modules from ExchangeOnline
        $this.Logger.LogMessage("Checking Basic Authentication", "INFO", $null, $null)
        if((Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name AllowBasic -ErrorAction SilentlyContinue).AllowBasic -eq 0) {

            $ShouldAllowBasic = Read-Host -Prompt "Basic Authentication is not enabled on this machine and it's required by ExchangeOnline to be able to import remote commands that AzureHunter utilizes. Would you like to enable it? (y/n)"
            if($ShouldAllowBasic -eq 'y') {
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name AllowBasic -Value 1 -ErrorAction SilentlyContinue
                Start-Sleep 1
                $this.Logger.LogMessage("Allowed Basic Authentication", "INFO", $null, $null)
            }
        }
    }

    ConnectExchangeOnline() {
        # Initialize ExchangeOnline Connection for queries
        $GetPSSessions = Get-PSSession | Select-Object -Property State, Name
        $ExOConnected = (@($GetPSSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0
        if($ExOConnected -ne "True") {
            Connect-ExchangeOnline
        }
    }
}
