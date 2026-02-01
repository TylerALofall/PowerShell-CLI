# Example: Complete Workflow for Claim Management and Evidence Collection
# This script demonstrates the full workflow using the PowerShell modules

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import modules
$moduleBasePath = Split-Path -Parent $PSScriptRoot
Import-Module "$moduleBasePath\powershell-modules\DocumentProcessing.psm1" -Force
Import-Module "$moduleBasePath\powershell-modules\EvidenceCollection.psm1" -Force

Write-Host "=== PowerShell MCP Toolbox - Example Workflow ===" -ForegroundColor Cyan
Write-Host ""

# Configuration
$claimId = "CLAIM-2024-EXAMPLE-001"
$evidenceBasePath = Join-Path -Path $PSScriptRoot -ChildPath "evidence-example"
$chainPath = Join-Path -Path $evidenceBasePath -ChildPath "chains"
$documentsPath = Join-Path -Path $evidenceBasePath -ChildPath "documents"
$reportsPath = Join-Path -Path $evidenceBasePath -ChildPath "reports"

# Create directories if they don't exist
@($evidenceBasePath, $chainPath, $documentsPath, $reportsPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

# Step 1: Create a new evidence chain
Write-Host "Step 1: Creating evidence chain for claim $claimId..." -ForegroundColor Green
try {
    $chain = New-EvidenceChain `
        -ClaimId $claimId `
        -ClaimType "Contract" `
        -Description "Example breach of contract claim for software development services" `
        -OutputPath $chainPath
    
    Write-Host "✓ Evidence chain created successfully" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to create evidence chain: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Create a sample document for demonstration
Write-Host "Step 2: Creating sample document..." -ForegroundColor Green
$sampleDocPath = Join-Path -Path $documentsPath -ChildPath "sample-contract.txt"
$sampleContent = @"
SAMPLE CONTRACT DOCUMENT
========================

This is a sample contract document for demonstration purposes.

Contract Date: 2024-01-15
Parties: Company A and Developer B
Terms: Software development services for web application

This document is for testing the PowerShell MCP Toolbox evidence collection system.
"@

try {
    $sampleContent | Out-File -FilePath $sampleDocPath -Encoding utf8
    Write-Host "✓ Sample document created at: $sampleDocPath" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to create sample document: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Process the document and extract metadata
Write-Host "Step 3: Processing document and extracting metadata..." -ForegroundColor Green
try {
    $metadata = Get-DocumentMetadata -FilePath $sampleDocPath
    
    Write-Host "Document Metadata:" -ForegroundColor Yellow
    Write-Host "  Name: $($metadata.FileName)"
    Write-Host "  Size: $($metadata.SizeBytes) bytes"
    Write-Host "  Created: $($metadata.CreatedDate)"
    Write-Host "  SHA256: $($metadata.Hash_SHA256)"
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to extract metadata: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Validate document integrity
Write-Host "Step 4: Validating document integrity..." -ForegroundColor Green
try {
    $validation = Test-DocumentIntegrity -FilePath $sampleDocPath
    
    if ($validation.Exists -and $validation.Readable -and $validation.NotEmpty) {
        Write-Host "✓ Document validation passed" -ForegroundColor Green
        Write-Host "  Exists: $($validation.Exists)"
        Write-Host "  Readable: $($validation.Readable)"
        Write-Host "  Not Empty: $($validation.NotEmpty)"
    }
    else {
        Write-Host "✗ Document validation failed" -ForegroundColor Red
        $validation.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to validate document: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Add document to evidence chain
Write-Host "Step 5: Adding document to evidence chain..." -ForegroundColor Green
try {
    $chainFilePath = Join-Path -Path $chainPath -ChildPath "$claimId.json"
    
    $evidenceItem = Add-EvidenceItem `
        -ClaimId $claimId `
        -ChainPath $chainFilePath `
        -EvidenceType "Document" `
        -SourcePath $sampleDocPath `
        -Description "Sample contract document" `
        -Tags @("contract", "sample", "legal")
    
    Write-Host "✓ Evidence item added: $($evidenceItem.EvidenceId)" -ForegroundColor Green
    Write-Host "  Type: $($evidenceItem.EvidenceType)"
    Write-Host "  Verified: $($evidenceItem.Verified)"
    Write-Host "  Hash: $($evidenceItem.IntegrityHash)"
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to add evidence: $_" -ForegroundColor Red
    exit 1
}

# Step 6: Add another piece of evidence (metadata file)
Write-Host "Step 6: Adding metadata as additional evidence..." -ForegroundColor Green
try {
    $metadataPath = Join-Path -Path $documentsPath -ChildPath "contract-metadata.json"
    $metadata | ConvertTo-Json -Depth 5 | Out-File -FilePath $metadataPath -Encoding utf8
    
    $metadataEvidence = Add-EvidenceItem `
        -ClaimId $claimId `
        -ChainPath $chainFilePath `
        -EvidenceType "Digital" `
        -SourcePath $metadataPath `
        -Description "Contract metadata and hash information" `
        -Tags @("metadata", "hash", "verification")
    
    Write-Host "✓ Metadata evidence added: $($metadataEvidence.EvidenceId)" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to add metadata evidence: $_" -ForegroundColor Red
    exit 1
}

# Step 7: Validate the evidence chain
Write-Host "Step 7: Validating evidence chain integrity..." -ForegroundColor Green
try {
    $chainValidation = Test-EvidenceChainIntegrity -ChainPath $chainFilePath -VerifyFiles $true
    
    if ($chainValidation.ChainValid) {
        Write-Host "✓ Evidence chain validation PASSED" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Evidence chain validation FAILED" -ForegroundColor Red
    }
    
    Write-Host "  Total Evidence Items: $($chainValidation.EvidenceCount)"
    Write-Host "  Verified: $($chainValidation.VerifiedCount)"
    Write-Host "  Failed: $($chainValidation.FailedCount)"
    
    if ($chainValidation.Issues.Count -gt 0) {
        Write-Host "  Issues:" -ForegroundColor Yellow
        $chainValidation.Issues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    }
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to validate chain: $_" -ForegroundColor Red
    exit 1
}

# Step 8: Export evidence chain reports
Write-Host "Step 8: Generating evidence chain reports..." -ForegroundColor Green
try {
    # Text report
    $textReportPath = Join-Path -Path $reportsPath -ChildPath "$claimId-report.txt"
    Export-EvidenceChainReport -ChainPath $chainFilePath -OutputPath $textReportPath -Format "Text"
    Write-Host "✓ Text report generated: $textReportPath" -ForegroundColor Green
    
    # JSON report
    $jsonReportPath = Join-Path -Path $reportsPath -ChildPath "$claimId-report.json"
    Export-EvidenceChainReport -ChainPath $chainFilePath -OutputPath $jsonReportPath -Format "JSON"
    Write-Host "✓ JSON report generated: $jsonReportPath" -ForegroundColor Green
    
    # HTML report
    $htmlReportPath = Join-Path -Path $reportsPath -ChildPath "$claimId-report.html"
    Export-EvidenceChainReport -ChainPath $chainFilePath -OutputPath $htmlReportPath -Format "HTML"
    Write-Host "✓ HTML report generated: $htmlReportPath" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to generate reports: $_" -ForegroundColor Red
    exit 1
}

# Step 9: Display final summary
Write-Host "=== Workflow Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Claim ID: $claimId"
Write-Host "  Evidence Chain: $chainFilePath"
Write-Host "  Total Evidence Items: $($chainValidation.EvidenceCount)"
Write-Host "  Reports Generated: 3 (Text, JSON, HTML)"
Write-Host ""
Write-Host "All files are stored in: $evidenceBasePath" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review the HTML report at: $htmlReportPath"
Write-Host "  2. Use the MCP server to interact with this claim context"
Write-Host "  3. Add more evidence using the Add-EvidenceItem function"
Write-Host ""
Write-Host "✓ Example workflow completed successfully!" -ForegroundColor Green
