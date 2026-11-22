#!/usr/bin/env python3
"""
Raymond Knowledge Graph Viewer & Edge Proxy Tool
Fetches the Knowledge Graph JSON representation from Supabase / Edge Function
and serves an interactive local viewer.

Usage:
    python3 packages/raymond-ui/serve.py [port]               # Start web viewer & proxy (default port: 8080)
    python3 packages/raymond-ui/serve.py --json               # Output graph JSON to stdout
    python3 packages/raymond-ui/serve.py --dump graph.json    # Save graph JSON to file
    python3 packages/raymond-ui/serve.py --test               # Test connection and show stats
"""

import argparse
import http.server
import json
import os
import re
import socketserver
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DIRECTORY = os.path.dirname(os.path.abspath(__file__))

def discover_credentials(cli_url=None, cli_key=None):
    """
    Auto-discovers Supabase URL and Authorization Key from:
    1. CLI arguments
    2. Environment variables (SUPABASE_URL, SUPABASE_KEY, SUPABASE_SERVICE_ROLE_KEY)
    3. Workspace .env file
    4. Antigravity MCP config (~/.gemini/config/mcp_config.json)
    """
    url = cli_url or os.environ.get("SUPABASE_URL")
    key = cli_key or os.environ.get("SUPABASE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    source = "cli/env" if (url and key) else None

    # Try .env in workspace root
    if not (url and key):
        env_paths = [
            os.path.join(DIRECTORY, "..", "..", ".env"),
            os.path.join(DIRECTORY, "..", ".env"),
            os.path.join(DIRECTORY, ".env"),
            ".env"
        ]
        for p in env_paths:
            if os.path.exists(p):
                try:
                    with open(p, "r", encoding="utf-8") as f:
                        for line in f:
                            line = line.strip()
                            if line.startswith("#") or not line or "=" not in line:
                                continue
                            k, v = line.split("=", 1)
                            k, v = k.strip(), v.strip().strip('"\'')
                            if k == "SUPABASE_URL" and not url:
                                url = v
                            elif k in ("SUPABASE_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_ANON_KEY") and not key:
                                key = v
                    if url and key:
                        source = f".env ({p})"
                        break
                except Exception:
                    pass

    # Try ~/.gemini/config/mcp_config.json
    if not (url and key):
        gemini_mcp = os.path.expanduser("~/.gemini/config/mcp_config.json")
        if os.path.exists(gemini_mcp):
            try:
                with open(gemini_mcp, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
                servers = cfg.get("mcpServers", {})
                raymond_cfg = servers.get("raymond", {})
                raw_url = raymond_cfg.get("url", "")
                auth_hdr = raymond_cfg.get("headers", {}).get("Authorization", "")
                
                if raw_url and not url:
                    # Clean URL to project base: https://<ref>.supabase.co
                    match = re.match(r"(https?://[^/]+)", raw_url)
                    if match:
                        url = match.group(1)
                
                if auth_hdr and not key:
                    # Extract bearer token or raw key
                    key = auth_hdr.replace("Bearer ", "").strip()
                
                if url and key:
                    source = f"MCP Config ({gemini_mcp})"
            except Exception:
                pass

    if url:
        url = url.rstrip("/")
    return url, key, source

def fetch_json(url, headers=None, timeout=10):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = resp.read()
        return json.loads(data.decode("utf-8"))

def fetch_graph_from_edge_or_db(supabase_url, supabase_key):
    """
    Fetches the knowledge graph JSON representation:
    First tries the Edge Function endpoint /functions/v1/mcp/graph.json.
    Falls back to querying Supabase PostgREST tables directly.
    """
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    # 1. Try Edge Function graph.json endpoint
    edge_url = f"{supabase_url}/functions/v1/mcp/graph.json"
    try:
        data = fetch_json(edge_url, headers=headers, timeout=6)
        if isinstance(data, dict) and "entities" in data:
            data["source_endpoint"] = "edge_function"
            return data
    except Exception:
        pass

    # 2. Fallback: Query PostgREST tables directly
    rest_url = f"{supabase_url}/rest/v1"
    try:
        entities = fetch_json(f"{rest_url}/entities?select=*&order=name.asc&limit=1000", headers)
        relations = fetch_json(f"{rest_url}/relations?select=*&order=created_at.desc&limit=2000", headers)
        try:
            memories = fetch_json(f"{rest_url}/memories?select=id,agent_id,session_id,category,content,tags,created_at,metadata&order=created_at.desc&limit=300", headers)
        except Exception:
            memories = []
        try:
            memory_entities = fetch_json(f"{rest_url}/memory_entities?select=memory_id,entity_id", headers)
        except Exception:
            memory_entities = []

        linked_mems = set(me.get("memory_id") for me in memory_entities if me.get("memory_id"))
        for r in relations:
            if r.get("memory_id"):
                linked_mems.add(r.get("memory_id"))
        unlinked_count = len([m for m in memories if m.get("id") not in linked_mems])

        stats = {
            "entity_count": len(entities),
            "relation_count": len(relations),
            "active_relations": len([r for r in relations if not r.get("valid_to")]),
            "superseded_relations": len([r for r in relations if r.get("valid_to")]),
            "memory_count": len(memories),
            "grounded_memory_count": len(memories) - unlinked_count,
            "unlinked_memory_count": unlinked_count
        }

        return {
            "status": "ok",
            "source_endpoint": "postgrest_direct",
            "stats": stats,
            "entities": entities,
            "relations": relations,
            "memories": memories,
            "memory_entities": memory_entities
        }
    except Exception as e:
        raise RuntimeError(f"Failed to query Supabase: {e}")

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class KnowledgeGraphProxyHandler(http.server.SimpleHTTPRequestHandler):
    supabase_url = None
    supabase_key = None
    auth_source = None
    cached_graph = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/status":
            self.send_json_response(200, {
                "proxy": True,
                "connected": bool(self.supabase_url and self.supabase_key),
                "supabase_url": self.supabase_url,
                "auth_source": self.auth_source
            })
            return

        if path in ("/api/graph", "/api/graph.json"):
            if not (self.supabase_url and self.supabase_key):
                self.send_json_response(503, {
                    "error": "No Supabase credentials configured",
                    "hint": "Set SUPABASE_URL and SUPABASE_KEY in .env or ~/.gemini/config/mcp_config.json"
                })
                return

            qs = urllib.parse.parse_qs(parsed.query)
            force_refresh = qs.get("refresh", ["false"])[0] == "true"

            if self.cached_graph is None or force_refresh:
                try:
                    self.cached_graph = fetch_graph_from_edge_or_db(self.supabase_url, self.supabase_key)
                except Exception as e:
                    self.send_json_response(500, {"error": str(e)})
                    return

            self.send_json_response(200, self.cached_graph)
            return

        # Fallback to serving static viewer files
        super().do_GET()

    def send_json_response(self, status_code, data):
        payload = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(payload)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/api/relations", "/api/entities", "/api/memory_entities"):
            length = int(self.headers.get("Content-Length", 0))
            body_bytes = self.rfile.read(length) if length > 0 else b"{}"
            try:
                payload = json.loads(body_bytes.decode("utf-8"))
            except Exception as e:
                self.send_json_response(400, {"error": f"Invalid JSON: {e}"})
                return

            table = path.replace("/api/", "")
            if not (self.supabase_url and self.supabase_key):
                fake_id = payload.get("id") or f"demo_{table}_{int(time.time() * 1000)}"
                result = {**payload, "id": fake_id, "created_at": "2026-11-19T21:45:00Z"}
                self.send_json_response(201, {"status": "ok", "demo": True, "data": result})
                return

            rest_url = f"{self.supabase_url}/rest/v1/{table}"
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
                "Prefer": "return=representation"
            }
            req = urllib.request.Request(rest_url, data=body_bytes, headers=headers, method="POST")
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    resp_data = json.loads(resp.read().decode("utf-8"))
                    item = resp_data[0] if isinstance(resp_data, list) and resp_data else resp_data
                    KnowledgeGraphProxyHandler.cached_graph = None
                    self.send_json_response(201, {"status": "ok", "data": item})
            except urllib.error.HTTPError as e:
                err_text = e.read().decode("utf-8")
                self.send_json_response(e.code, {"error": err_text})
            except Exception as e:
                self.send_json_response(500, {"error": str(e)})
            return

        self.send_json_response(404, {"error": "Not found"})

    def do_DELETE(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/api/relations", "/api/entities"):
            table = path.replace("/api/", "")
            qs = urllib.parse.parse_qs(parsed.query)
            item_id = qs.get("id", [None])[0]
            if not item_id:
                self.send_json_response(400, {"error": "Missing id parameter"})
                return

            if not (self.supabase_url and self.supabase_key):
                self.send_json_response(200, {"status": "ok", "demo": True})
                return

            rest_url = f"{self.supabase_url}/rest/v1/{table}?id=eq.{item_id}"
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}"
            }
            req = urllib.request.Request(rest_url, headers=headers, method="DELETE")
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    KnowledgeGraphProxyHandler.cached_graph = None
                    self.send_json_response(200, {"status": "ok"})
            except Exception as e:
                self.send_json_response(500, {"error": str(e)})
            return

        self.send_json_response(404, {"error": "Not found"})

    def log_message(self, format, *args):
        # Quiet standard HTTP logs
        sys.stderr.write(f"[{self.log_date_time_string()}] {args[0]} - {args[1]}\n")

def main():
    parser = argparse.ArgumentParser(description="Raymond Knowledge Graph Viewer & Proxy Tool")
    parser.add_argument("port", nargs="?", type=int, default=8080, help="Port to serve web viewer on (default: 8080)")
    parser.add_argument("--url", help="Supabase project URL (e.g. https://xyz.supabase.co)")
    parser.add_argument("--key", help="Supabase API key (anon or service role)")
    parser.add_argument("--json", action="store_true", help="Print graph JSON representation to stdout and exit")
    parser.add_argument("--dump", help="Save graph JSON representation to specified file and exit")
    parser.add_argument("--test", action="store_true", help="Test connection to Supabase and print stats")

    args = parser.parse_args()

    url, key, source = discover_credentials(args.url, args.key)

    if args.json or args.dump or args.test:
        if not (url and key):
            print("❌ Error: Could not find Supabase credentials.", file=sys.stderr)
            print("Please provide --url and --key or set them in .env or ~/.gemini/config/mcp_config.json", file=sys.stderr)
            sys.exit(1)

        print(f"🔗 Connecting to Supabase: {url} (via {source})...", file=sys.stderr)
        try:
            graph_data = fetch_graph_from_edge_or_db(url, key)
        except Exception as e:
            print(f"❌ Error fetching graph: {e}", file=sys.stderr)
            sys.exit(1)

        if args.test:
            stats = graph_data.get("stats", {})
            mem_count = stats.get('memory_count', 0)
            unlinked_cnt = stats.get('unlinked_memory_count')
            if unlinked_cnt is None:
                mem_ents = graph_data.get('memory_entities', [])
                rels = graph_data.get('relations', [])
                mems = graph_data.get('memories', [])
                linked_mems = set(me.get('memory_id') for me in mem_ents if me.get('memory_id'))
                for r in rels:
                    if r.get('memory_id'):
                        linked_mems.add(r.get('memory_id'))
                unlinked_cnt = len([m for m in mems if m.get('id') not in linked_mems])
            grounded_cnt = mem_count - unlinked_cnt

            print("✅ Successfully connected!")
            print(f"📊 Graph Statistics:")
            print(f"   • Total Entities:        {stats.get('entity_count', 0)}")
            print(f"   • Total Relations:       {stats.get('relation_count', 0)}")
            print(f"   • Active Relations:      {stats.get('active_relations', 0)}")
            print(f"   • Superseded Relations:  {stats.get('superseded_relations', 0)}")
            print(f"   • Total Memories:        {mem_count}")
            print(f"   • Grounded in KG:        {grounded_cnt}")
            print(f"   • Unlinked (Gray Nodes): {unlinked_cnt}")
            print(f"   • Source Endpoint:       {graph_data.get('source_endpoint')}")
            sys.exit(0)

        json_str = json.dumps(graph_data, indent=2)
        if args.dump:
            with open(args.dump, "w", encoding="utf-8") as f:
                f.write(json_str)
            print(f"✅ Saved Knowledge Graph JSON to {args.dump}", file=sys.stderr)
            sys.exit(0)

        if args.json:
            print(json_str)
            sys.exit(0)

    # Web Server Mode
    KnowledgeGraphProxyHandler.supabase_url = url
    KnowledgeGraphProxyHandler.supabase_key = key
    KnowledgeGraphProxyHandler.auth_source = source

    os.chdir(DIRECTORY)
    with ReusableTCPServer(("", args.port), KnowledgeGraphProxyHandler) as httpd:
        print("=" * 65)
        print("🕸️  Raymond Knowledge Graph Viewer & Proxy")
        print(f"    👉  Web Viewer UI: http://localhost:{args.port}")
        print(f"    👉  JSON Endpoint: http://localhost:{args.port}/api/graph")
        if url:
            print(f"    🔗  Supabase Host:  {url}")
            print(f"    🔑  Auth Source:    {source}")
        else:
            print("    ⚠️   Warning: No credentials detected. Running in Demo Mode.")
        print("=" * 65)
        print("Press Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")

if __name__ == "__main__":
    main()
