# Supabase Edge Function: Raymond MCP Memory Server

Run your MCP Memory System natively inside **Supabase Edge Functions**.
- ❌ No Docker containers
- ❌ No VPS to maintain
- ❌ No Cloudflare account needed
- ❌ No tunnels
- ✅ **$0.00 / month** on your existing Supabase project
- ✅ **Google Gemini 768-dim Embeddings** (1,500 req/min free tier)
- ✅ Direct, zero-latency access to your Postgres database & `pgvector`

---

## 🏗️ Architecture

```mermaid
flowchart TD
    Agent["Autonomous Agent (AGY / Claude / Cursor)"]
    Gateway["Supabase Edge Function (/functions/v1/mcp)"]
    Gemini["Google Gemini (gemini-embedding-001)"]
    Postgres[("Supabase PostgreSQL")]
    Memories[("public.memories")]
    Skills[("public.skills")]

    Agent -->|"MCP over SSE (HTTPS)"| Gateway
    Gateway -->|"1. Generate 768-dim Vector"| Gemini
    Gemini -->|"2. Return Vector"| Gateway
    Gateway -->|"3. Execute match_memories RPC"| Postgres
    Postgres --- Memories
    Postgres --- Skills
```

---

## ⚙️ Configuration

### 1. Configure Supabase Database
In your [Supabase Dashboard](https://supabase.com/dashboard) -> **SQL Editor**, run the entire [`schema.sql`](../schema.sql) script to enable `pgvector` (768 dimensions), create the tables, indexes, and RPC functions.

### 2. Configure Google AI Studio (Gemini)
1. Go to [Google AI Studio](https://aistudio.google.com).
2. Click **Get API key** -> **Create API key**.
3. Set the key into your Supabase project secrets:
   ```bash
   npx supabase secrets set GEMINI_API_KEY=AIzaSy... --project-ref <YOUR_PROJECT_REF>
   ```

### 3. Deploy Function
- **Via GitHub Actions (Recommended)**: Set `SUPABASE_ACCESS_TOKEN`, `SUPABASE_URL`, and `GEMINI_API_KEY` in your GitHub repository secrets. Every push to `main` deploys automatically.
- **Via CLI**:
  ```bash
  npx supabase login
  npx supabase link --project-ref <YOUR_PROJECT_REF>
  npx supabase functions deploy mcp --no-verify-jwt
  ```

---

## 🤖 How to Use on Your Agent

Configure your MCP client:

### Method A: HTTP Header (Standard)
```json
{
  "mcpServers": {
    "supabase-memory": {
      "url": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/mcp/sse",
      "headers": {
        "Authorization": "Bearer YOUR_SUPABASE_SERVICE_ROLE_KEY"
      }
    }
  }
}
```

### Method B: URL Query Parameter
```json
{
  "mcpServers": {
    "supabase-memory": {
      "url": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/mcp/sse?apikey=YOUR_SUPABASE_SERVICE_ROLE_KEY"
    }
  }
}
```

### Test Deployment
```bash
curl https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/mcp/health?test=embedding
```
