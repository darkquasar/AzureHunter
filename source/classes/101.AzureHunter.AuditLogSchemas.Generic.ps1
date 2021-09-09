

class AuditLogSchemaGeneric {

    <#

    .SYNOPSIS
        Class to capture the generic format of UnifiedAuditLog Record

    #>

    #hidden [string] $PSComputerName
    #hidden [string] $RunspaceId
    #hidden [string] $PSShowComputerName
    [string] $RecordType
    [DateTime] $CreationDate
    [string] $UserIds
    [string] $Operations
    [string] $AuditData
    [Int32] $ResultIndex
    [Int32] $ResultCount
    [string] $Identity
    #hidden [string] $IsValid
    #hidden [string] $ObjectState

}