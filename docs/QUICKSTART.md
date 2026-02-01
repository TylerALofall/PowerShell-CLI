# Quick Start Guide - PowerShell MCP Toolbox

This guide will help you get started with the PowerShell MCP Toolbox for managing legal claims and evidence collection.

## Installation Steps

### 1. Install Prerequisites

**Node.js 18+**
```bash
# Check if installed
node --version

# If not installed, download from: https://nodejs.org/
```

**PowerShell 7+**
```bash
# Check if installed
pwsh --version

# Windows: Install via Microsoft Store or download from:
# https://github.com/PowerShell/PowerShell/releases

# Linux:
# wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
# sudo dpkg -i packages-microsoft-prod.deb
# sudo apt-get update
# sudo apt-get install -y powershell

# macOS:
# brew install --cask powershell
```

### 2. Install Dependencies

```bash
cd /path/to/PowerShell-CLI
npm install
```

### 3. Configure MCP Client

For **Claude Desktop**, edit the configuration file:

**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux**: `~/.config/Claude/claude_desktop_config.json`

Add this configuration:

```json
{
  "mcpServers": {
    "powershell-toolbox": {
      "command": "node",
      "args": [
        "/absolute/path/to/PowerShell-CLI/src/index.js"
      ]
    }
  }
}
```

**Important**: Replace `/absolute/path/to/PowerShell-CLI` with the actual path to your repository.

### 4. Restart Claude Desktop

After saving the configuration, restart Claude Desktop to load the MCP server.

## Testing the Installation

### Test 1: Verify MCP Server Connection

In Claude Desktop, ask:
```
List the available MCP tools from the powershell-toolbox server
```

You should see tools like:
- store_claim_context
- get_claim_context
- execute_powershell_strict
- process_document
- validate_evidence_chain

### Test 2: Store a Claim

```
Use the powershell-toolbox to store a new claim:
- claim_id: TEST-2024-001
- claim_type: contract
- description: Test claim for verification
```

### Test 3: Execute PowerShell

```
Use the powershell-toolbox to execute this PowerShell command:
Get-Date | Select-Object DateTime, DayOfWeek
```

### Test 4: Run the Example Workflow

Open PowerShell and run:
```powershell
cd /path/to/PowerShell-CLI
pwsh -File ./examples/complete-workflow.ps1
```

This will create a complete example with:
- Evidence chain
- Sample documents
- Integrity validation
- Reports (Text, JSON, HTML)

## Using PowerShell Modules Directly

### Import Modules

```powershell
# Import document processing
Import-Module "./powershell-modules/DocumentProcessing.psm1"

# Import evidence collection
Import-Module "./powershell-modules/EvidenceCollection.psm1"
```

### Example: Process a Document

```powershell
# Extract metadata from a file
$metadata = Get-DocumentMetadata -FilePath "C:\path\to\document.pdf"
$metadata | Format-List

# Validate document integrity
$validation = Test-DocumentIntegrity -FilePath "C:\path\to\document.pdf"
if ($validation.NotEmpty -and $validation.Readable) {
    Write-Host "Document is valid!"
}
```

### Example: Create Evidence Chain

```powershell
# Create new evidence chain
$chain = New-EvidenceChain `
    -ClaimId "CLAIM-2024-001" `
    -ClaimType "Contract" `
    -Description "Contract dispute case" `
    -OutputPath "C:\Evidence\Chains"

# Add evidence
Add-EvidenceItem `
    -ClaimId "CLAIM-2024-001" `
    -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json" `
    -EvidenceType "Document" `
    -SourcePath "C:\Documents\contract.pdf" `
    -Description "Original signed contract"

# Validate chain
$validation = Test-EvidenceChainIntegrity `
    -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json"

if ($validation.ChainValid) {
    Write-Host "Evidence chain is valid!"
}

# Export report
Export-EvidenceChainReport `
    -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json" `
    -OutputPath "C:\Reports\evidence-report.html" `
    -Format "HTML"
```

## Common Workflows

### Workflow 1: Document Evidence Collection

1. **Store claim context** (via MCP or directly)
2. **Process documents** to extract metadata
3. **Add to evidence chain** with proper tracking
4. **Validate chain integrity** regularly
5. **Generate reports** for review

### Workflow 2: Bulk Document Processing

```powershell
# Find all PDFs in a directory
$docs = Find-DocumentsByPattern -Path "C:\Documents" -Pattern "*.pdf" -Recurse

# Process each document
foreach ($doc in $docs) {
    $metadata = Get-DocumentMetadata -FilePath $doc.FullPath
    Write-Host "Processed: $($doc.Name) - Size: $($metadata.SizeMB) MB"
}
```

### Workflow 3: Evidence Chain Validation

```powershell
# Get all evidence chains
$chains = Get-ChildItem -Path "C:\Evidence\Chains" -Filter "*.json"

# Validate each chain
foreach ($chainFile in $chains) {
    $validation = Test-EvidenceChainIntegrity -ChainPath $chainFile.FullName
    
    if ($validation.ChainValid) {
        Write-Host "✓ $($chainFile.Name) - VALID" -ForegroundColor Green
    } else {
        Write-Host "✗ $($chainFile.Name) - INVALID" -ForegroundColor Red
        $validation.Issues | ForEach-Object { Write-Host "  $_" }
    }
}
```

## MCP Integration Examples

### Example 1: Contextual Claim Management

Ask Claude:
```
I need to manage a legal claim. Can you:
1. Store context for claim ID "BREACH-2024-42" 
2. Type: contract
3. Description: "Vendor failed to deliver software as specified in contract dated 2024-01-15"
4. Context: parties are "TechCorp Inc" and "DevStudio LLC", contract value $50,000
```

### Example 2: Document Processing with Context

Ask Claude:
```
I have a contract document at C:\Documents\contract.pdf
Can you:
1. Extract its metadata
2. Process it for the claim BREACH-2024-42
3. Validate that it's readable and has content
```

### Example 3: Evidence Chain Validation

Ask Claude:
```
Please validate the evidence chain for claim BREACH-2024-42 and tell me:
- How many evidence items are stored
- Whether the chain integrity is valid
- Any issues found
```

## Troubleshooting

### Issue: MCP server not appearing in Claude

**Solution:**
1. Check that the path in config is absolute (not relative)
2. Verify Node.js is in PATH: `node --version`
3. Check logs in Claude's developer console
4. Restart Claude Desktop completely

### Issue: PowerShell commands fail

**Solution:**
1. Verify PowerShell 7+ is installed: `pwsh --version`
2. Ensure `pwsh` is in system PATH
3. On Windows, you may need to run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Issue: Module import errors

**Solution:**
1. Use absolute paths when importing modules
2. Verify the .psm1 files exist in powershell-modules/
3. Check file permissions

### Issue: Evidence chain file not found

**Solution:**
1. Ensure the output directory exists before creating chains
2. Use absolute paths for chain storage
3. Check that you have write permissions to the directory

## Next Steps

1. **Review the main README.md** for comprehensive documentation
2. **Run the example workflow** to see everything in action
3. **Create your first claim** using the MCP tools
4. **Process some documents** and add them to evidence chains
5. **Generate reports** to review your evidence

## Getting Help

- Review the full documentation in README.md
- Check the examples/ directory for more scripts
- Review the PowerShell module comments for detailed function documentation
- Test with the example workflow first before processing real data

## Best Practices

1. **Always use strict mode** - It's built into all modules and MCP tools
2. **Validate evidence regularly** - Run integrity checks on your chains
3. **Keep backups** - Evidence chains are JSON files, back them up regularly
4. **Use descriptive IDs** - Make claim IDs and evidence IDs meaningful
5. **Document everything** - Use the description fields generously
6. **Test first** - Use the example workflow to understand the system before real use

Enjoy using the PowerShell MCP Toolbox!
