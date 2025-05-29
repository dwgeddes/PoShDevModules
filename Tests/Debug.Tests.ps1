#Requires -Modules Pester
$ProgressPreference = 'SilentlyContinue'
function Write-Progress { param($Activity, $Status, $PercentComplete) }
# ...existing code...