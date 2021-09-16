# AzureHunter

A Powershell module to run threat hunting playbooks on data from Azure and O365 for Cloud Forensics purposes.


[![CI](https://github.com/darkquasar/AzureHunter/actions/workflows/tag-and-release.yml/badge.svg?branch=main)](https://github.com/darkquasar/AzureHunter/actions/workflows/tag-and-release.yml)
[![PS Gallery](https://img.shields.io/badge/install-PS%20Gallery-blue.svg)](https://www.powershellgallery.com/packages/AzureHunter/)
[![Coverage Status](https://coveralls.io/repos/github/darkquasar/AzureHunter/badge.svg?branch=master)](https://coveralls.io/github/darkquasar/AzureHunter?branch=master)
[![Documentation Status](https://img.shields.io/badge/docs-latest-brightgreen.svg?style=flat)](http://AzureHunter.readthedocs.io/en/latest/?badge=latest)
![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/AzureHunter)

![azurehunter-demo-gif](https://github.com/darkquasar/AzureHunter/blob/5a94c58dbcb83cb2a153e73bebc568f1e3e96c57/media/azurehunter-gif-demo.gif)

## Getting Started

Install from the PSGallery and Import the module

    Install-Module AzureHunter -Scope CurrentUser
    Import-Module AzureHunter

## What is the UnifiedAuditLog?

The unified audit log contains user, group, application, domain, and directory activities performed in the Microsoft 365 admin center or in the Azure management portal. For a complete list of Azure AD events, see the list of [RecordTypes](https://docs.microsoft.com/en-us/office/office-365-management-api/office-365-management-activity-api-schema#auditlogrecordtype).

The UnifiedAuditLog is a great source of cloud forensic information since it contains a wealth of data on multiple types of cloud operations like ExchangeItems, SharePoint, Azure AD, OneDrive, Data Governance, Data Loss Prevention, Windows Defender Alerts and Quarantine events, Threat intelligence events in Microsoft Defender for Office 365 and the list goes on and on!

## Usage

**AzureHunter** has two main commands: `Search-AzureCloudUnifiedLog` and `Invoke-HuntAzureAuditLogs`. 

The purpose of `Search-AzureCloudUnifiedLog` is to implement a complex logic to ensure that the highest percentage of *UnifiedAuditLog records* are mined from Azure. By default, it will export extracted and deduplicated records to a CSV file.

The purpose of `Invoke-HuntAzureAuditLogs` is to provide a flexible interface into hunting playbooks stored in the `playbooks` folder. These playbooks are designed so that anyone can contribute with their own analytics and ideas. So far, only two very simple playbooks have been developed: `AzHunter.Playbook.Exporter` and `AzHunter.Playbook.LogonAnalyser`. The `Exporter` takes care of exporting records after applying de-duplication and sorting operations to the data. The `LogonAnalyser` is in beta mode and extracts events where the `Operations` property is `UserLoggedIn`. It is an example of what can be done with the playbooks and how easy it is to construct one. 

When running `Search-AzureCloudUnifiedLog`, you can pass in a list of playbooks to run per log batch. `Search-AzureCloudUnifiedLog` will pass on the batch to the playbooks via `Invoke-HuntAzureAuditLogs`.

Finally `Invoke-HuntAzureAuditLogs` can, be used standalone. If you have an export of UnifiedAuditLog records, you can load them into a Powershell Array and pass them on to this command and specify the relevant playbooks.

### Example 1 | Run search on Azure UnifiedAuditLog and extract records to CSV file (default behaviour)

```powershell
Search-AzureCloudUnifiedLog -StartDate "2020-03-06T10:00:00" -EndDate "2020-06-09T12:40:00" -TimeInterval 12 -AggregatedResultsFlushSize 5000 -Verbose
```

This command will: 
- Search data between the dates in *StartDate* and *EndDate*
- Implement a window of 12 hours between these dates, which will be used to sweep the entire length of the time interval (StartDate --> EndDate). This window will be **automatically reduced and adjusted** to provide the maximum amount of records within the window, thus ensuring higher quality of output. The time window slides sequentially until reaching the **EndDate**.
- The `AggregatedResultsFlushSize` parameter speficies the batches of records that will be processed by downstream playbooks. We are telling **AzureHunter** here to process the batch of records once the total amount reaches **5000**. This way, you can get results on the fly, without having to wait for hours until a huge span of records is exported to CSV files.

### Example 2 | Run Hunting Playbooks on CSV File

We assume that you have exported UnifiedAuditLog records to a CSV file, if so you can then do: 

```powershell
$RecordArray = Import-Csv .\my-exported-records.csv
Invoke-HuntAzureAuditLogs -Records $RecordArray -Playbooks 'AzHunter.Playbook.LogonAnalyser'
```

You can run more than one playbook by separating them via commas, they will run sequentially:

```powershell
$RecordArray = Import-Csv .\my-exported-records.csv
Invoke-HuntAzureAuditLogs -Records $RecordArray -Playbooks 'AzHunter.Playbook.Exporter', 'AzHunter.Playbook.LogonAnalyser'
```

## Why?
Since the aftermath of the *SolarWinds Supply Chain Compromise* many tools have emerged out of deep forges of cyberforensicators, carefully developed by cyber blacksmith ninjas. These tools usually help you perform cloud forensics in Azure. My intention with AzureHunter is not to bring more noise to this crowded space, however, I found myself in the need to address some gaps that I have observed in some of the tools in the space (I might be wrong though, since there is a proliferation of tools out there and I don't know them all...):

a. Azure cloud forensic tools don't usually address the complications of the Powershell API for the `UnifiedAuditLog`. This API is **very unstable and inconsistent** when exporting large quantities of data. I wanted to develop an interface that is fault tolerant (**enough**) to address some of these issues focusing solely on the *UnifiedAuditLog* since this is the Azure artefact that contains the most relevant and detailed activity logs for users, applications and services.
b. Azure cloud forensic tools don't usually put focus on developing `Playbooks`. I wanted to come up with a simple framework that would help the community create and share new playbooks.

If, however, **you are looking for a more feature rich and mature application for Azure Cloud Forensics** I would suggest you check out the excellent work performed by the cyber security experts that created the following applications: 

- CISA's [Sparrow](https://github.com/cisagov/Sparrow)
- [HAWK](https://github.com/T0pCyber/hawk)
- CrowdStrike Reporting Tool for Azure [CRT](https://github.com/CrowdStrike/CRT)

*I'm sure there is a more extensive list of tools, but these are the ones I could come up with. Feel free to suggest some more.*

### Why Powershell?

1. I didn't want to re-invent the wheel
2. Yes the Powershell interface to Azure's UnifiedAuditLog is unstable, but in terms of time-to-production it would have taken me an insane amount of hours to achieve the same thing writing a whole new interface in languages such as .NET, Golang or Python to achieve the same objectives. In the meanwhile, *the world of Cyber Defense and Response does not wait!*

## TODO

- Specify standard playbook metadata attributes that need to be present so that AzureHunter can leverage them.
- Allow for playbooks to specify dependencies on other playbooks so that one needs to be run before the other. Playbook chaining could produce interesting results and avoid code duplication.
- Develop Pester tests and Coveralls results.
- Develop documentation in ReadTheDocs.
- Allow for the specification of playbooks in SIGMA rule standard (this might require some PR to the SIGMA repo)

## More Information

For more information

* [AzureHunter.readthedocs.io](http://AzureHunter.readthedocs.io)
* [github.com/darkquasar/AzureHunter](https://github.com/darkquasar/AzureHunter)
* [ThreatHunterz.com](https://threathunterz.com)

## Credits

* Icon made by [itim2101](https://www.flaticon.com/authors/itim2101) from www.flaticon.com