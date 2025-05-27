<#
.SYNOPSIS
    Writes log messages based on the specified log level

.DESCRIPTION
    Internal helper function for consistent logging throughout the module

.PARAMETER Message
    The message to log

.PARAMETER CurrentLogLevel
    The current log level setting

.PARAMETER MessageLevel
    The level of this specific message

.EXAMPLE
    Write-LogMessage "Installing module..." "Normal" "Normal"
#>
function Write-LogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$CurrentLogLevel,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$MessageLevel
    )

    $logLevels = @{
        'Silent' = 0
        'Normal' = 1
        'Verbose' = 2
    }

    if ($logLevels[$CurrentLogLevel] -ge $logLevels[$MessageLevel]) {
        switch ($MessageLevel) {
            'Normal' { Write-Host $Message -ForegroundColor Green }
            'Verbose' { Write-Verbose $Message }
            'Silent' { } # Don't output anything for silent messages
        }
    }
}
