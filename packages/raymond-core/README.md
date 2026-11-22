# @raymond/core

The core serverless memory and knowledge graph engine for Raymond.

## Overview
`@raymond/core` encapsulates:
- **PostgreSQL Database Schema & Migrations**: Relational grounding, pgvector embeddings, and transaction tables (`packages/raymond-core/supabase/migrations/`).
- **Supabase Edge Function MCP Server**: Model Context Protocol (MCP) server running on Deno/Edge (`packages/raymond-core/supabase/functions/mcp/`).
- **Dietz-Burgess Transaction Protocol**: Atomic multi-agent promise and transaction state machines (`tx_*` tools).
- **Standalone SQL Reference**: Complete bootstrap script in `packages/raymond-core/schema.sql`.

## Deployment
Automated deployment is handled via GitHub Actions in `.github/workflows/deploy.yml` whenever changes are pushed to `packages/raymond-core/**`.

To deploy manually via Supabase CLI:
```bash
cd packages/raymond-core
supabase functions deploy mcp --project-ref <PROJECT_REF> --no-verify-jwt
```
