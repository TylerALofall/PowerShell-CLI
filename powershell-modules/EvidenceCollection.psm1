<#
.SYNOPSIS
Evidence Collection Module for Legal Claims Processing

.DESCRIPTION
Provides functions for collecting, validating, and organizing evidence
for legal claims. Ensures chain of custody and data integrity with strict validation.

.NOTES
Author: PowerShell MCP Toolbox
Version: 1.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-EvidenceChain {
    <#
    .SYNOPSIS
    Initialize a new evidence chain for a claim
    
    .PARAMETER ClaimId
    Unique identifier for the claim
    
    .PARAMETER ClaimType
    Type of claim (contract, tort, evidence, etc.)
    
    .PARAMETER Description
    Description of the claim
    
    .PARAMETER OutputPath
    Path to store evidence chain data
    
    .EXAMPLE
    New-EvidenceChain -ClaimId "CLAIM-2024-001" -ClaimType "Contract" -Description "Breach of contract claim" -OutputPath "C:\Evidence\Chains"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ClaimId,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Contract', 'Tort', 'Evidence', 'Criminal', 'Civil', 'Administrative', 'Other')]
        [string]$ClaimType,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    # Ensure output directory exists
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $chainPath = Join-Path -Path $OutputPath -ChildPath "$ClaimId.json"
    
    if (Test-Path -Path $chainPath) {
        Write-Warning "Evidence chain already exists for claim: $ClaimId"
        return Get-Content -Path $chainPath -Raw | ConvertFrom-Json
    }
    
    $evidenceChain = [PSCustomObject]@{
        ClaimId         = $ClaimId
        ClaimType       = $ClaimType
        Description     = $Description
        CreatedDate     = Get-Date
        LastUpdated     = Get-Date
        Status          = 'Active'
        EvidenceItems   = @()
        ChainIntegrity  = 'Valid'
        Custodian       = $env:USERNAME
        ComputerName    = $env:COMPUTERNAME
    }
    
    # Save to file
    $evidenceChain | ConvertTo-Json -Depth 10 | Out-File -FilePath $chainPath -Encoding utf8
    
    Write-Verbose "Evidence chain created: $chainPath"
    return $evidenceChain
}

function Add-EvidenceItem {
    <#
    .SYNOPSIS
    Add an evidence item to an existing evidence chain
    
    .PARAMETER ClaimId
    Claim identifier
    
    .PARAMETER ChainPath
    Path to evidence chain file
    
    .PARAMETER EvidenceType
    Type of evidence
    
    .PARAMETER SourcePath
    Path to the evidence file
    
    .PARAMETER Description
    Description of the evidence
    
    .PARAMETER Tags
    Optional tags for categorization
    
    .EXAMPLE
    Add-EvidenceItem -ClaimId "CLAIM-2024-001" -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json" -EvidenceType "Document" -SourcePath "C:\contract.pdf" -Description "Original contract"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClaimId,
        
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ChainPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Document', 'Digital', 'Physical', 'Testimony', 'Audio', 'Video', 'Image', 'Other')]
        [string]$EvidenceType,
        
        [Parameter(Mandatory = $false)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Tags
    )
    
    # Load existing chain
    $chainData = Get-Content -Path $ChainPath -Raw | ConvertFrom-Json
    
    if ($chainData.ClaimId -ne $ClaimId) {
        throw "Claim ID mismatch. Expected: $($chainData.ClaimId), Got: $ClaimId"
    }
    
    # Create evidence item
    $evidenceId = "EV-$ClaimId-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    $evidenceItem = [PSCustomObject]@{
        EvidenceId      = $evidenceId
        EvidenceType    = $EvidenceType
        Description     = $Description
        SourcePath      = $SourcePath
        Tags            = if ($Tags) { $Tags } else { @() }
        AddedDate       = Get-Date
        AddedBy         = $env:USERNAME
        Verified        = $false
        IntegrityHash   = $null
    }
    
    # Calculate hash if source file exists
    if ($SourcePath -and (Test-Path -Path $SourcePath)) {
        $evidenceItem.IntegrityHash = (Get-FileHash -Path $SourcePath -Algorithm SHA256).Hash
        $evidenceItem.Verified = $true
    }
    
    # Convert to ArrayList to ensure we can add items
    $evidenceList = [System.Collections.ArrayList]@($chainData.EvidenceItems)
    $null = $evidenceList.Add($evidenceItem)
    
    # Rebuild chain object
    $chain = [PSCustomObject]@{
        ClaimId         = $chainData.ClaimId
        ClaimType       = $chainData.ClaimType
        Description     = $chainData.Description
        CreatedDate     = $chainData.CreatedDate
        LastUpdated     = Get-Date
        Status          = $chainData.Status
        EvidenceItems   = $evidenceList.ToArray()
        ChainIntegrity  = $chainData.ChainIntegrity
        Custodian       = $chainData.Custodian
        ComputerName    = $chainData.ComputerName
    }
    
    # Save updated chain
    $chain | ConvertTo-Json -Depth 10 | Out-File -FilePath $ChainPath -Encoding utf8
    
    Write-Verbose "Evidence item added: $evidenceId"
    return $evidenceItem
}

function Test-EvidenceChainIntegrity {
    <#
    .SYNOPSIS
    Validate the integrity of an evidence chain
    
    .PARAMETER ChainPath
    Path to evidence chain file
    
    .PARAMETER VerifyFiles
    Whether to verify file hashes (default: true)
    
    .EXAMPLE
    Test-EvidenceChainIntegrity -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ChainPath,
        
        [Parameter(Mandatory = $false)]
        [bool]$VerifyFiles = $true
    )
    
    $chain = Get-Content -Path $ChainPath -Raw | ConvertFrom-Json
    
    $validationResult = [PSCustomObject]@{
        ClaimId             = $chain.ClaimId
        ChainValid          = $true
        EvidenceCount       = $chain.EvidenceItems.Count
        VerifiedCount       = 0
        FailedCount         = 0
        MissingFiles        = @()
        HashMismatches      = @()
        ValidationDate      = Get-Date
        Issues              = @()
    }
    
    if ($chain.EvidenceItems.Count -eq 0) {
        $validationResult.Issues += "No evidence items in chain"
        $validationResult.ChainValid = $false
    }
    
    foreach ($item in $chain.EvidenceItems) {
        if (-not $item.SourcePath) {
            continue
        }
        
        # Check file exists
        if (-not (Test-Path -Path $item.SourcePath)) {
            $validationResult.MissingFiles += $item.SourcePath
            $validationResult.FailedCount++
            $validationResult.ChainValid = $false
            continue
        }
        
        # Verify hash if requested
        if ($VerifyFiles -and $item.IntegrityHash) {
            $currentHash = (Get-FileHash -Path $item.SourcePath -Algorithm SHA256).Hash
            if ($currentHash -ne $item.IntegrityHash) {
                $validationResult.HashMismatches += [PSCustomObject]@{
                    EvidenceId   = $item.EvidenceId
                    SourcePath   = $item.SourcePath
                    ExpectedHash = $item.IntegrityHash
                    ActualHash   = $currentHash
                }
                $validationResult.FailedCount++
                $validationResult.ChainValid = $false
            }
            else {
                $validationResult.VerifiedCount++
            }
        }
    }
    
    if ($validationResult.MissingFiles.Count -gt 0) {
        $validationResult.Issues += "Missing files: $($validationResult.MissingFiles.Count)"
    }
    
    if ($validationResult.HashMismatches.Count -gt 0) {
        $validationResult.Issues += "Hash mismatches: $($validationResult.HashMismatches.Count)"
    }
    
    return $validationResult
}

function Get-EvidenceChain {
    <#
    .SYNOPSIS
    Retrieve an evidence chain with full details
    
    .PARAMETER ChainPath
    Path to evidence chain file
    
    .EXAMPLE
    Get-EvidenceChain -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ChainPath
    )
    
    try {
        $chain = Get-Content -Path $ChainPath -Raw | ConvertFrom-Json
        return $chain
    }
    catch {
        Write-Error "Failed to load evidence chain: $_"
        throw
    }
}

function Export-EvidenceChainReport {
    <#
    .SYNOPSIS
    Export a formatted report of an evidence chain
    
    .PARAMETER ChainPath
    Path to evidence chain file
    
    .PARAMETER OutputPath
    Path to save the report
    
    .PARAMETER Format
    Report format (JSON, HTML, Text)
    
    .EXAMPLE
    Export-EvidenceChainReport -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json" -OutputPath "C:\Reports\report.html" -Format "HTML"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ChainPath,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'HTML', 'Text')]
        [string]$Format = 'Text'
    )
    
    $chain = Get-Content -Path $ChainPath -Raw | ConvertFrom-Json
    $validation = Test-EvidenceChainIntegrity -ChainPath $ChainPath
    
    switch ($Format) {
        'JSON' {
            $report = [PSCustomObject]@{
                Chain      = $chain
                Validation = $validation
                Generated  = Get-Date
            }
            $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding utf8
        }
        
        'HTML' {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Evidence Chain Report - $($chain.ClaimId)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #34495e; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #3498db; color: white; }
        .valid { color: green; font-weight: bold; }
        .invalid { color: red; font-weight: bold; }
        .metadata { background-color: #ecf0f1; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <h1>Evidence Chain Report</h1>
    <div class="metadata">
        <p><strong>Claim ID:</strong> $($chain.ClaimId)</p>
        <p><strong>Claim Type:</strong> $($chain.ClaimType)</p>
        <p><strong>Description:</strong> $($chain.Description)</p>
        <p><strong>Created:</strong> $($chain.CreatedDate)</p>
        <p><strong>Last Updated:</strong> $($chain.LastUpdated)</p>
        <p><strong>Status:</strong> $($chain.Status)</p>
        <p><strong>Chain Integrity:</strong> <span class="$(if ($validation.ChainValid) {'valid'} else {'invalid'})">$(if ($validation.ChainValid) {'VALID'} else {'INVALID'})</span></p>
    </div>
    
    <h2>Evidence Items ($($chain.EvidenceItems.Count))</h2>
    <table>
        <tr>
            <th>Evidence ID</th>
            <th>Type</th>
            <th>Description</th>
            <th>Added Date</th>
            <th>Verified</th>
        </tr>
$(foreach ($item in $chain.EvidenceItems) {
"        <tr>
            <td>$($item.EvidenceId)</td>
            <td>$($item.EvidenceType)</td>
            <td>$($item.Description)</td>
            <td>$($item.AddedDate)</td>
            <td>$(if ($item.Verified) {'Yes'} else {'No'})</td>
        </tr>"
})
    </table>
    
    <h2>Validation Results</h2>
    <div class="metadata">
        <p><strong>Total Evidence:</strong> $($validation.EvidenceCount)</p>
        <p><strong>Verified:</strong> $($validation.VerifiedCount)</p>
        <p><strong>Failed:</strong> $($validation.FailedCount)</p>
        <p><strong>Missing Files:</strong> $($validation.MissingFiles.Count)</p>
        <p><strong>Hash Mismatches:</strong> $($validation.HashMismatches.Count)</p>
    </div>
    
    <p><em>Report generated on $($validation.ValidationDate)</em></p>
</body>
</html>
"@
            $html | Out-File -FilePath $OutputPath -Encoding utf8
        }
        
        'Text' {
            $report = @"
=== EVIDENCE CHAIN REPORT ===

Claim ID: $($chain.ClaimId)
Claim Type: $($chain.ClaimType)
Description: $($chain.Description)
Created: $($chain.CreatedDate)
Last Updated: $($chain.LastUpdated)
Status: $($chain.Status)

=== EVIDENCE ITEMS ($($chain.EvidenceItems.Count)) ===

$(foreach ($item in $chain.EvidenceItems) {
"Evidence ID: $($item.EvidenceId)
Type: $($item.EvidenceType)
Description: $($item.Description)
Added: $($item.AddedDate)
Verified: $(if ($item.Verified) {'Yes'} else {'No'})
---
"
})

=== VALIDATION RESULTS ===

Chain Valid: $(if ($validation.ChainValid) {'YES'} else {'NO'})
Total Evidence: $($validation.EvidenceCount)
Verified: $($validation.VerifiedCount)
Failed: $($validation.FailedCount)
Missing Files: $($validation.MissingFiles.Count)
Hash Mismatches: $($validation.HashMismatches.Count)

Report generated on $($validation.ValidationDate)
"@
            $report | Out-File -FilePath $OutputPath -Encoding utf8
        }
    }
    
    Write-Host "Report exported to: $OutputPath"
}

# Export module members
Export-ModuleMember -Function @(
    'New-EvidenceChain',
    'Add-EvidenceItem',
    'Test-EvidenceChainIntegrity',
    'Get-EvidenceChain',
    'Export-EvidenceChainReport'
)
