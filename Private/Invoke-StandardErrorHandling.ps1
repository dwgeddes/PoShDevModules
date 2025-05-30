<#
.SYNOPSIS
    Provides standardized error handling for the module

.DESCRIPTION
    Internal function that provides consistent error handling patterns
    across all module functions, including proper error categorization,
    logging, and cleanup operations.

.PARAMETER ErrorRecord
    The error record to process

.PARAMETER Operation
    The operation being performed when the error occurred

.PARAMETER CleanupScript
    Optional cleanup script block to execute before throwing

.PARAMETER WriteToHost
    Whether to write error information to host (for user-facing functions)

.EXAMPLE
    try {
        # Some operation
    } catch {
        Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "Installing module"
    }
#>
function Invoke-StandardErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        
        [scriptblock]$CleanupScript,
        
        [switch]$WriteToHost,
        
        [switch]$NonTerminating
    )
    
    # Execute cleanup if provided
    if ($CleanupScript) {
        try {
            & $CleanupScript
        } catch {
            Write-Warning "Cleanup operation failed: $($_.Exception.Message)"
        }
    }
    
    # Enhanced error handling
    $errorMessage = "Failed to ${Operation}: $($ErrorRecord.Exception.Message)"
    Write-Verbose "Full error details: $($ErrorRecord | Out-String)"
    
    if ($WriteToHost) {
        Write-Error "Error: $errorMessage"
    } else {
        Write-Error $errorMessage
    }
    
    if ($NonTerminating) {
        return
    }
    
    $exception = New-Object System.Exception($errorMessage, $ErrorRecord.Exception)
    $newErrorRecord = New-Object System.Management.Automation.ErrorRecord(
        $exception,
        "PoShDevModules.${Operation}",
        $ErrorRecord.CategoryInfo.Category,
        $ErrorRecord.TargetObject
    )
    throw $newErrorRecord
}
