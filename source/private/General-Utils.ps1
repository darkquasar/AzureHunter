<#
    This file will be loaded upon calling the module and contains generic util functions.
#>

Function New-GlobalVars {

    # *** BEGIN: GENERAL *** #

    # *** Getting a handle to the root path of the module so that we can refer to it *** #
    if ($PSScriptRoot) {
        $Global:AzHunterRoot = [System.IO.DirectoryInfo]::new($PSScriptRoot)
    } 
    else {
        $Global:AzHunterRoot = [System.IO.DirectoryInfo]::new($pwd)
    }
    if($Global:AzHunterRoot.FullName -match "source") {
        $Global:AzHunterRoot = $Global:AzHunterRoot.Parent
    }

}

Function New-OutputFolder {

    <#
    .SYNOPSIS
        Create new folders to store playbook outputs
 
    .DESCRIPTION
        
 
    .PARAMETER FolderName
        The name of the output folder to be created.

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
            HelpMessage='Plugin output folder'
        )]
        [ValidateNotNullOrEmpty()]
        $FolderName,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=1,
            HelpMessage='Whether we want to create a new parent output folder to hold the results of our plugins'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$NewParentOutputFolder
    )

    # Initialize Logger
    if(!$Global:Logger){ $Logger = [Logger]::New() }
        
    if($NewParentOutputFolder) {
        try {
            # Configure Output Folder
            $CurrentFolder = [System.IO.DirectoryInfo]::new($pwd)
            $strTimeNow = (Get-Date).ToUniversalTime().ToString("yyMMdd-HHmmss")
            $ParentFolderName = "AzHunter-$strTimeNow-output"
            $Global:AzHunterParentOutputFolder = New-Item -Path $CurrentFolder.FullName -Name $ParentFolderName -ItemType Directory
            $Logger.LogMessage("Created Parent Output Folder: $Global:AzHunterParentOutputFolder", "INFO", $null, $null)
        }
        catch {
            Write-Host "Parent Output Folder Could not be Created"
        }
    }
    else {
        
        $ProposedFolder = "$Global:AzHunterParentOutputFolder\$FolderName"
        $FolderAlreadyExists = Test-Path $ProposedFolder
        if($FolderAlreadyExists) {
            $Logger.LogMessage("Folder $ProposedFolder already exists. No need to create a new one.", "INFO", $null, $null)
            $ExistingPath = Join-Path $Global:AzHunterParentOutputFolder $FolderName
            $AzHunterPlaybookOutputFolder = [System.IO.DirectoryInfo]::new($ExistingPath)
        }
        else {
            $AzHunterPlaybookOutputFolder = New-Item -Path $Global:AzHunterParentOutputFolder -Name $FolderName -ItemType Directory
        }
        
        return $AzHunterPlaybookOutputFolder
    }

}

New-GlobalVars
New-OutputFolder -NewParentOutputFolder