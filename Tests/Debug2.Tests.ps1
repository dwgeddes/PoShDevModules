#Requires -Modules Pester
$ProgressPreference = 'SilentlyContinue'
function Write-Progress { param($Activity, $Status, $PercentComplete) }

Describe "My Test Suite" {
    It "Test Case 1" {
        # Your test code here
    }

    It "Test Case 2" {
        # Your test code here
    }
}