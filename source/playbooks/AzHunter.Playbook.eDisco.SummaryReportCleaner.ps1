<#

This Playbook imports C# module Sylvan.Data.Csv.dll SHA256: B6FAE39606A4378DF11C3F8CDAE8545F34AF3B0F7231EE2BE174D4B1EAD35428. The module was obtained from NuGet package https://www.nuget.org/packages/Sylvan.Data.Csv/

#>

Function Start-AzHunterPlaybook {
    <#
    .SYNOPSIS
        A PowerShell function to run a hunting playbook
 
    .DESCRIPTION
        This playbook expects to be provided an Advanced eDiscovery Summary Report containing a list of emails and attachments from a Review Set. It will create three different files as output: 

			1. A BasicFilteredSet which only keeps a subset of columns, applies DateTime transformations to match your local time and fills down "Date" values for attachments associated with an email belonging to the same FamilyID.
			2. A TransposedSet which grabs the BasicFilteredSet and removes the "Email_subject" and "Native_file_name" columns and, instead, consolidates both of them into a single columns called "Mail_Subject_or_File_Name"
			3. A SODSet, which grabs the results from the TransposedSet and converts it to SpreadSheet of Doom format capturing the following attributes: TimeStamp, System, Artifact, Event, User, Comments
 
    .PARAMETER Records
        An array of records or a file path to apply different data transformations to. The file is expected to be in CSV format.

    .PARAMETER SylvanCsvBufer
        The size of the CSV buffer. The bigger the buffer, the more bytes it can process but the slower it is. Default: 25000.

    .PARAMETER CsvRecordsBatchSize
        The CSV export batch size. This is the amount of records that will be accumulated in memory before dumping them to Disk or passing them to the next pipeline. Default: 2000.

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
            HelpMessage='Azure eDiscovery Summary CSV File path'
        )]
        [ValidateNotNullOrEmpty()]
        $Records,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=1,
            HelpMessage='Whether we want records returned back to the console'
        )]
        [ValidateNotNullOrEmpty()]
        [switch]$PassThru,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=2,
            HelpMessage='The size of the CSV buffer. The bigger the buffer, the more bytes it can process but the slower it is. Default: 25000'
        )]
        [ValidateNotNullOrEmpty()]
        [int]$SylvanCsvBufer = 25000,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=3,
            HelpMessage='The CSV export batch size. This is the amount of records that will be accumulated in memory before dumping them to Disk or passing them to the next pipeline. Default: 500.'
        )]
        [ValidateNotNullOrEmpty()]
        [int]$CsvRecordsBatchSize = 500,

        [Parameter( 
            Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            Position=0,
            HelpMessage='eDiscovery Item Class. The default setting will only export emails and attachments by selecting "IPM.Note" as the item class. Multiple item classes can be passed as strings separated by coma like this: "IPM.Note", "IPM.Schedule.Meeting.Request", etc. You can also pass in a value of "All" so that all items are exported in the summary. For more information see: https://docs.microsoft.com/en-us/microsoft-365/compliance/keyword-queries-and-search-conditions?view=o365-worldwide'
        )]
        [ValidateNotNullOrEmpty()]
        [String[]]$eDiscoItemClass = "IPM.Note"
    )

    BEGIN {

		# *** BEGIN: GENERAL *** #
        $PlaybookName = 'AzHunter.Playbook.eDisco.SummaryReportCleaner'
        
		# Initialize Logger
        if(!$Global:Logger){ $Logger = [Logger]::New() }
        $Logger.LogMessage("[$PlaybookName] Loading Playbook", "INFO", $null, $null)

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
        
        # Create output folder for Playbook inside default parent output folder for this session
        $PlaybookOutputFolder = New-OutputFolder -FolderName $PlaybookName

		# Load Sylvan.Data.Csv Type
		try {
			Add-Type -Path "$($Global:AzHunterRoot.FullName)\bin\Sylvan.Data.Csv.dll"
		}
		catch {
			$Logger.LogMessage("Could not load Sylvan.Data.Csv", "ERROR", $null, $_)
		}
        $CsvReaderOptions = [Sylvan.Data.Csv.CsvDataReaderOptions]::new()
        $CsvReaderOptions.BufferSize = $SylvanCsvBufer # Increasing Buffer so long strings of CSV data can be parsed without issues

        # *** END: GENERAL *** #

        $Logger.LogMessage("[$PlaybookName] Export Folder Name set to: $($PlaybookOutputFolder.FullName)", "INFO", $null, $null)
        
        # Determine whether we have an object with records or a pointer to a file
        if($Records.GetType() -eq [System.Object]) {
            $Logger.LogMessage("Cannot pass a powershell object to this playbook. Please provide a path to a CSV file.", "ERROR", $null, $_)
        }

    }

    PROCESS {

        # Load pointer to CSV File
        $csv = [Sylvan.Data.Csv.CsvDataReader]::Create("$($Records.FullName)", $CsvReaderOptions)

        # Define CSV Schema. We will iterate over all the row numbers and create a variable to hold the ordinal position of the Column
        $CsvSchemaColumnNames = $csv.GetSchemaTable().ColumnName
        ForEach($ColumnName in $CsvSchemaColumnNames) {
            $ColumnOrdinal = $csv.GetOrdinal("$ColumnName")
            New-Variable -Name "ID$ColumnName" -Value $ColumnOrdinal -Force
        }

        $SelectedColumns = @("File_class", "Family_ID", "Date", "Email_subject", "Email_sender", "Email_recipients", "Native_file_name", "Native_extension", "Native_size", "Doc_date_created", "Doc_modified_by", "Doc_date_modified", "Doc_authors", "Word_count")

        [System.Collections.ArrayList]$AzHuntereDiscoveryCollection = @()
        [System.Collections.ArrayList]$AzHuntereDiscoveryCollectionLinkedListTracker = @()

        $CurrentFamilyID = ""
        $PreviousFamilyID = ""
        $SkippedRecordFamilyID = "" # To keep track of the FamilyID items to skip as part of ItemClass check
        $SkippedRecordsCount = 0 # To keep track of how many have been skipped

        while($csv.Read()){

            $eDiscoverySchema = [Ordered]@{

                "Row_number" = $csv.GetDecimal($IDRow_number)
                "File_ID" = $csv.GetString($IDFile_ID)
                "Immutable_ID" = $csv.GetString($IDImmutable_ID)
                "File_class" = $csv.GetString($IDFile_class)
                "Family_ID" = $csv.GetString($IDFamily_ID)
                "Native_MD5" = $csv.GetString($IDNative_MD5)
                "Native_SHA_256" = $csv.GetString($IDNative_SHA_256)
                "Location_name" = $csv.GetString($IDLocation_name)
                "Location" = $csv.GetString($IDLocation)
                "Custodian" = $csv.GetString($IDCustodian)
                "Compound_path" = $csv.GetString($IDCompound_path)
                "Parent_ID" = $csv.GetString($IDParent_ID)
                "Input_file_ID" = $csv.GetString($IDInput_file_ID)
                "Input_path" = $csv.GetString($IDInput_path)
                "Load_ID" = $csv.GetString($IDLoad_ID)
                "Date" = if(($csv.GetValue($IDDate)) -ne ""){ $csv.GetDateTime($IDDate) } else { $csv.GetString($IDDate) };
                "Item_class" = $csv.GetString($IDItem_class)
                "Message_kind" = $csv.GetString($IDMessage_kind)
                "Email_to" = $csv.GetString($IDEmail_to)
                "Email_cc" = $csv.GetString($IDEmail_cc)
                "Email_bcc" = $csv.GetString($IDEmail_bcc)
                "Email_subject" = $csv.GetString($IDEmail_subject)
                "Email_date_sent" = $csv.GetString($IDEmail_date_sent)
                "Email_sender" = $csv.GetString($IDEmail_sender)
                "Email_sender_domain" = $csv.GetString($IDEmail_sender_domain)
                "Email_recipients" = $csv.GetString($IDEmail_recipients)
                "Email_recipient_domains" = $csv.GetString($IDEmail_recipient_domains)
                "Email_participants" = $csv.GetString($IDEmail_participants)
                "Email_participant_domains" = $csv.GetString($IDEmail_participant_domains)
                "Email_date_received" = $csv.GetString($IDEmail_date_received)
                "Email_action" = $csv.GetString($IDEmail_action)
                "Email_has_attachment" = $csv.GetString($IDEmail_has_attachment)
                "Email_importance" = $csv.GetString($IDEmail_importance)
                "Email_security" = $csv.GetString($IDEmail_security)
                "Email_sensitivity" = $csv.GetString($IDEmail_sensitivity)
                "Email_read_receipt" = $csv.GetString($IDEmail_read_receipt)
                "Email_delivery_receipt" = $csv.GetString($IDEmail_delivery_receipt)
                "Email_internet_headers" = $csv.GetString($IDEmail_internet_headers)
                "Email_message_ID" = $csv.GetString($IDEmail_message_ID)
                "In_reply_to_ID" = $csv.GetString($IDIn_reply_to_ID)
                "Recipient_count" = $csv.GetDecimal($IDRecipient_count)
                "Family_size" = $csv.GetDecimal($IDFamily_size)
                "Conversation_index" = $csv.GetString($IDConversation_index)
                "Conversation_ID" = $csv.GetString($IDConversation_ID)
                "Meeting_start_date" = $csv.GetString($IDMeeting_start_date)
                "Meeting_end_date" = $csv.GetString($IDMeeting_end_date)
                "Email_set" = $csv.GetString($IDEmail_set)
                "Family_duplicate_set" = $csv.GetString($IDFamily_duplicate_set)
                "Email_level" = $csv.GetString($IDEmail_level)
                "Email_thread" = $csv.GetString($IDEmail_thread)
                "Inclusive_type" = $csv.GetString($IDInclusive_type)
                "Parent_node" = $csv.GetString($IDParent_node)
                "Set_order_inclusives_first" = $csv.GetString($IDSet_order_inclusives_first)
                "Native_file_name" = $csv.GetString($IDNative_file_name)
                "Native_type" = $csv.GetString($IDNative_type)
                "Native_extension" = $csv.GetString($IDNative_extension)
                "Native_size" = (($csv.GetDecimal($IDNative_size)) / 1024) / 1024
                "Doc_date_modified" = $csv.GetString($IDDoc_date_modified)
                "Doc_date_created" = $csv.GetString($IDDoc_date_created)
                "Doc_modified_by" = $csv.GetString($IDDoc_modified_by)
                "Doc_authors" = $csv.GetString($IDDoc_authors)
                "Doc_comments" = $csv.GetString($IDDoc_comments)
                "Doc_keywords" = $csv.GetString($IDDoc_keywords)
                "Doc_version" = $csv.GetString($IDDoc_version)
                "Doc_subject" = $csv.GetString($IDDoc_subject)
                "Doc_template" = $csv.GetString($IDDoc_template)
                "Doc_title" = $csv.GetString($IDDoc_title)
                "Doc_company" = $csv.GetString($IDDoc_company)
                "Doc_last_saved_by" = $csv.GetString($IDDoc_last_saved_by)
                "O365_date_modified" = $csv.GetString($IDO365_date_modified)
                "O365_date_created" = $csv.GetString($IDO365_date_created)
                "O365_modified_by" = $csv.GetString($IDO365_modified_by)
                "O365_authors" = $csv.GetString($IDO365_authors)
                "O365_created_by" = $csv.GetString($IDO365_created_by)
                "File_system_date_modified" = $csv.GetString($IDFile_system_date_modified)
                "File_system_date_created" = $csv.GetString($IDFile_system_date_created)
                "Marked_as_pivot" = $csv.GetString($IDMarked_as_pivot)
                "Similarity_percent" = $csv.GetString($IDSimilarity_percent)
                "Pivot_ID" = $csv.GetString($IDPivot_ID)
                "Set_ID" = $csv.GetString($IDSet_ID)
                "ND_set" = $csv.GetString($IDND_set)
                "Duplicate_subset" = $csv.GetString($IDDuplicate_subset)
                "Dominant_theme" = $csv.GetString($IDDominant_theme)
                "Themes_list" = $csv.GetString($IDThemes_list)
                "ND_ET_sort_excl_attach" = $csv.GetString($IDND_ET_sort_excl_attach)
                "ND_ET_sort_incl_attach" = $csv.GetString($IDND_ET_sort_incl_attach)
                "Tags" = $csv.GetString($IDTags)
                "Potentially_privileged" = $csv.GetString($IDPotentially_privileged)
                "Extracted_content_type" = $csv.GetString($IDExtracted_content_type)
                "Compliance_labels" = $csv.GetString($IDCompliance_labels)
                "Deduped_custodians" = $csv.GetString($IDDeduped_custodians)
                "Deduped_file_IDs" = $csv.GetString($IDDeduped_file_IDs)
                "Deduped_compound_path" = $csv.GetString($IDDeduped_compound_path)
                "Extracted_text_length" = $csv.GetString($IDExtracted_text_length)
                "Has_text" = $csv.GetString($IDHas_text)
                "Word_count" = $csv.GetString($IDWord_count)
                "Error_Ignored" = $csv.GetString($IDError_Ignored)
                "Error_code" = $csv.GetString($IDError_code)
                "Was_Remediated" = $csv.GetString($IDWas_Remediated)
                "Is_representative" = $csv.GetString($IDIs_representative)
                "Export_native_path" = $csv.GetString($IDExport_native_path)
                "Converted_file_path" = $csv.GetString($IDConverted_file_path)
                "Redacted_file_path" = $csv.GetString($IDRedacted_file_path)
                "Extracted_text_path" = $csv.GetString($IDExtracted_text_path)
                "Redacted_text_path" = $csv.GetString($IDRedacted_text_path)
                "Original_input_path" = $csv.GetString($IDOriginal_input_path)
                "Original_file_extension" = $csv.GetString($IDOriginal_file_extension)
                "Group_Id" = $csv.GetString($IDGroup_Id)
                "ModernAttachment_ParentId" = $csv.GetString($IDModernAttachment_ParentId)
                "Version_GroupId" = $csv.GetString($IDVersion_GroupId)
                "Version_Number" = $csv.GetString($IDVersion_Number)
                "Channel_Name" = $csv.GetString($IDChannel_Name)
                "ConversationName" = $csv.GetString($IDConversationName)
                "ConversationType" = $csv.GetString($IDConversationType)
                "ContainsDeletedMessage" = $csv.GetString($IDContainsDeletedMessage)
                "ContainsEditedMessage" = $csv.GetString($IDContainsEditedMessage)

            }

            # *** POST-PROCESS RECORD ***
            # Drop record if it does not match our Item Class Selector
            $SkipRecord = $False
            
            if($eDiscoItemClass -ine "All") {

                # Check first whether we should ignore the record because it belongs to the same FamilyID as the one we wanted to skip. This will for example skip Attachments that belonged to a Item Classes such as "IPM.Schedule.Meeting.Request" which are meeting invites with attached documents.

                if($eDiscoverySchema.Family_ID -eq $SkippedRecordFamilyID) {
                    continue
                }

                ForEach($ItemClass in $eDiscoItemClass) { 

                    if(($eDiscoverySchema.Item_Class -eq "") -xor ($eDiscoverySchema.Item_Class -ieq $ItemClass)) {
                        $SkipRecord = $False

                    }
                    else {
                        $SkipRecord = $True
                        $SkippedRecordFamilyID = $eDiscoverySchema.Family_ID
                        $SkippedRecordsCount++
                        break
                    }
                }

                if($SkipRecord -eq $True) {
                   continue
                }

            }

            # 01. Convert Date to current timezone time format
            if($eDiscoverySchema.Date -ne ""){$eDiscoverySchema.Date = $eDiscoverySchema.Date.ToLocalTime().AddHours(-1).ToString('dd-MM-yyy hh:mm:ss tt')}

            # 02. Add new record to TempObject for FamilyID LinkedList processing
            $TempRecordObj = New-Object -TypeName PSObject -Property $eDiscoverySchema

            if($AzHuntereDiscoveryCollectionLinkedListTracker.Count -eq 2){

                $AzHuntereDiscoveryCollectionLinkedListTracker[0] = $AzHuntereDiscoveryCollectionLinkedListTracker[1]
                $AzHuntereDiscoveryCollectionLinkedListTracker[1] = $TempRecordObj
            }
            else {
                $AzHuntereDiscoveryCollectionLinkedListTracker.Add($TempRecordObj) | Out-Null

            }

            if($AzHuntereDiscoveryCollectionLinkedListTracker.Count -eq 1){
                $CurrentFamilyID = $AzHuntereDiscoveryCollectionLinkedListTracker.Family_ID
            }
            else {
                $PreviousFamilyID = $AzHuntereDiscoveryCollectionLinkedListTracker[0].Family_ID
                $CurrentFamilyID = $AzHuntereDiscoveryCollectionLinkedListTracker[1].Family_ID
            }

            # 03. Fill Down Date Values for Attachments
            # 03.01 First let's make sure that both Previous and Current FamilyIDs have the same Date
            if($PreviousFamilyID -eq $CurrentFamilyID){

                $AzHuntereDiscoveryCollectionLinkedListTracker[1].Date = $AzHuntereDiscoveryCollectionLinkedListTracker[0].Date

                # 03.02 Now ensure that the record's Date is the same as the previous one if it's an attachment
                if($eDiscoverySchema.File_class -eq "Attachment"){

                    # $eDiscoverySchema.Date = $AzHunterFamilyIDRecords | Where-Object { $eDiscoverySchema.FamilyID -eq $CurrentFamilyID } | Select-Object -ExpandProperty TimeStamp
                    $eDiscoverySchema.Date = $AzHuntereDiscoveryCollectionLinkedListTracker[0].Date
                }
            }

            # 04. Convert Doc Created Date to current timezone time format
            if($eDiscoverySchema.Doc_date_created -ne ""){$eDiscoverySchema.Doc_date_created = $eDiscoverySchema.Doc_date_created.ToDateTime([cultureinfo]::CurrentCulture).ToLocalTime().AddHours(-1).ToString('dd-MM-yyy hh:mm:ss tt')}

            # 05. Convert Doc Modified Date to current timezone time format
            if($eDiscoverySchema.Doc_date_modified -ne ""){$eDiscoverySchema.Doc_date_modified = $eDiscoverySchema.Doc_date_modified.ToDateTime([cultureinfo]::CurrentCulture).ToLocalTime().AddHours(-1).ToString('dd-MM-yyy hh:mm:ss tt')}

            # 06. We don't want to see Email Subjects on Attachments
            if($eDiscoverySchema.File_class -eq "Attachment"){ $eDiscoverySchema.Email_subject = "" }

            # 07. Delete "item.msg" from the name of the emails, since it's nondescript
            if(($eDiscoverySchema.File_class -eq "Email") -and ($eDiscoverySchema.Native_file_name -eq "item.msg")){ $eDiscoverySchema.Native_file_name = "" }


            # 08. Append Records to ArrayList if it meets document criteria
            if($eDiscoverySchema.Native_extension -ieq "msg" -or 
                $eDiscoverySchema.Native_extension -ieq "pdf" -or
                $eDiscoverySchema.Native_extension -ieq "doc" -or
                $eDiscoverySchema.Native_extension -ieq "docx" -or
                $eDiscoverySchema.Native_extension -ieq "ppt" -or
                $eDiscoverySchema.Native_extension -ieq "pptx" -or
                $eDiscoverySchema.Native_extension -ieq "xls" -or
                $eDiscoverySchema.Native_extension -ieq "xlsx" -or
                $eDiscoverySchema.Native_extension -ieq "vsd" -or
                $eDiscoverySchema.Native_extension -ieq "vsdx" -or
                $eDiscoverySchema.Native_extension -ieq "zip" -or
                $eDiscoverySchema.Native_extension -ieq "7z") {
                
                    # Add new record to eDiscoverySchema
                    $NewTempRecordObj = New-Object -TypeName PSObject -Property $eDiscoverySchema 
                    $AzHuntereDiscoveryCollection.Add($NewTempRecordObj) | Out-Null

            }

            # Add in Batches of 2000 Records
            if($AzHuntereDiscoveryCollection.Count -eq $CsvRecordsBatchSize){
                $Logger.LogMessage("Skipped $SkippedRecordsCount total records so far...", "INFO", $null, $null) 
                $Logger.LogMessage("Exporting $($AzHuntereDiscoveryCollection.Count) records to output file", "INFO", $null, $null)

                if(-not $PassThru) {
                    $AzHuntereDiscoveryCollection | Select-Object $SelectedColumns | Export-Csv -Path "$PlaybookOutputFolder\AzHunter.eDisco.SummaryReport.csv" -Append -NoClobber -NoTypeInformation
                }
                else {
                    return $AzHuntereDiscoveryCollection | Select-Object $SelectedColumns
                }

                # Reset collection to initiate next batch
                [System.Collections.ArrayList]$AzHuntereDiscoveryCollection = @()

                $Logger.LogMessage("[$PlaybookName] Current batch of records exported. Proceeding with next batch...", "INFO", $null, $null)

            }

        }

        # Add Final records
        if($AzHuntereDiscoveryCollection.Count -lt $CsvRecordsBatchSize -and $AzHuntereDiscoveryCollection.Count -gt 1) {
                $Logger.LogMessage("Exporting final $($AzHuntereDiscoveryCollection.Count) records to output file", "INFO", $null, $null)
                $AzHuntereDiscoveryCollection | Select-Object $SelectedColumns | Export-Csv -Path "$PlaybookOutputFolder\AzHunter.eDisco.SummaryReport.csv" -Append -NoClobber -NoTypeInformation
                [System.Collections.ArrayList]$AzHuntereDiscoveryCollection = @()

            }

        $csv.Close()

    }

    END {
        $Logger.LogMessage("[$PlaybookName] Finished running playbook", "INFO", $null, $null)
        
    }

}



