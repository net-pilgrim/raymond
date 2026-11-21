# Raymond Knowledge Graph Visualizer & Explorer

An interactive, zero-dependency graphical browser for multi-agent knowledge graphs and grounded memories.

![Raymond Knowledge Graph Viewer](data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">🕸️</text></svg>)

## 🚀 Quick Start (Zero Runtime Needed)

### Option 1: Live Hosted GitHub Pages Viewer (Recommended)
The interactive viewer is deployed live on GitHub Pages:
- 🌐 **Web App**: [`https://net-pilgrim.github.io/raymond/`](https://net-pilgrim.github.io/raymond/)
- **1-Click Launch**: Run `./open-viewer.sh` from the repository root to automatically open the GitHub Pages app in your default browser with your credentials auto-connected.
- **Connect**: Click **Settings** to enter your Supabase URL & Key (stored in your browser's `localStorage` only), or click **Load Demo Graph** to explore offline.

### Option 2: Local Standalone File (`file://`)
Run `./open-viewer.sh --local` or double-click `viewer/index.html` to open directly as a local file with no web server.
- **Offline Drag-and-Drop**: Drag any `graph.json` directly onto the canvas or click **Import JSON** to inspect without credentials.

### Option 3: Optional Python CLI Helper
If you prefer CLI workflows or piping JSON output to scripts:

```bash
# Output graph JSON representation directly to stdout
python3 viewer/serve.py --json

# Save graph JSON representation to a file
python3 viewer/serve.py --dump graph.json

# Test connection and view statistics
python3 viewer/serve.py --test

# Optional local proxy server
python3 viewer/serve.py 8080
```

---

## 🎨 Key Features

- **Interactive Force-Directed & DAG Layouts**:
  - Physics-based organic graph visualization powered by Vis Network.
  - Toggle between dynamic force-directed physics and hierarchical directed acyclic graph (DAG) mode.
  - Physics stabilization and freeze/unfreeze controls.
- **Drag-to-Connect Interactive Relation Creation**:
  - Drag any node onto another node to instantly create a directed **`connected_to`** relation.
  - Real-time drop-target snapping indicator with target name preview.
  - Non-blocking action toast with instant **`Undo`** support.
  - Automatically promotes and grounds unlinked gray memory nodes into active connected entities when dragged onto entities.
  - Persists directly to Supabase (`public.relations`) via local proxy or PostgREST.
- **Entity Type Color Theming & Gray Memory Nodes**:
  - Distinct colors and badges for `concept`, `component`, `technology`, `decision`, `agent`, `system`, and `tool`.
  - **Gray Nodes for Unlinked Memories**: Memories stored in the database that are not yet grounded into KG entities or relations appear as distinct **gray nodes** (`memory` type). Clicking them opens the inspector drawer showing their full Markdown content and grounding guidelines.
- **Temporal Validity & Relation Tracking**:
  - Directed edges labeled with predicates (`uses`, `depends_on`, `protects`, `implements`, `replaces`).
  - Visual distinction between **Active** relations (solid vibrant edges) and **Superseded** relations (dashed red/muted lines with `valid_to` timestamps).
- **Search & Auto-Focus**:
  - Real-time fuzzy autocomplete search over entity names, types, and aliases.
  - Selecting any search result flies the camera to the node with spring animation and opens its inspector.
- **1-Hop / 2-Hop Neighborhood Isolation**:
  - Double-click any node (or click "Focus 1-Hop" in the inspector) to isolate its immediate neighborhood.
- **Slide-Out Inspector Drawer**:
  - **Entity Details**: Type badge, aliases, degree count, and raw metadata.
  - **Relations Explorer**: Lists all incoming and outgoing relations with clickable neighbor links.
  - **Grounded Memories**: Displays all memories linked to the entity (author agent, category, tags, created timestamp, full content snippet).
- **Offline Demo Dataset**:
  - Comes with a realistic pre-loaded multi-agent software architecture graph so you can test the viewer immediately without needing database credentials.
- **Exporting**:
  - Export the graph view as a high-resolution PNG screenshot with 1 click.
