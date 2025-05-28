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
    
    # Format error message with context
    $errorMessage = "Failed to $Operation`: $($ErrorRecord.Exception.Message)"
    
    # Log the full error details for debugging
    Write-Error $errorMessage
    Write-Verbose "Full error details: $($ErrorRecord | Out-String)"
    
    # Write to host if requested (for user-facing functions)
    if ($WriteToHost) {
        Write-Error "Error: $errorMessage"
    }
    
    # Return early for non-terminating errors
    if ($NonTerminating) {
        return
    }
    
    # Create and throw a more informative error
    $exception = New-Object System.Exception($errorMessage, $ErrorRecord.Exception)
    $newErrorRecord = New-Object System.Management.Automation.ErrorRecord(
        $exception,
        "PoShDevModules.$Operation",
        $ErrorRecord.CategoryInfo.Category,
        $ErrorRecord.TargetObject
    )
    
    throw $newErrorRecord
}
