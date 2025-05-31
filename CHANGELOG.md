# PowerShell Module Refinement Instructions - v2.1.2

## 🚨 CRITICAL RULES - NO EXCEPTIONS

**NEVER create wrapper functions** that just call existing PowerShell cmdlets without adding real value.

**MANDATORY: Update Logs/performance-{ModuleName}.json** continuously with timestamps and objective measurements.

**ASSUMPTION VALIDATION PROTOCOL**: Before implementing any solution:
1. **Document Assumptions**: List what you're assuming about PowerShell behavior
2. **Test Assumptions**: Create simplest possible test for each assumption  
3. **Explain Dependencies**: State PowerShell rules/behaviors you're relying on
4. **Reality Check**: Test one assumption at a time with minimal examples

Example: "I assume private functions are available in public function scope"
→ Test: Create minimal function that calls private helper, run it directly

**MENTAL MODEL VALIDATION**: Before claiming completion:
- Explain why this should work based on PowerShell behavior
- Identify what could break this approach
- Test the specific mechanism you're relying on
- Validate actual behavior matches expected behavior

**EXECUTION TIMEOUT PROTOCOL**: Before any command execution:
- Predict completion time: "Should finish in X seconds/minutes"
- Report at 30 seconds: "Still running, estimated X more time"
- Report at 2 minutes: "Taking longer than expected, may be hanging"
- Auto-terminate at 5 minutes: "Operation terminated - likely hanging due to prompts/progress bars"
- Common hangs: Write-Progress, Read-Host, confirmation dialogs, subprocess inheritance

**INDIVIDUAL FUNCTION VALIDATION**: Before claiming any function works:
```powershell
# Test each public function in isolation
Remove-Module ModuleName -Force -ErrorAction SilentlyContinue
Import-Module .\ModuleName.psd1 -Force
$result = Get-SpecificFunction -Parameter "TestValue"
Write-Host "Function result: $result"
```

**SUBPROCESS EXECUTION VALIDATION**: For any operation that spawns processes:
- Test in isolated PowerShell session
- Verify no hanging on automated execution
- Check subprocess inheritance of parent session settings

**BLOCKED: Cannot run tests without timeout protection**
Before ANY test execution, verify each test file contains:
- Start-Job wrapper OR Mock commands OR Test-WithTimeout function
- If missing: STOP, add protection, then proceed

**MANDATORY: Private Function Export Check**
After Stage 1 assessment:
- List all Private/*.ps1 functions
- Check if tests reference any private functions  
- If yes: Either export them or mock them
- Document decision in assumptions_documented

**CRUD Module Time Management:**
- <10 functions = 30min maximum
- If approaching limit: Log scope_creep_detected, stop work, ask user

**TIMEOUT PROTECTION - MANDATORY FOR TESTS**: Wrap potentially hanging operations:

```powershell
# Method 1: Start-Job with timeout (recommended)
It "tests operation without hanging" {
    $job = Start-Job { 
        Import-Module ./ModuleName.psd1
        Update-SomeFunction -Parameter "Test"
    }
    $completed = Wait-Job $job -Timeout 30
    if ($completed) {
        $result = Receive-Job $job
        Remove-Job $job
        $result | Should -Not -BeNull
    } else {
        Remove-Job $job -Force
        throw "Operation timed out after 30 seconds - likely hanging"
    }
}

# Method 2: Mock interactive commands
BeforeAll {
    Mock Read-Host { return "mocked-input" }
    Mock Write-Progress { }
    $global:ConfirmPreference = 'None'
}

# Method 3: Force non-interactive parameters
It "uses non-interactive execution" {
    Update-DevModule -ModuleName "Test" -Force -NonInteractive
}

# Method 4: Runspace timeout for complex operations
function Test-WithTimeout {
    param($ScriptBlock, $TimeoutSeconds = 10)
    $ps = [PowerShell]::Create()
    $ps.AddScript($ScriptBlock)
    $async = $ps.BeginInvoke()
    if ($async.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000)) {
        $result = $ps.EndInvoke($async)
        $ps.Dispose()
        return $result
    } else {
        $ps.Stop()
        $ps.Dispose()
        throw "Operation timed out after $TimeoutSeconds seconds"
    }
}
```

**USE TIMEOUT PROTECTION FOR**: Subprocess calls, file operations, network requests, module operations, any function that might prompt user

**VERIFICATION REQUIREMENT**: After claiming any change:
```powershell
# Prove the change was made
Get-Content $file | Select-String "expected_change" | Should -Not -BeNullOrEmpty
# Run the test that was supposedly fixed
Invoke-Pester "Tests/specific.tests.ps1" -TestName "FailingTest"
```

**NEVER ASSUME EXTERNAL PROBLEMS** without testing the assumption first. Before claiming "corrupt data", "permission issues", or "OS problems" - create a test that proves it.

**TEST REAL USER WORKFLOWS** - not testing theater. Use public API exactly as users would, with real execution.

**DECISION JUSTIFICATION PROTOCOL**: Before every major decision, state: [What I'm deciding] [Options considered] [Instruction section referenced] [Reasoning] [Predicted risks]

**INSTRUCTION CITATION REQUIREMENT**: For every action, format as: "Following [Section X.Y], I am doing [action] because [reasoning]"

**FAILURE PREDICTION PROTOCOL**: Before implementing any solution, predict the top 3 ways this could fail and how to detect each failure quickly

**NEVER IGNORE FAILING TESTS.** If a test isn't worth fixing, it wasn't worth testing for.

## STAGE 1: MODULE ASSESSMENT & ARCHETYPE IDENTIFICATION

### Quick Assessment (5 minutes max)

**Function Count & Complexity:**
```powershell
# Count functions and classify
$publicFunctions = Get-ChildItem Public/*.ps1 | Measure-Object
$avgLinesPerFunction = (Get-Content Public/*.ps1 | Measure-Object -Line).Lines / $publicFunctions.Count
```

**Module Archetype Classification:**
- **CRUD Module**: <10 functions, mostly Get/Set/New/Remove operations
- **API Integration**: External API calls, authentication, data transformation  
- **File Processing**: File system operations, path handling, cross-platform needs
- **Legacy Conversion**: Old code patterns, Windows-specific, needs modernization
- **Utility Collection**: >15 unrelated functions, Swiss Army knife pattern

**Critical Issues Triage:**
- **BLOCKER**: Module won't import or core functions crash
- **MAJOR**: Standards violations, security issues, broken functionality
- **MINOR**: Style, naming, optimization opportunities

**Decision Matrix:**
```
Functions <5 + no critical issues = SKIP (just run tests)
CRUD + minor issues only = STANDARDS CLEANUP
API/File Processing + any major issues = FULL REFINEMENT  
Legacy Conversion = FULL REFINEMENT (high value)
Utility Collection = EVALUATE BY FUNCTION
```

**Cross-Platform Validation Checkpoint:**
- [ ] No hardcoded Windows paths (`C:\`, `$env:USERPROFILE`)
- [ ] Uses `Join-Path` for all path operations
- [ ] Tests file permissions handling
- [ ] No Windows-specific cmdlets unless documented

### Stage 1 Performance Tracking
**MANDATORY LOGGING**: Update performance-report.json with:
```json
{
  "stage_1_assessment": {
    "timestamp": "2024-XX-XX_XX:XX:XX",
    "time_minutes": X,
    "model_used": "claude-3-5-sonnet",
    "assumptions_documented": [
      {"assumption": "module_loads_private_functions", "test_method": "direct_function_call", "validated": true}
    ],
    "decision_reasoning": {
      "what_deciding": "module_archetype_and_approach",
      "options_considered": ["skip", "standards_cleanup", "full_refinement"],
      "instruction_cited": "section_1_decision_matrix",
      "choice_made": "full_refinement",
      "reasoning": "Legacy module with major standards violations",
      "predicted_risks": ["time_overrun", "complex_dependencies", "test_failures"],
      "confidence": 0.8
    },
    "context_state": {
      "files_examined": ["Public/Get-User.ps1", "ModuleName.psd1"],
      "module_archetype": "LegacyConversion",
      "function_count": 12,
      "avg_lines_per_function": 45,
      "critical_issues": 3,
      "major_issues": 7,
      "minor_issues": 15,
      "cross_platform_compatible": true
    },
    "instruction_adherence": {
      "followed_assessment_protocol": true,
      "cited_correct_section": true,
      "completed_within_time_budget": true
    }
  }
}
```

**CONTINUOUS VALIDATION CHECKPOINT**: After assessment, validate:
- [ ] Module imports without errors
- [ ] Function count matches what I counted  
- [ ] Archetype classification makes sense
- [ ] Decision aligns with instruction matrix
- [ ] Cross-platform considerations documented
- [ ] **Private function export check completed**
- [ ] **Time budget appropriate for module complexity**

## STAGE 2: ARCHETYPE-SPECIFIC CRITICAL FIXES

### CRUD Module Pattern
**Focus**: Parameter validation, return standardization, pipeline support
**Time Budget**: 15-30 minutes
**Quality Gate**: All CRUD operations return consistent object types

```powershell
# CRUD Function Template
function Verb-Noun {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )
    process {
        if ($null -eq $Id) { return }  # Empty pipeline handling
        try {
            # Core logic here
            [PSCustomObject]@{ Id = $Id; Status = 'Success'; Data = $result }
        }
        catch { Write-Error "Failed to process '$Id': $($_.Exception.Message)"; return $null }
    }
}
```

### API Integration Module Pattern  
**Focus**: Error handling, authentication, rate limiting, retries
**Time Budget**: 30-45 minutes
**Quality Gate**: All API calls wrapped in try/catch with specific error handling

```powershell
# API Function Template
function Invoke-ApiOperation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,
        
        [Parameter()]
        [hashtable]$Headers = @{},
        
        [Parameter()]
        [int]$MaxRetries = 3
    )
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            if ($PSCmdlet.ShouldProcess($Endpoint, "API call")) {
                $result = Invoke-RestMethod -Uri $Endpoint -Headers $Headers -ErrorAction Stop
                return $result
            }
        }
        catch [System.Net.WebException] {
            $attempt++
            if ($attempt -ge $MaxRetries) { throw }
            Write-Warning "API call failed, retrying ($attempt/$MaxRetries)"
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}
```

### File Processing Module Pattern
**Focus**: Cross-platform paths, permissions, TestDrive usage
**Time Budget**: 20-35 minutes  
**Quality Gate**: All file operations use cross-platform path handling

```powershell
# File Processing Template
function Process-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$Path
    )
    
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $safeFileName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
    $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "$safeFileName-processed.txt"
    
    try {
        # Processing logic here
        return $outputPath
    }
    catch [System.IO.IOException] {
        Write-Error "File operation failed: $($_.Exception.Message)"
        return $null
    }
}
```

### Stage 2 Decision Rules
**Helper Function Creation Rules:**
- Same logic in 3+ places AND >10 lines AND complex logic = CREATE
- Simple parameter passing OR single cmdlet call = DO NOT CREATE
- Cross-cutting concern (logging, auth) = CREATE if used in 3+ functions

**SAFE DESIGN PATTERNS - Use These Templates:**

```powershell
# SAFE: Parameter design that prevents breaking changes
[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    
    [Parameter()]
    [ValidateSet('Create','Update','Delete')]
    [string]$Action = 'Create',
    
    [Parameter()]
    [ValidateRange(1,100)]
    [int]$Timeout = 30
)

# SAFE: Return object pattern
return [PSCustomObject]@{
    Name = $Name
    Status = 'Success'
    Action = $Action
    Timestamp = Get-Date
}

# SAFE: Error handling pattern
try {
    # Core logic
} catch [System.IO.FileNotFoundException] {
    Write-Error "File not found: $Path"
    return $null
} catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
    throw
}
```

**Quality Gate Criteria:**
- Module imports without errors ✅
- No wrapper functions exist ✅  
- Critical issues from Stage 1 resolved ✅

## STAGE 3: MODULE STRUCTURE OPTIMIZATION & TESTING

### Module Structure Validation (Before Testing)

**MANDATORY: Module Organization Review**
Before running any tests, validate and optimize structure:

**Directory Structure Requirements:**
- [ ] All test scripts in `Tests/` directory (*.Tests.ps1)
- [ ] All public functions in `Public/` directory  
- [ ] All private functions in `Private/` directory
- [ ] Module root clear of misplaced files

**Function Organization Optimization:**
```powershell
# Review function organization
Get-ChildItem Public/*.ps1 | ForEach-Object {
    $lines = (Get-Content $_ | Measure-Object -Line).Lines
    $functions = Select-String "^function " $_ | Measure-Object
    Write-Host "$($_.Name): $lines lines, $($functions.Count) functions"
}
```

**Organization Rules:**
- **Single function per file**: <50 lines = separate files
- **Related functions grouped**: >50 lines + related = combine  
- **Subdirectories**: >10 functions = organize by category
- **Test consolidation**: Group related test scenarios

**File Placement Validation:**
- Move misplaced functions to correct directories
- Consolidate or split files based on organization rules
- Create subdirectories if needed (Public/Auth/, Public/Core/)
- Optimize test file structure and naming
- **Remove unused/obsolete files** (old scripts, duplicates, temp files)

### Test Planning Phase (Before Writing Tests)

**MANDATORY: Test Script Review Before Execution**
Before running any tests, validate:
- [ ] Timeout protection on all potentially hanging operations
- [ ] Expected error sections clearly marked with Context blocks
- [ ] No hardcoded paths or Windows-specific operations
- [ ] Mock/real decision follows instruction guidelines  
- [ ] Test names describe expected behavior, not implementation
- [ ] Individual function validation included
- [ ] Pipeline testing with empty/null/multiple inputs

**🚨 CRITICAL: Test Real User Experience, Not Testing Theater**

**Required Test Scenarios by Archetype:**

**CRUD Module Test Matrix:**
```
MANDATORY USER WORKFLOW TEST (must pass before completion):
$testName = "TestObject123"
$created = New-Something -Name $testName
$retrieved = Get-Something -Name $testName  
$updated = Set-Something -Name $testName -Property "NewValue"
$removed = Remove-Something -Name $testName

Additional validations:
✅ Invalid input returns null + Write-Error  
✅ Pipeline with multiple objects works
✅ Pipeline with empty input returns gracefully
✅ Parameter validation catches bad input
```

**API Integration Test Matrix:**
```  
✅ Real API call with test credentials (if safe)
OR Mock successful API response (if external)
✅ Network timeout/failure handling
✅ Authentication failure handling  
✅ Rate limiting response handling
✅ Retry logic verification with real delays
```

**File Processing Test Matrix:**
```
✅ Real file processing (use TestDrive)
✅ Non-existent file handling 
✅ Permission denied scenarios (simulate with TestDrive)
✅ Cross-platform path handling with real paths
✅ Full read-process-write cycle validation
```

**🚨 ASSUMPTION VALIDATION PROTOCOL**
Before assuming external problems:
- **"File corrupt" assumption**: Create test file and verify it works
- **"Permission issue" assumption**: Test with known good permissions  
- **"Data problem" assumption**: Test with fresh, simple data
- **"OS/Platform issue" assumption**: Test same operation on test data

**REAL vs MOCK DECISION RULES:**
```
Use REAL execution for:
✅ Public API smoke tests (ALWAYS)
✅ User workflow validation (ALWAYS)
✅ Basic functionality verification (ALWAYS)
✅ Cross-platform compatibility (ALWAYS)

Use MOCKS only for:
✅ External system dependencies (APIs, databases)
✅ Error condition simulation  
✅ Performance testing with large datasets
✅ Dangerous operations (file deletion, etc.)
```

### Enhanced Testing Patterns

**Expected Error Organization:**
```powershell
Context "Expected Error Scenarios - Errors Below Are Intentional" {
    It "should throw on invalid input" {
        { Get-User -Name "" } | Should -Throw
    }
    It "should return null on missing file" {
        Get-FileData -Path "nonexistent.txt" | Should -BeNull
    }
}

Context "Normal Operation Scenarios - No Errors Expected" {
    It "should process valid data" {
        $result = Get-User -Name "ValidUser"
        $result.Name | Should -Be "ValidUser"
    }
}
```

### Test Data Strategy
```powershell
# Test data generation patterns
$testUsers = @(
    @{Name='ValidUser'; Id=1; Email='user@test.com'},
    @{Name=''; Id=2; Email='invalid'},  # Invalid name
    @{Name='EdgeCase'; Id=$null; Email='edge@test.com'}  # Invalid ID
)

# Use data-driven tests
It "handles various user inputs" -TestCases $testUsers {
    param($Name, $Id, $Email)
    $result = Get-User -Name $Name -Id $Id
    # Assertions based on expected behavior
}
```

### Integration Test Architecture
```powershell
# Safe integration testing pattern
param([switch]$RunIntegrationTests)
if (-not $RunIntegrationTests) { 
    Write-Warning "Integration tests skipped. Use -RunIntegrationTests to enable."
    return 
}

# Use staging/test environments
$testConfig = @{
    ApiEndpoint = 'https://api-staging.example.com'
    TestCredential = Get-StoredCredential -Name 'TestAccount'
}
```

### Testing Performance Baseline
Before writing tests, establish what "good" looks like:
- **High-value test**: Finds real bug in <5 minutes of creation
- **Medium-value test**: Exercises important code path, quick to maintain
- **Low-value test**: Takes >10 minutes to write, finds no real issues

### Stage 3 Performance Tracking & Continuous Validation
**MANDATORY LOGGING**: Update performance-report.json for each test decision:
```json
{
  "stage_3_testing_strategy": {
    "test_planning_phase": {
      "timestamp": "2024-XX-XX_XX:XX:XX", 
      "time_minutes": 12,
      "assumptions_documented": [
        {"assumption": "pipeline_supports_empty_input", "test_method": "empty_array_test", "validated": true}
      ],
      "decision_reasoning": {
        "what_deciding": "test_scenarios_to_implement",
        "options_considered": ["comprehensive_coverage", "targeted_high_value", "minimal_smoke_tests"],
        "instruction_cited": "stage_3_test_matrix_crud",
        "choice_made": "targeted_high_value",
        "reasoning": "CRUD module with clear patterns, focus on user scenarios",
        "predicted_risks": ["missing_edge_cases", "over_testing_framework", "insufficient_integration"]
      }
    },
    "test_implementation": [
      {
        "test_name": "Get-User parameter validation",
        "timestamp": "2024-XX-XX_XX:XX:XX",
        "time_minutes": 5,
        "test_type": "high_value",
        "timeout_protection_used": true,
        "decision_reasoning": {
          "what_deciding": "mock_vs_real_testing_approach", 
          "options_considered": ["mock_get_aduser", "use_test_data", "integration_test"],
          "instruction_cited": "stage_3_mock_decision_tree", 
          "choice_made": "use_test_data",
          "reasoning": "Testing our logic, not Active Directory",
          "predicted_risks": ["test_data_unrealistic", "missing_integration_issues"]
        },
        "validation_results": {
          "test_runs": true,
          "finds_real_issue": true,
          "maintenance_burden": "low",
          "execution_time_ms": 45
        }
      }
    ],
    "test_effectiveness_analysis": {
      "total_tests_written": 8,
      "high_value_tests": 5,
      "medium_value_tests": 2, 
      "tests_removed": 1,
      "real_issues_found": 3,
      "time_on_real_issues_minutes": 15,
      "time_on_test_maintenance_minutes": 8,
      "effectiveness_ratio": 0.65
    }
  }
}
```

**CONTINUOUS VALIDATION**: After each test implementation:
- [ ] Test runs without framework errors
- [ ] Test actually validates intended behavior using REAL execution
- [ ] Test doesn't take >30 seconds to execute
- [ ] Test failure would indicate real problem, not test setup issue
- [ ] Test uses public API exactly as user would call it
- [ ] Timeout protection implemented for any potentially hanging operations

### Complete Testing Workflow

**After Structure Optimization:**
1. **Run Tests**: Execute full test suite with timeout protection
2. **Fix All Issues**: Address every test failure systematically  
3. **Complete Module Review**: 
   - Review contents of every folder in module
   - Verify file contents belong in current path
   - If misplaced: integrate contents into proper locations
   - If correctly placed: ensure up-to-date, correct, complete, and appropriately detailed
4. **Update Documentation**: 
   - Update README.md with any API changes
   - Update Logs/CHANGELOG.md with session changes
5. **Final Review**: 
   - Verify performance report completeness
   - Validate all JSON sections populated
   - Confirm user workflow validation completed

**🚨 END-TO-END SMOKE TEST PROTOCOL - MANDATORY**
Before marking any stage complete, validate with fresh PowerShell session:
```powershell
# Import module fresh
Remove-Module ModuleName -Force -ErrorAction SilentlyContinue
Import-Module .\ModuleName.psd1 -Force

# Test 3 most common user scenarios with real execution
# Example for CRUD module:
$result1 = New-Something -Name "SmokeTest1"
$result2 = Get-Something -Name "SmokeTest1" 
$result3 = Remove-Something -Name "SmokeTest1"

# Verify results are what user expects
Write-Host "Smoke test results: $result1, $result2, $result3"
```

**SMOKE TEST FAILURE PROTOCOL**:
If any smoke test fails:
1. **All previous tests are suspect** - investigate test vs reality gap
2. **Do NOT assume user data problems** - assume module bug first
3. **Debug with simplest possible inputs** - no complex scenarios
4. **Fix the actual bug** - don't create workarounds or diagnostics

**"TESTS PASS BUT USER REPORTS FAILURE" PROTOCOL**:
When tests pass but user reports module doesn't work:
1. **IMMEDIATELY question test coverage** - what did tests miss?
2. **Run exact user command** in fresh session
3. **Compare test execution vs user execution** - find the difference
4. **Assume test inadequacy first** - not user environment issues
5. **Add missing test coverage** - prevent this gap recurring

## STAGE 4: ALGORITHMIC DECISION FRAMEWORK

### Parameter Set Design Algorithm
```
Count distinct parameter combinations:
├─ 1-2 combinations → Single parameter set
├─ 3-4 combinations, related purpose → Multiple parameter sets
└─ >4 combinations OR unrelated → Split into separate functions

Example: Get-User -Id 123 vs Get-User -Name "John" = parameter sets
Example: Get-User vs Search-User = separate functions
```

### Function Complexity Decision Tree
```
Function lines > 50?
├─ YES: Count distinct responsibilities
│   ├─ 1 responsibility → Extract helper functions
│   └─ >1 responsibility → Split into separate functions
└─ NO: Count similar functions <20 lines
    └─ >2 similar functions → Combine with parameters
```

### Error Handling Decision Matrix
```powershell
# Error severity algorithm
switch ($errorType) {
    'DataLoss' { throw "Critical error: $message" }
    'SecurityViolation' { throw "Security error: $message" }
    'ExpectedFailure' { Write-Warning $message; return $null }
    'UserError' { Write-Error $message; return $null }
    'SystemIssue' { Write-Error $message; throw }
}
```

### Mock vs Real Testing Decision Tree
```
External dependency?
├─ Network call → Mock with realistic responses
├─ File system → Use TestDrive (real but isolated)
├─ Database → Mock for unit tests, real for integration
├─ Your module logic → Real testing, no mocks
└─ PowerShell cmdlets → Trust PowerShell, don't test
```

## STAGE 5: RECOVERY & ESCALATION STRATEGIES

### Degraded Success Modes
When full refinement isn't possible, define minimum acceptable outcomes:

**Minimum Viable Module:**
- Imports without errors ✅
- Core functions work with valid input ✅
- Basic error handling exists ✅
- No security vulnerabilities ✅

**Acceptable Compromises:**
- Missing parameter validation (if documented)
- Incomplete test coverage (if gaps identified)
- Style inconsistencies (if functionality solid)

### Escalation Decision Points
```
Time spent > 2x estimated effort?
├─ YES: Document problem in performance-report.json → STOP and ask
└─ NO: Continue

Test failures > 50% of total tests?  
├─ YES: Question test strategy → STOP and ask
└─ NO: Fix tests systematically

Critical errors found after "completion"?
├─ YES: Analyze testing blind spots → STOP and ask
└─ NO: Minor fixes acceptable
```

### Salvage Operations
When refinement goes wrong:
1. **Preserve original code** in backup branch/folder
2. **Document what worked** vs what failed
3. **Extract successful patterns** for reuse
4. **Identify root cause** of failure
5. **Update performance-report.json** with lessons learned

## CRITICAL ANTI-PATTERNS - IMMEDIATE FIXES

**These indicate fundamental misunderstanding:**
1. **Wrapper functions** → DELETE immediately
2. `Write-Host` for output → Change to `Write-Output`
3. `$global:` variables → Use `$script:` or `$module:`
4. Functions >50 lines → SPLIT now
5. Success strings/`$true` returns → Return objects
6. `-ErrorAction SilentlyContinue` → Handle explicitly
7. Hardcoded paths → Use environment variables
8. Manual string parsing → Use cmdlets
9. **Operations without timeout protection** → Add timeout wrappers
10. **Claims without proof** → Validate before declaring success

## POWERSHELL GOTCHAS - AUTOMATIC FIXES

**Pipeline Behavior:**
```powershell
# ❌ Wrong: Missing process block
function Get-Data { param([Parameter(ValueFromPipeline)]$Name) return $Name.ToUpper() }

# ✅ Right: Process block for pipeline
function Get-Data { 
    param([Parameter(ValueFromPipeline)]$Name) 
    process { return $Name.ToUpper() }
}
```

**Cross-Platform Paths:**
```powershell
# ❌ Wrong: Windows-specific
$configPath = "$env:USERPROFILE\AppData\config.json"

# ✅ Right: Cross-platform  
$configPath = Join-Path $env:HOME '.config/app/config.json'
```

**Variable Scoping:**
```powershell
# ❌ Wrong: Global pollution
$global:connectionCache = @{}

# ✅ Right: Module scope
$script:connectionCache = @{}
```

**Interactive Operations:**
```powershell
# ❌ Wrong: Can hang in automation
$input = Read-Host "Enter value"
Update-Module $moduleName

# ✅ Right: Non-interactive with timeout protection
$input = if ($Interactive) { Read-Host "Enter value" } else { "default-value" }
$job = Start-Job { Update-Module $moduleName -Force }
Wait-Job $job -Timeout 30 | Out-Null
```

## PERFORMANCE_REPORT.JSON TEMPLATE - MACHINE-READABLE FORMAT

Store in Logs directory as `Logs/performance-{ModuleName}.json`:

```json
{
  "session_metadata": {
    "module_name": "ModuleName",
    "module_version": "1.2.3",
    "session_start": "2024-XX-XX_XX:XX:XX",
    "session_end": "2024-XX-XX_XX:XX:XX", 
    "total_duration_minutes": 0,
    "final_status": "success|partial_success|failure|escalated",
    "model_used": "claude-3-5-sonnet|gpt-4|etc",
    "model_changes": [{"timestamp": "2024-XX-XX_XX:XX", "from": "gpt-4", "to": "claude", "reason": "user_switched"}]
  },

  "user_workflow_validation": {
    "original_broken_command": "specific_user_workflow_that_triggered_refinement",
    "workflow_tested": false,
    "test_result": null,
    "validation_method": "direct_execution|pipeline_test|integration_scenario",
    "original_problem_resolved": false
  },

  "timeout_protection_compliance": {
    "tests_requiring_protection": 5,
    "tests_with_protection": 0,
    "compliance_rate": 0.0,
    "hanging_incidents": 1,
    "protection_methods_used": ["start_job", "mock_interactive"]
  },

  "instruction_usage_analysis": {
    "sections_never_referenced": ["stage_4_parameter_sets", "advanced_error_patterns"],
    "sections_referenced_but_low_value": [
      {"section": "cross_platform_validation", "citations": 2, "value_score": 0.1}
    ],
    "most_valuable_sections": [
      {"section": "assumption_validation", "citations": 5, "decisions_influenced": 3}
    ],
    "time_per_instruction_section": {
      "timeout_protection": 15,
      "safe_design_patterns": 8
    }
  },

  "decision_effectiveness": {
    "decisions_by_instruction_section": {
      "timeout_protection": {"total": 3, "successful": 2, "user_corrections": 1, "effectiveness": 0.67},
      "assumption_validation": {"total": 5, "successful": 4, "user_corrections": 1, "effectiveness": 0.8}
    }
  },

  "compliance_effectiveness": {
    "instruction_compliance_vs_outcomes": [
      {"instruction": "assumption_validation_followed", "followed": true, "false_completion_claims": 0},
      {"instruction": "verification_followed", "followed": false, "false_completion_claims": 2},
      {"instruction": "timeout_protection_used", "followed": false, "hanging_incidents": 1}
    ]
  },

  "preventable_corrections": [
    {
      "user_correction": "function_not_exported",
      "instruction_that_should_prevent": "export_validation_checkpoint", 
      "was_instruction_followed": false,
      "prevention_effectiveness": "would_have_prevented"
    }
  ],

  "breaking_changes_tracking": {
    "changes_applied": [
      {
        "timestamp": "2024-XX-XX_XX:XX:XX",
        "change_description": "added_parameter_validation_to_Get_User",
        "function_modified": "Get-User",
        "functions_broken": ["Set-User", "Update-User"],
        "break_reason": "parameter_signature_mismatch",
        "fix_attempt": 1
      }
    ],
    "oscillation_patterns": [
      {
        "functions_involved": ["Get-User", "Set-User"],
        "change_cycle_count": 3,
        "pattern_detected": "parameter_compatibility_loop",
        "resolution_needed": "standardize_parameter_design"
      }
    ],
    "total_breaking_changes": 0,
    "functions_broken_multiple_times": []
  },

```json
{
  "session_metadata": {
    "module_name": "ModuleName",
    "session_start": "2024-XX-XX_XX:XX:XX",
    "session_end": "2024-XX-XX_XX:XX:XX", 
    "total_duration_minutes": 0,
    "final_status": "success|partial_success|failure|escalated",
    "model_used": "claude-3-5-sonnet|gpt-4|etc",
    "model_changes": [{"timestamp": "2024-XX-XX_XX:XX", "from": "gpt-4", "to": "claude", "reason": "user_switched"}]
  },
  
  "module_analysis": {
    "archetype": "CRUD|API|FileProcessing|LegacyConversion|Utility",
    "archetype_confidence": 0.8,
    "function_count": 12,
    "avg_complexity": "low|medium|high",
    "critical_issues": 3,
    "major_issues": 7,
    "minor_issues": 15,
    "archetype_classification_accuracy": "correct|incorrect|partially_correct"
  },

  "assumption_tracking": {
    "documented_assumptions": [
      {
        "assumption": "private_functions_available_in_public_scope",
        "test_method": "direct_function_call_test",
        "validation_result": true,
        "impact_if_wrong": "function_not_found_errors"
      }
    ],
    "untested_assumptions": ["list_assumptions_not_validated"],
    "assumption_validation_failures": [
      {
        "failed_assumption": "dot_sourcing_works_in_module_context",
        "expected_behavior": "private_functions_accessible",
        "actual_behavior": "scope_isolation_prevents_access",
        "impact": "critical_function_failures"
      }
    ],
    "mental_model_corrections": [
      {
        "original_understanding": "module_automatically_makes_private_functions_available",
        "corrected_understanding": "explicit_export_or_script_scope_required",
        "learning_source": "user_correction"
      }
    ]
  },

  "instruction_adherence_analysis": {
    "stage_1_assessment": {"followed": true, "effectiveness": 0.9, "time_budget_met": true},
    "stage_2_critical_fixes": {"followed": true, "effectiveness": 0.7, "time_budget_met": false},
    "stage_3_testing": {"followed": false, "reason": "skipped_test_planning_phase", "effectiveness": 0.4},
    "assumption_validation_protocol": {"adherence_rate": 0.8, "assumptions_documented": 5, "assumptions_tested": 4},
    "timeout_protection_usage": {"adherence_rate": 0.9, "tests_with_protection": 8, "hanging_incidents": 0},
    "decision_justification_protocol": {"adherence_rate": 0.8, "quality_score": 0.6},
    "instruction_citation_requirement": {"adherence_rate": 0.9, "accuracy": 0.8},
    "failure_prediction_protocol": {"adherence_rate": 0.7, "prediction_accuracy": 0.6}
  },

  "decision_analysis": [
    {
      "decision_id": "001",
      "timestamp": "2024-XX-XX_XX:XX:XX",
      "stage": "stage_2_critical_fixes",
      "decision_type": "function_modification|test_creation|architecture_change|error_handling",
      "what_deciding": "whether_to_split_complex_function",
      "assumptions_documented": [
        {"assumption": "function_splitting_improves_testability", "validated": true}
      ],
      "context_state": {
        "current_function": "Get-UserData", 
        "function_lines": 65,
        "responsibilities_count": 3,
        "previous_decisions_influencing": ["archetype_classification", "crud_pattern_selection"]
      },
      "options_considered": ["split_into_3_functions", "extract_2_helpers", "leave_as_is"],
      "instruction_section_cited": "stage_4_complexity_decision_tree",
      "choice_made": "split_into_3_functions",
      "reasoning": "Function has 3 distinct responsibilities that map to different CRUD operations",
      "predicted_risks": ["breaking_existing_calls", "parameter_complexity", "testing_overhead"],
      "predicted_failure_modes": [
        {"failure": "import_errors", "detection": "import_module_test"},
        {"failure": "parameter_binding_issues", "detection": "pipeline_validation"},
        {"failure": "return_type_inconsistency", "detection": "object_type_validation"}
      ],
      "time_spent_minutes": 12,
      "actual_outcome": "success|failure|partial_success",
      "actual_failures_encountered": [],
      "prediction_accuracy": 0.8,
      "would_make_same_decision": true,
      "instruction_effectiveness": 0.9
    }
  ],

  "failure_chain_analysis": [
    {
      "failure_id": "001",
      "timestamp": "2024-XX-XX_XX:XX:XX",
      "failure_description": "Function Get-User created but doesn't work when called",
      "impact_severity": "critical|major|minor",
      "detection_method": "user_correction|self_validation|test_failure",
      "failure_chain": [
        {
          "decision_point": "parameter_design_choice",
          "decision_made": "used_generic_object_type",
          "assumption_behind_decision": "object_type_provides_flexibility",
          "assumption_validation_attempted": false,
          "instruction_that_should_have_prevented": "stage_2_parameter_standards",
          "why_instruction_not_followed": "misread_as_suggestion_not_requirement",
          "missing_information": "specific_type_validation_examples",
          "environmental_factors": "complex_legacy_code_patterns"
        }
      ],
      "root_cause_category": "untested_assumption|instruction_misinterpretation|missing_validation|complexity_underestimation|environmental_factor",
      "prevention_strategy": "strengthen_assumption_validation|add_validation_checkpoint|provide_more_examples"
    }
  ],

  "user_correction_analysis": [
    {
      "correction_id": "001",
      "timestamp": "2024-XX-XX_XX:XX:XX",
      "what_agent_did": "Created parameter as [object]$InputData",
      "what_user_corrected": "Changed to [PSCustomObject]$UserData with validation",
      "correction_severity": "critical|major|minor",
      "agent_error_category": "ignored_instruction|misunderstood_instruction|poor_judgment|oversight|untested_assumption",
      "assumption_behind_error": "object_type_sufficient_for_parameter",
      "assumption_validation_gap": "did_not_test_parameter_binding_behavior",
      "instruction_section_relevant": "stage_2_parameter_standards", 
      "instruction_clarity": "clear|ambiguous|missing",
      "agent_acknowledgment": "understood|defensive|confused",
      "repeat_likelihood": "high|medium|low",
      "prevention_strategy": "add_emphasis|add_examples|add_validation_checkpoint|restructure_instruction"
    }
  ],

  "timeout_protection_analysis": {
    "tests_with_timeout_protection": 8,
    "tests_without_protection": 2,
    "hanging_incidents_prevented": 3,
    "timeout_methods_used": ["start_job", "mock_interactive", "runspace"],
    "most_effective_method": "start_job_with_30s_timeout",
    "operations_requiring_protection": ["subprocess_calls", "module_operations", "file_operations"]
  },

  "agent_oversight_analysis": [
    {
      "oversight_id": "001", 
      "timestamp": "2024-XX-XX_XX:XX:XX",
      "what_agent_missed": "Function had hardcoded Windows path in validation",
      "how_user_found_it": "Tested on Linux system",
      "impact_if_undetected": "Module unusable on non-Windows systems",
      "why_agent_missed_it": "no_cross_platform_validation_checkpoint",
      "assumption_behind_oversight": "paths_work_universally",
      "assumption_validation_gap": "did_not_test_on_different_platforms",
      "instruction_gap": "missing_cross_platform_validation_requirement",
      "attention_failure": true,
      "complexity_factor": false,
      "prevention_strategy": "add_cross_platform_checkpoint|add_validation_template"
    }
  ],

  "time_value_analysis": {
    "total_time_minutes": 120,
    "time_breakdown": {
      "analysis_planning": 15,
      "critical_fixes": 35, 
      "testing_creation": 25,
      "testing_debugging": 20,
      "documentation": 10,
      "rework_corrections": 15
    },
    "value_breakdown": {
      "high_value_activities": ["critical_fixes", "high_value_testing"],
      "medium_value_activities": ["analysis_planning", "documentation"],
      "low_value_activities": ["testing_debugging", "rework_corrections"]
    },
    "efficiency_metrics": {
      "value_delivered_per_minute": 0.7,
      "rework_percentage": 0.25,
      "testing_overhead_ratio": 0.8,
      "decision_speed": "fast|medium|slow"
    }
  },

  "instruction_effectiveness_analysis": {
    "most_effective_sections": [
      {
        "section": "stage_2_crud_template",
        "effectiveness_score": 0.9,
        "why_effective": "clear_concrete_example_with_validation"
      }
    ],
    "least_effective_sections": [
      {
        "section": "stage_3_mock_decision_tree", 
        "effectiveness_score": 0.3,
        "why_ineffective": "too_abstract_needed_specific_examples",
        "improvement_needed": "add_concrete_before_after_examples"
      }
    ],
    "ignored_instructions": [
      {
        "section": "failure_prediction_protocol",
        "ignore_rate": 0.6,
        "reason": "too_time_consuming_in_practice",
        "suggestion": "simplify_to_3_bullet_points"
      }
    ],
    "misunderstood_instructions": [
      {
        "section": "parameter_standards",
        "misunderstanding": "interpreted_as_suggestions_not_requirements", 
        "frequency": 0.4,
        "suggestion": "add_emphasis_markers_and_examples"
      }
    ]
  },

  "testing_strategy_analysis": {
    "test_planning_effectiveness": 0.7,
    "high_value_test_creation_rate": 0.6,
    "test_maintenance_overhead": 0.3,
    "real_issue_detection_rate": 0.8,
    "false_positive_rate": 0.2,
    "timeout_protection_effectiveness": 0.95,
    "testing_blind_spots": ["cross_platform_compatibility", "error_message_accuracy"],
    "over_tested_areas": ["parameter_validation", "mock_call_verification"],
    "under_tested_areas": ["pipeline_behavior", "integration_scenarios"]
  },

  "pattern_recognition": {
    "recurring_error_patterns": [
      {
        "pattern": "creating_wrapper_functions",
        "frequency": 3,
        "instruction_sections": ["anti_patterns", "helper_function_rules"],
        "root_cause": "misunderstanding_of_value_add_requirement"
      }
    ],
    "recurring_oversight_patterns": [
      {
        "pattern": "missing_cross_platform_considerations", 
        "frequency": 2,
        "sections_that_should_prevent": ["powershell_gotchas"],
        "root_cause": "insufficient_emphasis_in_instructions"
      }
    ],
    "adaptation_indicators": {
      "learns_from_corrections": true,
      "repeats_same_mistakes": false,
      "applies_patterns_consistently": "sometimes",
      "resistance_to_guidance": "low"
    }
  },

  "prompt_optimization_recommendations": {
    "critical_additions": [
      {
        "recommendation": "add_cross_platform_validation_checkpoint",
        "priority": "high",
        "evidence": "missed_platform_issues_3_times",
        "implementation": "add_mandatory_validation_after_each_function"
      }
    ],
    "instruction_clarifications": [
      {
        "section": "parameter_standards",
        "issue": "interpreted_as_optional",
        "fix": "add_emphasis_and_mandatory_language"
      }
    ],
    "content_reorganization": [
      {
        "recommendation": "move_anti_patterns_to_top",
        "reason": "frequently_violated_late_in_process"
      }
    ],
    "content_removal": [
      {
        "section": "advanced_parameter_sets_guidance",
        "reason": "never_used_adds_cognitive_load"
      }
    ]
  }
}
```

## FINAL VALIDATION SEQUENCE

**BLOCKED: Cannot declare success without user workflow validation**

```powershell
# 1. Import Test
Import-Module . -Force -ErrorAction Stop

# 2. Static Analysis  
Invoke-ScriptAnalyzer . -Recurse -Severity Warning,Error

# 3. Individual Function Validation
Get-Command -Module ModuleName | ForEach-Object {
    & $_.Name -ErrorAction Stop  # Basic execution test
}

# 4. Test Execution with Timeout Protection
$job = Start-Job { Invoke-Pester .\Tests\ -PassThru }
if (Wait-Job $job -Timeout 300) {
    $testResults = Receive-Job $job
    Remove-Job $job
} else {
    Remove-Job $job -Force
    throw "Test execution timed out - investigate hanging tests"
}

# 5. Help Validation  
Get-Command -Module ModuleName | ForEach-Object {
    Get-Help $_.Name -Examples | Out-Null  # Verify help works
}

# 6. MANDATORY: User Workflow Validation
# Test exact user command/scenario that triggered refinement
# Verify original problem resolved
# Document workflow test results in performance report
```

## FINAL RETROSPECTIVE ANALYSIS

Before marking session complete:
1. **Review conversation** for repeated mistakes/corrections
2. **Identify instruction gaps** that caused problems
3. **Verify performance-report.json completeness** - all sections populated
4. **Note what worked well** vs poorly
5. **Recommend instruction improvements** for next version
6. **Document assumption validation effectiveness**
7. **Assess timeout protection success rate**

**CHANGELOG Format** (append to Logs/CHANGELOG.md):
```markdown
## [Date] - Module v{Version}
### Fixed
- Issue description and resolution method
### Changed  
- Function modifications and reasoning
### Added
- New functionality or improvements
### Performance
- Time: XXmin, Issues: X, User corrections: X
```

**CONTINUOUS PERFORMANCE LOGGING REQUIREMENT**: 
Update performance-report.json in machine-readable JSON format after:
- Every decision made (with reasoning, predictions, and assumptions)
- Every function modified (with validation results)  
- Every test created (with effectiveness analysis and timeout protection)
- Every user correction received (with root cause analysis)
- Every assumption validation attempt (with results)
- Every issue discovered (with failure chain reconstruction)

**Validation Rule**: Every failure must be resolved by:
1. **Fix the code** (real issue found)
2. **Fix the test** (test setup wrong)
3. **Remove the test** (adds no value) + document in failure_chain_analysis

**Success Criteria**: Module imports ✅ + Core functions work ✅ + Tests pass ✅ + Help works ✅ + JSON report complete ✅ + Assumptions validated ✅ + No hanging issues ✅

## QUICK REFERENCE - MANDATORY ACTIONS

**At Session Start**: 
- Extract module info: `$manifest = Import-PowerShellDataFile .\*.psd1`
- Create performance file: `Logs/performance-{$manifest.RootModule}.json`
- **Document Initial Problem**: Record the specific user workflow that's broken
- Log module_name and module_version in session_metadata
- Initialize all JSON sections including breaking_changes_tracking

**Before Every Decision**: Document assumptions, state [What I'm deciding] [Options considered] [Instruction cited] [Reasoning] [Predicted risks] + Log to decision_analysis[]

**Before Every Implementation**: Validate key assumptions with minimal tests, explain expected PowerShell behavior

**After Every Function Change**: 
- Validate [Imports clean] [Basic execution] [Individual function works] [Follows template] 
- Test assumptions about PowerShell behavior
- **Track breaking changes**: If change breaks other functions, log to breaking_changes_tracking
- Check for oscillation patterns (fixing A breaks B, fixing B breaks A)
- Update code_change_metrics and execution_events

**After Every Test Creation**: 
- Add timeout protection for potentially hanging operations
- Validate [Runs without error] [Tests real behavior] [Execution <30s] 
- Log test_type and timeout_protection_used
- Update testing_strategy_analysis

**After Every User Correction**: 
- Log [What I did wrong] [Root cause] [Untested assumption] [Prevention strategy]
- Update user_correction_analysis[] and assumption_tracking
- Record timestamp in session_timeline

**When Operations Take >Expected Time**: 
- Report progress at 30s, 2min marks
- Terminate and investigate at 5min
- Log timeout incidents

**At Session End**: 
- Complete final retrospective analysis
- Verify all JSON sections populated
- Calculate final metrics
- Document lessons learned
- **Create/update Logs/CHANGELOG.md** with session changes
- Log session_end timestamp

**JSON Logging Sections to Update Continuously**:
- `assumption_tracking` - All assumptions documented and validation attempts
- `decision_analysis[]` - Every major choice with assumption documentation
- `failure_chain_analysis[]` - When things don't work with assumption gaps
- `user_correction_analysis[]` - When user corrects with assumption analysis
- `timeout_protection_analysis` - Effectiveness of hanging prevention
- `instruction_adherence_analysis` - How well following new protocols