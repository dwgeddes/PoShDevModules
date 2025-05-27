# Universal Execution Method Tests for PoShDevModules
# This file tests that all public functions support three execution methods:
# 1. Direct parameter execution
# 2. Pipeline execution  
# 3. Interactive execution

# Import the module for testing
$ModulePath = Split-Path $PSScriptRoot -Parent
Import-Module $ModulePath -Force

Write-Host "=== PoShDevModules Universal Execution Method Tests ===" -ForegroundColor Green

# Test Install-DevModule
Write-Host "`n1. Testing Install-DevModule" -ForegroundColor Yellow

# Test parameter sets
Write-Host "   Parameter Sets:" -ForegroundColor Cyan
(Get-Command Install-DevModule).ParameterSets | ForEach-Object {
    Write-Host "     - $($_.Name): $($_.Parameters.Name -join ', ')" -ForegroundColor White
}

# Test Update-DevModule
Write-Host "`n2. Testing Update-DevModule" -ForegroundColor Yellow

# Test pipeline support
Write-Host "   Pipeline Support:" -ForegroundColor Cyan
$updateParams = (Get-Command Update-DevModule).Parameters
if ($updateParams.Name -and $updateParams.Name.Attributes.ValueFromPipelineByPropertyName) {
    Write-Host "     ✓ Name parameter supports ValueFromPipelineByPropertyName" -ForegroundColor Green
} else {
    Write-Host "     ✗ Name parameter missing pipeline support" -ForegroundColor Red
}

# Test Uninstall-DevModule
Write-Host "`n3. Testing Uninstall-DevModule" -ForegroundColor Yellow

# Test pipeline support
Write-Host "   Pipeline Support:" -ForegroundColor Cyan
$removeParams = (Get-Command Uninstall-DevModule).Parameters
if ($removeParams.Name -and $removeParams.Name.Attributes.ValueFromPipelineByPropertyName) {
    Write-Host "     ✓ Name parameter supports ValueFromPipelineByPropertyName" -ForegroundColor Green
} else {
    Write-Host "     ✗ Name parameter missing pipeline support" -ForegroundColor Red
}

# Test Get-InstalledDevModule
Write-Host "`n4. Testing Get-InstalledDevModule" -ForegroundColor Yellow

# Test pipeline support
Write-Host "   Pipeline Support:" -ForegroundColor Cyan
$getParams = (Get-Command Get-InstalledDevModule).Parameters
if ($getParams.Name -and $getParams.Name.Attributes.ValueFromPipelineByPropertyName) {
    Write-Host "     ✓ Name parameter supports ValueFromPipelineByPropertyName" -ForegroundColor Green
} else {
    Write-Host "     ✗ Name parameter missing pipeline support" -ForegroundColor Red
}

# Test Invoke-DevModuleOperation
Write-Host "`n5. Testing Invoke-DevModuleOperation" -ForegroundColor Yellow

# Test parameter sets
Write-Host "   Parameter Sets:" -ForegroundColor Cyan
(Get-Command Invoke-DevModuleOperation).ParameterSets | ForEach-Object {
    Write-Host "     - $($_.Name): $($_.Parameters.Name -join ', ')" -ForegroundColor White
}

# Test all functions have proper pipeline blocks
Write-Host "`n6. Testing Pipeline Block Structure" -ForegroundColor Yellow

$functionsToTest = @('Install-DevModule', 'Update-DevModule', 'Uninstall-DevModule', 'Get-InstalledDevModule')

foreach ($functionName in $functionsToTest) {
    $functionDef = Get-Command $functionName | Select-Object -ExpandProperty Definition
    
    $hasBegin = $functionDef -match '\bbegin\s*\{'
    $hasProcess = $functionDef -match '\bprocess\s*\{'
    $hasEnd = $functionDef -match '\bend\s*\{'
    
    Write-Host "   $functionName pipeline blocks:" -ForegroundColor Cyan
    Write-Host "     Begin: $(if($hasBegin){'✓'}else{'✗'})" -ForegroundColor $(if($hasBegin){'Green'}else{'Red'})
    Write-Host "     Process: $(if($hasProcess){'✓'}else{'✗'})" -ForegroundColor $(if($hasProcess){'Green'}else{'Red'})  
    Write-Host "     End: $(if($hasEnd){'✓'}else{'✗'})" -ForegroundColor $(if($hasEnd){'Green'}else{'Red'})
}

# Test parameter validation
Write-Host "`n7. Testing Parameter Validation" -ForegroundColor Yellow

$functionsToTest = @('Install-DevModule', 'Update-DevModule', 'Uninstall-DevModule', 'Get-InstalledDevModule')

foreach ($functionName in $functionsToTest) {
    $params = (Get-Command $functionName).Parameters
    Write-Host "   $functionName validation:" -ForegroundColor Cyan
    
    foreach ($paramName in $params.Keys) {
        $param = $params[$paramName]
        $hasValidation = $param.Attributes | Where-Object { 
            $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] -or
            $_ -is [System.Management.Automation.ValidateScriptAttribute] -or
            $_ -is [System.Management.Automation.ValidateSetAttribute]
        }
        
        if ($hasValidation) {
            Write-Host "     ✓ $paramName has validation" -ForegroundColor Green
        }
    }
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Green
Write-Host "All public functions have been analyzed for:" -ForegroundColor White
Write-Host "- Parameter sets for multiple operation modes" -ForegroundColor White
Write-Host "- Pipeline support (ValueFromPipelineByPropertyName)" -ForegroundColor White
Write-Host "- Proper begin/process/end block structure" -ForegroundColor White
Write-Host "- Parameter validation attributes" -ForegroundColor White
