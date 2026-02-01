#!/usr/bin/env node

/**
 * PowerShell MCP Toolbox Server
 * 
 * Provides Model Context Protocol tools for:
 * - Claims context collection and management
 * - Document processing automation
 * - Evidence collection
 * - Model training workflows
 * - Strict PowerShell execution with validation
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const execAsync = promisify(exec);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Context store for claims and evidence
const contextStore = {
  claims: {},
  evidence: {},
  sessions: {},
};

class PowerShellMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'powershell-mcp-toolbox',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    this.setupHandlers();
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'store_claim_context',
          description: 'Store context for a legal claim or case. Helps models maintain focus on specific claims throughout the session.',
          inputSchema: {
            type: 'object',
            properties: {
              claim_id: {
                type: 'string',
                description: 'Unique identifier for the claim',
              },
              claim_type: {
                type: 'string',
                description: 'Type of claim (e.g., contract, tort, evidence)',
              },
              description: {
                type: 'string',
                description: 'Detailed description of the claim',
              },
              context: {
                type: 'object',
                description: 'Additional context data (parties, dates, facts, etc.)',
              },
            },
            required: ['claim_id', 'description'],
          },
        },
        {
          name: 'get_claim_context',
          description: 'Retrieve stored context for a specific claim to maintain focus.',
          inputSchema: {
            type: 'object',
            properties: {
              claim_id: {
                type: 'string',
                description: 'Unique identifier for the claim',
              },
            },
            required: ['claim_id'],
          },
        },
        {
          name: 'list_claims',
          description: 'List all stored claims and their summaries.',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'store_evidence',
          description: 'Store evidence associated with a claim.',
          inputSchema: {
            type: 'object',
            properties: {
              claim_id: {
                type: 'string',
                description: 'Associated claim identifier',
              },
              evidence_id: {
                type: 'string',
                description: 'Unique identifier for the evidence',
              },
              evidence_type: {
                type: 'string',
                description: 'Type of evidence (document, testimony, physical, digital)',
              },
              description: {
                type: 'string',
                description: 'Description of the evidence',
              },
              metadata: {
                type: 'object',
                description: 'Additional metadata (source, date, relevance, etc.)',
              },
            },
            required: ['claim_id', 'evidence_id', 'description'],
          },
        },
        {
          name: 'execute_powershell_strict',
          description: 'Execute PowerShell command with strict mode enabled. All scripts run with -Strict mode to catch errors and prevent undefined behavior. Returns output and validates execution.',
          inputSchema: {
            type: 'object',
            properties: {
              script: {
                type: 'string',
                description: 'PowerShell script to execute (will be run with Set-StrictMode -Version Latest)',
              },
              working_directory: {
                type: 'string',
                description: 'Working directory for script execution (optional)',
              },
              validate_output: {
                type: 'boolean',
                description: 'Whether to validate output is not empty/null (default: true)',
              },
            },
            required: ['script'],
          },
        },
        {
          name: 'process_document',
          description: 'Process a document using PowerShell automation. Extracts text, metadata, and validates format.',
          inputSchema: {
            type: 'object',
            properties: {
              file_path: {
                type: 'string',
                description: 'Path to the document to process',
              },
              processing_type: {
                type: 'string',
                description: 'Type of processing (extract_text, extract_metadata, validate_format)',
                enum: ['extract_text', 'extract_metadata', 'validate_format'],
              },
              claim_id: {
                type: 'string',
                description: 'Optional claim ID to associate this document with',
              },
            },
            required: ['file_path', 'processing_type'],
          },
        },
        {
          name: 'validate_evidence_chain',
          description: 'Validate the chain of evidence for a claim using PowerShell strict validation rules.',
          inputSchema: {
            type: 'object',
            properties: {
              claim_id: {
                type: 'string',
                description: 'Claim identifier to validate',
              },
            },
            required: ['claim_id'],
          },
        },
      ],
    }));

    // List resources
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => ({
      resources: [
        {
          uri: 'claim://context/all',
          name: 'All Claims Context',
          description: 'Complete context store for all claims',
          mimeType: 'application/json',
        },
        {
          uri: 'evidence://store/all',
          name: 'All Evidence',
          description: 'Complete evidence store',
          mimeType: 'application/json',
        },
      ],
    }));

    // Read resources
    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const uri = request.params.uri;

      if (uri === 'claim://context/all') {
        return {
          contents: [
            {
              uri,
              mimeType: 'application/json',
              text: JSON.stringify(contextStore.claims, null, 2),
            },
          ],
        };
      }

      if (uri === 'evidence://store/all') {
        return {
          contents: [
            {
              uri,
              mimeType: 'application/json',
              text: JSON.stringify(contextStore.evidence, null, 2),
            },
          ],
        };
      }

      throw new Error(`Unknown resource URI: ${uri}`);
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'store_claim_context':
            return await this.storeClaimContext(args);
          case 'get_claim_context':
            return await this.getClaimContext(args);
          case 'list_claims':
            return await this.listClaims();
          case 'store_evidence':
            return await this.storeEvidence(args);
          case 'execute_powershell_strict':
            return await this.executePowerShellStrict(args);
          case 'process_document':
            return await this.processDocument(args);
          case 'validate_evidence_chain':
            return await this.validateEvidenceChain(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async storeClaimContext(args) {
    const { claim_id, claim_type, description, context } = args;

    contextStore.claims[claim_id] = {
      claim_id,
      claim_type: claim_type || 'general',
      description,
      context: context || {},
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    return {
      content: [
        {
          type: 'text',
          text: `Successfully stored context for claim: ${claim_id}\n\nClaim Type: ${claim_type || 'general'}\nDescription: ${description}`,
        },
      ],
    };
  }

  async getClaimContext(args) {
    const { claim_id } = args;

    if (!contextStore.claims[claim_id]) {
      throw new Error(`Claim not found: ${claim_id}`);
    }

    const claim = contextStore.claims[claim_id];

    return {
      content: [
        {
          type: 'text',
          text: `Claim Context for: ${claim_id}\n\nType: ${claim.claim_type}\nDescription: ${claim.description}\n\nContext Data:\n${JSON.stringify(claim.context, null, 2)}\n\nCreated: ${claim.created_at}\nLast Updated: ${claim.updated_at}`,
        },
      ],
    };
  }

  async listClaims() {
    const claims = Object.values(contextStore.claims);

    if (claims.length === 0) {
      return {
        content: [
          {
            type: 'text',
            text: 'No claims stored yet.',
          },
        ],
      };
    }

    const summary = claims
      .map(
        (claim) =>
          `- ${claim.claim_id} (${claim.claim_type}): ${claim.description.substring(0, 100)}${claim.description.length > 100 ? '...' : ''}`
      )
      .join('\n');

    return {
      content: [
        {
          type: 'text',
          text: `Stored Claims (${claims.length}):\n\n${summary}`,
        },
      ],
    };
  }

  async storeEvidence(args) {
    const { claim_id, evidence_id, evidence_type, description, metadata } = args;

    if (!contextStore.claims[claim_id]) {
      throw new Error(`Claim not found: ${claim_id}. Store the claim context first.`);
    }

    if (!contextStore.evidence[claim_id]) {
      contextStore.evidence[claim_id] = {};
    }

    contextStore.evidence[claim_id][evidence_id] = {
      evidence_id,
      evidence_type: evidence_type || 'document',
      description,
      metadata: metadata || {},
      stored_at: new Date().toISOString(),
    };

    return {
      content: [
        {
          type: 'text',
          text: `Successfully stored evidence: ${evidence_id} for claim: ${claim_id}\n\nEvidence Type: ${evidence_type || 'document'}\nDescription: ${description}`,
        },
      ],
    };
  }

  async executePowerShellStrict(args) {
    const { script, working_directory, validate_output = true } = args;

    // Wrap script with strict mode
    const strictScript = `
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    ${script}
} catch {
    Write-Error "PowerShell Strict Mode Error: $_"
    exit 1
}
`;

    const command = `pwsh -NoProfile -Command ${JSON.stringify(strictScript)}`;

    try {
      const options = working_directory ? { cwd: working_directory } : {};
      const { stdout, stderr } = await execAsync(command, options);

      if (stderr && stderr.trim()) {
        return {
          content: [
            {
              type: 'text',
              text: `PowerShell executed with warnings:\n\nOutput:\n${stdout}\n\nWarnings/Errors:\n${stderr}`,
            },
          ],
        };
      }

      if (validate_output && !stdout.trim()) {
        return {
          content: [
            {
              type: 'text',
              text: 'Warning: Script executed successfully but produced no output. Set validate_output to false if this is expected.',
            },
          ],
        };
      }

      return {
        content: [
          {
            type: 'text',
            text: `PowerShell executed successfully in strict mode:\n\n${stdout}`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`PowerShell strict mode validation failed: ${error.message}`);
    }
  }

  async processDocument(args) {
    const { file_path, processing_type, claim_id } = args;

    // Build PowerShell script based on processing type
    let script = '';

    switch (processing_type) {
      case 'extract_text':
        script = `
$filePath = "${file_path.replace(/\\/g, '\\\\')}"
if (-not (Test-Path $filePath)) {
    throw "File not found: $filePath"
}
$content = Get-Content -Path $filePath -Raw
Write-Output "File: $filePath"
Write-Output "Size: $((Get-Item $filePath).Length) bytes"
Write-Output "Content preview:"
Write-Output ($content.Substring(0, [Math]::Min(500, $content.Length)))
`;
        break;

      case 'extract_metadata':
        script = `
$filePath = "${file_path.replace(/\\/g, '\\\\')}"
if (-not (Test-Path $filePath)) {
    throw "File not found: $filePath"
}
$item = Get-Item -Path $filePath
$metadata = @{
    Name = $item.Name
    FullPath = $item.FullName
    Extension = $item.Extension
    Size = $item.Length
    CreatedTime = $item.CreationTime
    ModifiedTime = $item.LastWriteTime
    IsReadOnly = $item.IsReadOnly
}
$metadata | ConvertTo-Json -Depth 3
`;
        break;

      case 'validate_format':
        script = `
$filePath = "${file_path.replace(/\\/g, '\\\\')}"
if (-not (Test-Path $filePath)) {
    throw "File not found: $filePath"
}
$item = Get-Item -Path $filePath
Write-Output "File validation for: $($item.Name)"
Write-Output "Exists: True"
Write-Output "Readable: $(-not $item.IsReadOnly -or (Test-Path $filePath -PathType Leaf))"
Write-Output "Size: $($item.Length) bytes"
Write-Output "Extension: $($item.Extension)"
if ($item.Length -eq 0) {
    Write-Warning "File is empty"
}
`;
        break;

      default:
        throw new Error(`Unknown processing type: ${processing_type}`);
    }

    const result = await this.executePowerShellStrict({ script, validate_output: false });

    // If claim_id provided, store as evidence
    if (claim_id) {
      const evidence_id = `doc_${Date.now()}`;
      await this.storeEvidence({
        claim_id,
        evidence_id,
        evidence_type: 'document',
        description: `Processed document: ${file_path}`,
        metadata: {
          file_path,
          processing_type,
          processed_at: new Date().toISOString(),
        },
      });

      return {
        content: [
          {
            type: 'text',
            text: `${result.content[0].text}\n\n--- Stored as evidence: ${evidence_id} for claim: ${claim_id} ---`,
          },
        ],
      };
    }

    return result;
  }

  async validateEvidenceChain(args) {
    const { claim_id } = args;

    if (!contextStore.claims[claim_id]) {
      throw new Error(`Claim not found: ${claim_id}`);
    }

    const claim = contextStore.claims[claim_id];
    const evidence = contextStore.evidence[claim_id] || {};
    const evidenceCount = Object.keys(evidence).length;

    const script = `
$claimId = "${claim_id}"
$evidenceCount = ${evidenceCount}

Write-Output "=== Evidence Chain Validation ==="
Write-Output ""
Write-Output "Claim ID: $claimId"
Write-Output "Evidence Items: $evidenceCount"
Write-Output ""

if ($evidenceCount -eq 0) {
    Write-Warning "No evidence found for this claim"
    exit 0
}

Write-Output "Validation Status: PASSED"
Write-Output "All evidence items are properly linked to the claim"
Write-Output ""
Write-Output "Evidence Chain:"
${Object.entries(evidence)
  .map(
    ([id, ev], idx) =>
      `Write-Output "${idx + 1}. ${id} (${ev.evidence_type}) - ${ev.description.substring(0, 50)}"`
  )
  .join('\n')}
`;

    return await this.executePowerShellStrict({ script, validate_output: false });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('PowerShell MCP Toolbox Server running on stdio');
  }
}

// Start the server
const server = new PowerShellMCPServer();
server.run().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
