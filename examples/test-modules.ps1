#!/usr/bin/env pwsh

<#
.SYNOPSIS
Simple test script to verify PowerShell modules are working correctly

.DESCRIPTION
This script runs basic tests on the PowerShell modules to ensure they're functioning properly.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testsPassed = 0
$testsFailed = 0

function Test-Module {
    param(
        [string]$TestName,
        [scriptblock]$TestBlock
    )
    
    Write-Host "Running: $TestName" -ForegroundColor Cyan
    try {
        & $TestBlock
        Write-Host "  ✓ PASSED" -ForegroundColor Green
        $script:testsPassed++
    }
    catch {
        Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
        $script:testsFailed++
    }
    Write-Host ""
}

# Import modules
$moduleBasePath = Split-Path -Parent $PSScriptRoot
Import-Module "$moduleBasePath/powershell-modules/DocumentProcessing.psm1" -Force
Import-Module "$moduleBasePath/powershell-modules/EvidenceCollection.psm1" -Force

Write-Host "=== PowerShell Module Tests ===" -ForegroundColor Yellow
Write-Host ""

# Test 1: DocumentProcessing module loads
Test-Module "DocumentProcessing module loads" {
    $commands = Get-Command -Module DocumentProcessing
    if ($commands.Count -ne 4) {
        throw "Expected 4 commands, got $($commands.Count)"
    }
}

# Test 2: EvidenceCollection module loads
Test-Module "EvidenceCollection module loads" {
    $commands = Get-Command -Module EvidenceCollection
    if ($commands.Count -ne 5) {
        throw "Expected 5 commands, got $($commands.Count)"
    }
}

# Test 3: Create test file and extract metadata
Test-Module "Get-DocumentMetadata works" {
    $testFile = "/tmp/test-doc-$([guid]::NewGuid()).txt"
    "Test content" | Out-File -FilePath $testFile
    
    $metadata = Get-DocumentMetadata -FilePath $testFile
    
    if (-not $metadata.FileName) {
        throw "Metadata missing FileName"
    }
    if ($metadata.SizeBytes -eq 0) {
        throw "File size should not be 0"
    }
    if (-not $metadata.Hash_SHA256) {
        throw "Missing SHA256 hash"
    }
    
    Remove-Item -Path $testFile -Force
}

# Test 4: Document integrity validation
Test-Module "Test-DocumentIntegrity works" {
    $testFile = "/tmp/test-doc-$([guid]::NewGuid()).txt"
    "Test content for integrity" | Out-File -FilePath $testFile
    
    $validation = Test-DocumentIntegrity -FilePath $testFile
    
    if (-not $validation.Exists) {
        throw "File should exist"
    }
    if (-not $validation.Readable) {
        throw "File should be readable"
    }
    if (-not $validation.NotEmpty) {
        throw "File should not be empty"
    }
    
    Remove-Item -Path $testFile -Force
}

# Test 5: Create evidence chain
Test-Module "New-EvidenceChain works" {
    $testChainPath = "/tmp/test-chains"
    $testClaimId = "TEST-$([guid]::NewGuid())"
    
    $chain = New-EvidenceChain `
        -ClaimId $testClaimId `
        -ClaimType "Contract" `
        -Description "Test claim" `
        -OutputPath $testChainPath
    
    if ($chain.ClaimId -ne $testClaimId) {
        throw "Claim ID mismatch"
    }
    if ($chain.EvidenceItems.Count -ne 0) {
        throw "New chain should have no evidence items"
    }
    
    Remove-Item -Path "$testChainPath/$testClaimId.json" -Force
}

# Test 6: Add evidence to chain
Test-Module "Add-EvidenceItem works" {
    $testChainPath = "/tmp/test-chains"
    $testClaimId = "TEST-$([guid]::NewGuid())"
    $testFile = "/tmp/test-evidence-$([guid]::NewGuid()).txt"
    
    "Evidence content" | Out-File -FilePath $testFile
    
    $null = New-EvidenceChain `
        -ClaimId $testClaimId `
        -ClaimType "Contract" `
        -Description "Test claim" `
        -OutputPath $testChainPath
    
    $evidence = Add-EvidenceItem `
        -ClaimId $testClaimId `
        -ChainPath "$testChainPath/$testClaimId.json" `
        -EvidenceType "Document" `
        -SourcePath $testFile `
        -Description "Test evidence"
    
    if (-not $evidence.EvidenceId) {
        throw "Evidence should have an ID"
    }
    if (-not $evidence.Verified) {
        throw "Evidence should be verified"
    }
    if (-not $evidence.IntegrityHash) {
        throw "Evidence should have integrity hash"
    }
    
    Remove-Item -Path $testFile -Force
    Remove-Item -Path "$testChainPath/$testClaimId.json" -Force
}

# Test 7: Validate evidence chain
Test-Module "Test-EvidenceChainIntegrity works" {
    $testChainPath = "/tmp/test-chains"
    $testClaimId = "TEST-$([guid]::NewGuid())"
    $testFile = "/tmp/test-evidence-$([guid]::NewGuid()).txt"
    
    "Evidence content" | Out-File -FilePath $testFile
    
    $null = New-EvidenceChain `
        -ClaimId $testClaimId `
        -ClaimType "Contract" `
        -Description "Test claim" `
        -OutputPath $testChainPath
    
    $null = Add-EvidenceItem `
        -ClaimId $testClaimId `
        -ChainPath "$testChainPath/$testClaimId.json" `
        -EvidenceType "Document" `
        -SourcePath $testFile `
        -Description "Test evidence"
    
    $validation = Test-EvidenceChainIntegrity -ChainPath "$testChainPath/$testClaimId.json"
    
    if (-not $validation.ChainValid) {
        throw "Chain should be valid"
    }
    if ($validation.VerifiedCount -ne 1) {
        throw "Should have 1 verified item"
    }
    
    Remove-Item -Path $testFile -Force
    Remove-Item -Path "$testChainPath/$testClaimId.json" -Force
}

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Yellow
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed!" -ForegroundColor Red
    exit 1
}
