# PowerShell MCP Toolbox

A Model Context Protocol (MCP) server for PowerShell-based document processing, evidence collection, and model training automation with strict validation.

## Overview

This toolbox provides AI models with focused context management for legal claims while maintaining PowerShell's strict mode validation to ensure data integrity and prevent errors.

## Features

### 🎯 Context Management
- **Claims Context Storage**: Store and retrieve detailed claim information
- **Evidence Linking**: Associate evidence with specific claims
- **Session Persistence**: Maintain focus across model interactions

### ⚡ PowerShell Strict Mode
- All scripts execute with `Set-StrictMode -Version Latest`
- Automatic error detection and validation
- Prevention of undefined behavior and null references

### 📄 Document Processing
- Extract text and metadata from documents
- Validate file integrity with hash verification
- Process multiple document formats

### 🔐 Evidence Collection
- Chain of custody tracking
- Evidence integrity validation
- Comprehensive evidence reports

## Installation

1. **Prerequisites**
   - Node.js 18 or higher
   - PowerShell 7+ (pwsh)

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Configure MCP Client**
   
   Add to your MCP client configuration (e.g., Claude Desktop):
   
   ```json
   {
     "mcpServers": {
       "powershell-toolbox": {
         "command": "node",
         "args": ["/path/to/PowerShell-CLI/src/index.js"]
       }
     }
   }
   ```

## MCP Tools

### Context Management Tools

#### `store_claim_context`
Store context for a legal claim or case.

**Parameters:**
- `claim_id` (required): Unique identifier for the claim
- `claim_type`: Type of claim (contract, tort, evidence, etc.)
- `description` (required): Detailed description
- `context`: Additional context data (parties, dates, facts)

**Example:**
```json
{
  "claim_id": "CLAIM-2024-001",
  "claim_type": "contract",
  "description": "Breach of contract for software development services",
  "context": {
    "parties": ["Company A", "Developer B"],
    "contract_date": "2024-01-15",
    "breach_date": "2024-06-01"
  }
}
```

#### `get_claim_context`
Retrieve stored context for a specific claim.

**Parameters:**
- `claim_id` (required): Unique identifier for the claim

#### `list_claims`
List all stored claims and their summaries.

#### `store_evidence`
Store evidence associated with a claim.

**Parameters:**
- `claim_id` (required): Associated claim identifier
- `evidence_id` (required): Unique identifier for the evidence
- `evidence_type`: Type of evidence (document, testimony, physical, digital)
- `description` (required): Description of the evidence
- `metadata`: Additional metadata

### PowerShell Execution Tools

#### `execute_powershell_strict`
Execute PowerShell commands with strict mode validation.

**Parameters:**
- `script` (required): PowerShell script to execute
- `working_directory`: Working directory for execution
- `validate_output`: Whether to validate output is not empty (default: true)

**Example:**
```json
{
  "script": "Get-ChildItem -Path C:\\Documents | Where-Object {$_.Extension -eq '.pdf'}",
  "validate_output": true
}
```

#### `process_document`
Process a document using PowerShell automation.

**Parameters:**
- `file_path` (required): Path to the document
- `processing_type` (required): extract_text, extract_metadata, or validate_format
- `claim_id`: Optional claim ID to associate document with

#### `validate_evidence_chain`
Validate the chain of evidence for a claim.

**Parameters:**
- `claim_id` (required): Claim identifier to validate

## PowerShell Modules

### DocumentProcessing.psm1

Functions for document processing:

- `Get-DocumentMetadata`: Extract comprehensive metadata from documents
- `Test-DocumentIntegrity`: Validate document integrity and readability
- `Export-DocumentEvidence`: Export document with evidence metadata
- `Find-DocumentsByPattern`: Search for documents with pattern matching

**Usage Example:**
```powershell
Import-Module ./powershell-modules/DocumentProcessing.psm1

# Extract metadata
$metadata = Get-DocumentMetadata -FilePath "C:\Documents\contract.pdf"

# Validate integrity
$validation = Test-DocumentIntegrity -FilePath "C:\Documents\contract.pdf" -ExpectedHash "ABC123..."

# Export as evidence
Export-DocumentEvidence -FilePath "C:\Documents\contract.pdf" -OutputDirectory "C:\Evidence" -ClaimId "CLAIM-2024-001"
```

### EvidenceCollection.psm1

Functions for evidence management:

- `New-EvidenceChain`: Initialize a new evidence chain for a claim
- `Add-EvidenceItem`: Add evidence items to a chain
- `Test-EvidenceChainIntegrity`: Validate chain integrity
- `Get-EvidenceChain`: Retrieve evidence chain details
- `Export-EvidenceChainReport`: Generate evidence reports (JSON, HTML, Text)

**Usage Example:**
```powershell
Import-Module ./powershell-modules/EvidenceCollection.psm1

# Create evidence chain
$chain = New-EvidenceChain -ClaimId "CLAIM-2024-001" -ClaimType "Contract" -Description "Breach of contract" -OutputPath "C:\Evidence\Chains"

# Add evidence
Add-EvidenceItem -ClaimId "CLAIM-2024-001" -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json" -EvidenceType "Document" -SourcePath "C:\contract.pdf" -Description "Original contract"

# Validate chain
$validation = Test-EvidenceChainIntegrity -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json"

# Export report
Export-EvidenceChainReport -ChainPath "C:\Evidence\Chains\CLAIM-2024-001.json" -OutputPath "C:\Reports\report.html" -Format "HTML"
```

## Workflow Examples

### Example 1: Document Evidence Collection

```
1. Store claim context:
   - Use store_claim_context to create claim "CLAIM-2024-001"

2. Process documents:
   - Use process_document to extract metadata from contract.pdf
   - Associate with claim using claim_id parameter

3. Validate evidence:
   - Use validate_evidence_chain to verify all evidence is properly linked
```

### Example 2: Strict PowerShell Automation

```
1. Execute with validation:
   - Use execute_powershell_strict to run document search
   - Script runs with Set-StrictMode -Version Latest
   - Catches undefined variables, null references automatically

2. Process results:
   - Output validated for completeness
   - Errors caught and reported clearly
```

## Testing

### Run Module Tests

A test script is provided to verify the PowerShell modules are working correctly:

```bash
pwsh -File examples/test-modules.ps1
```

This will run 7 tests covering:
- Module loading
- Metadata extraction
- Document integrity validation
- Evidence chain creation
- Evidence item addition
- Chain integrity validation

### Run Complete Workflow Example

To see the full system in action:

```bash
pwsh -File examples/complete-workflow.ps1
```

This creates a complete example with evidence chains, sample documents, and reports.

## Directory Structure

```
PowerShell-CLI/
├── src/
│   └── index.js              # MCP server implementation
├── powershell-modules/
│   ├── DocumentProcessing.psm1    # Document processing functions
│   └── EvidenceCollection.psm1    # Evidence management functions
├── examples/
│   └── ...                   # Example scripts and workflows
├── docs/
│   └── ...                   # Additional documentation
├── package.json              # Node.js dependencies
├── .gitignore               # Git ignore rules
└── README.md                # This file
```

## Security & Best Practices

1. **Strict Mode**: All PowerShell scripts run with strict mode to catch errors early
2. **Validation**: Input validation on all file paths and parameters
3. **Hash Verification**: SHA256 hashing for evidence integrity
4. **Chain of Custody**: Timestamp and user tracking for all evidence
5. **No Secrets**: Never commit sensitive data or credentials

## Troubleshooting

### PowerShell Not Found
Ensure PowerShell 7+ is installed and `pwsh` is in your PATH:
```bash
pwsh --version
```

### MCP Connection Issues
Check your MCP client configuration and ensure the path to `src/index.js` is correct.

### Module Import Errors
Use absolute paths when importing modules in scripts:
```powershell
Import-Module "C:\full\path\to\PowerShell-CLI\powershell-modules\DocumentProcessing.psm1"
```

## Contributing

This is a personal automation project, but suggestions and improvements are welcome.

## License

MIT License - See package.json for details
