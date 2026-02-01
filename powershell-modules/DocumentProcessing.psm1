<#
.SYNOPSIS
Document Processing Module for Legal Evidence Collection

.DESCRIPTION
Provides functions for processing documents with strict validation,
extracting metadata, and preparing documents for evidence collection.
All functions run with Set-StrictMode to ensure data integrity.

.NOTES
Author: PowerShell MCP Toolbox
Version: 1.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DocumentMetadata {
    <#
    .SYNOPSIS
    Extract comprehensive metadata from a document
    
    .PARAMETER FilePath
    Path to the document file
    
    .EXAMPLE
    Get-DocumentMetadata -FilePath "C:\Documents\evidence.pdf"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$FilePath
    )
    
    try {
        $file = Get-Item -Path $FilePath
        
        $metadata = [PSCustomObject]@{
            FileName        = $file.Name
            FullPath        = $file.FullName
            Extension       = $file.Extension
            SizeBytes       = $file.Length
            SizeKB          = [Math]::Round($file.Length / 1KB, 2)
            SizeMB          = [Math]::Round($file.Length / 1MB, 2)
            CreatedDate     = $file.CreationTime
            ModifiedDate    = $file.LastWriteTime
            AccessedDate    = $file.LastAccessTime
            IsReadOnly      = $file.IsReadOnly
            Attributes      = $file.Attributes
            Directory       = $file.DirectoryName
            Hash_MD5        = (Get-FileHash -Path $FilePath -Algorithm MD5).Hash
            Hash_SHA256     = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
        }
        
        return $metadata
    }
    catch {
        Write-Error "Failed to extract metadata from $FilePath : $_"
        throw
    }
}

function Test-DocumentIntegrity {
    <#
    .SYNOPSIS
    Validate document integrity and readability
    
    .PARAMETER FilePath
    Path to the document file
    
    .PARAMETER ExpectedHash
    Optional expected SHA256 hash for validation
    
    .EXAMPLE
    Test-DocumentIntegrity -FilePath "C:\Documents\evidence.pdf"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$ExpectedHash
    )
    
    $validationResult = [PSCustomObject]@{
        FilePath       = $FilePath
        Exists         = $false
        Readable       = $false
        NotEmpty       = $false
        HashMatch      = $null
        ValidationDate = Get-Date
        Issues         = @()
    }
    
    # Check existence
    if (Test-Path -Path $FilePath) {
        $validationResult.Exists = $true
    }
    else {
        $validationResult.Issues += "File does not exist"
        return $validationResult
    }
    
    # Check readability
    try {
        $null = Get-Content -Path $FilePath -First 1 -ErrorAction Stop
        $validationResult.Readable = $true
    }
    catch {
        $validationResult.Issues += "File is not readable: $_"
    }
    
    # Check if not empty
    $file = Get-Item -Path $FilePath
    if ($file.Length -gt 0) {
        $validationResult.NotEmpty = $true
    }
    else {
        $validationResult.Issues += "File is empty (0 bytes)"
    }
    
    # Check hash if provided
    if ($ExpectedHash) {
        try {
            $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
            $validationResult.HashMatch = ($actualHash -eq $ExpectedHash)
            if (-not $validationResult.HashMatch) {
                $validationResult.Issues += "Hash mismatch. Expected: $ExpectedHash, Got: $actualHash"
            }
        }
        catch {
            $validationResult.Issues += "Failed to calculate hash: $_"
        }
    }
    
    return $validationResult
}

function Export-DocumentEvidence {
    <#
    .SYNOPSIS
    Export document with evidence metadata for legal processing
    
    .PARAMETER FilePath
    Path to the document file
    
    .PARAMETER OutputDirectory
    Directory to export evidence package
    
    .PARAMETER ClaimId
    Optional claim identifier to associate with evidence
    
    .EXAMPLE
    Export-DocumentEvidence -FilePath "C:\Documents\contract.pdf" -OutputDirectory "C:\Evidence" -ClaimId "CLAIM-2024-001"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory,
        
        [Parameter(Mandatory = $false)]
        [string]$ClaimId
    )
    
    # Ensure output directory exists
    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
    
    # Get document metadata
    $metadata = Get-DocumentMetadata -FilePath $FilePath
    
    # Create evidence package
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $evidenceId = if ($ClaimId) { "$ClaimId`_$timestamp" } else { "EVIDENCE_$timestamp" }
    $evidenceDir = Join-Path -Path $OutputDirectory -ChildPath $evidenceId
    
    New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
    
    # Copy original document
    $file = Get-Item -Path $FilePath
    $destPath = Join-Path -Path $evidenceDir -ChildPath $file.Name
    Copy-Item -Path $FilePath -Destination $destPath -Force
    
    # Export metadata
    $metadataPath = Join-Path -Path $evidenceDir -ChildPath "metadata.json"
    $metadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $metadataPath -Encoding utf8
    
    # Create evidence manifest
    $manifest = [PSCustomObject]@{
        EvidenceId      = $evidenceId
        ClaimId         = $ClaimId
        OriginalPath    = $FilePath
        ExportedPath    = $destPath
        ExportDate      = Get-Date
        IntegrityHash   = $metadata.Hash_SHA256
        Metadata        = $metadata
    }
    
    $manifestPath = Join-Path -Path $evidenceDir -ChildPath "manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath $manifestPath -Encoding utf8
    
    Write-Output "Evidence package created: $evidenceDir"
    return $manifest
}

function Find-DocumentsByPattern {
    <#
    .SYNOPSIS
    Search for documents matching a pattern with strict validation
    
    .PARAMETER Path
    Base path to search
    
    .PARAMETER Pattern
    File pattern to match (e.g., "*.pdf", "contract*")
    
    .PARAMETER Recurse
    Search recursively in subdirectories
    
    .EXAMPLE
    Find-DocumentsByPattern -Path "C:\Documents" -Pattern "*.pdf" -Recurse
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        
        [Parameter(Mandatory = $false)]
        [switch]$Recurse
    )
    
    $searchParams = @{
        Path    = $Path
        Filter  = $Pattern
        File    = $true
    }
    
    if ($Recurse) {
        $searchParams.Recurse = $true
    }
    
    try {
        $files = Get-ChildItem @searchParams
        
        if ($files.Count -eq 0) {
            Write-Warning "No files found matching pattern '$Pattern' in path '$Path'"
            return @()
        }
        
        $results = foreach ($file in $files) {
            [PSCustomObject]@{
                Name         = $file.Name
                FullPath     = $file.FullName
                SizeMB       = [Math]::Round($file.Length / 1MB, 2)
                Extension    = $file.Extension
                ModifiedDate = $file.LastWriteTime
            }
        }
        
        return $results
    }
    catch {
        Write-Error "Search failed: $_"
        throw
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-DocumentMetadata',
    'Test-DocumentIntegrity',
    'Export-DocumentEvidence',
    'Find-DocumentsByPattern'
)
