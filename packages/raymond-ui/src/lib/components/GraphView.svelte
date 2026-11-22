<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import type { KnowledgeGraphData, Entity } from '../types';
  import { Network } from 'vis-network';
  import { DataSet } from 'vis-data';
  import { Search, ZoomIn, ZoomOut, Maximize2, Play, Pause, GitFork } from '@lucide/svelte';

  export let graphData: KnowledgeGraphData;
  export let onSelectEntity: (entity: any) => void;

  let container: HTMLDivElement;
  let network: Network | null = null;
  let isPhysicsFrozen = false;
  let isDagMode = false;
  let searchQuery = '';

  const TYPE_COLORS: Record<string, { bg: string; border: string; text: string }> = {
    concept: { bg: '#1e3a8a', border: '#3b82f6', text: '#93c5fd' },
    component: { bg: '#064e3b', border: '#10b981', text: '#a7f3d0' },
    technology: { bg: '#4c1d95', border: '#8b5cf6', text: '#ddd6fe' },
    decision: { bg: '#701a75', border: '#d946ef', text: '#f5d0fe' },
    agent: { bg: '#7c2d12', border: '#f97316', text: '#fed7aa' },
    system: { bg: '#134e4a', border: '#14b8a6', text: '#99f6e4' },
    tool: { bg: '#713f12', border: '#eab308', text: '#fef08a' },
    memory: { bg: '#334155', border: '#64748b', text: '#cbd5e1' },
  };

  function initNetwork() {
    if (!container || !graphData) return;

    const nodesArray = graphData.entities.map(e => {
      const color = TYPE_COLORS[e.type] || { bg: '#1e293b', border: '#475569', text: '#e2e8f0' };
      const isMemory = e.type === 'memory';
      return {
        id: e.id,
        label: e.name || e.id,
        shape: isMemory ? 'box' : 'dot',
        size: isMemory ? undefined : 20,
        color: {
          background: color.bg,
          border: color.border,
          highlight: { background: color.border, border: '#ffffff' }
        },
        font: { color: color.text, face: 'Plus Jakarta Sans', size: 12 },
        margin: isMemory ? 8 : undefined,
        borderWidth: 2,
        data: e,
      };
    });

    const edgesArray = graphData.relations.map(r => {
      const isSuperseded = Boolean(r.valid_to);
      return {
        id: r.id,
        from: r.source_id,
        to: r.target_id,
        label: r.predicate,
        arrows: 'to',
        color: {
          color: isSuperseded ? '#f43f5e' : '#38bdf8',
          highlight: '#ffffff',
          opacity: isSuperseded ? 0.45 : 0.85
        },
        dashes: isSuperseded,
        font: { color: '#94a3b8', face: 'JetBrains Mono', size: 10, align: 'middle' },
        data: r,
      };
    });

    const data = {
      nodes: new DataSet(nodesArray),
      edges: new DataSet(edgesArray)
    };

    const options = {
      physics: {
        enabled: !isPhysicsFrozen,
        solver: 'forceAtlas2Based',
        forceAtlas2Based: {
          gravitationalConstant: -45,
          centralGravity: 0.008,
          springLength: 95,
          springConstant: 0.18,
          damping: 0.95
        },
        stabilization: { iterations: 100 }
      },
      layout: {
        hierarchical: isDagMode ? {
          direction: 'UD',
          sortMethod: 'directed',
          levelSeparation: 120,
          nodeSpacing: 160
        } : false
      },
      interaction: {
        hover: true,
        tooltipDelay: 200,
        zoomView: true,
        dragView: true
      }
    };

    if (network) {
      network.destroy();
    }

    network = new Network(container, data, options as any);

    network.on('click', params => {
      if (params.nodes.length > 0) {
        const nodeId = params.nodes[0];
        const ent = graphData.entities.find(e => e.id === nodeId);
        if (ent) onSelectEntity(ent);
      }
    });
  }

  $: if (graphData && container) {
    initNetwork();
  }

  function togglePhysics() {
    isPhysicsFrozen = !isPhysicsFrozen;
    if (network) {
      network.setOptions({ physics: { enabled: !isPhysicsFrozen } });
    }
  }

  function toggleDagMode() {
    isDagMode = !isDagMode;
    initNetwork();
  }

  function handleSearch() {
    if (!network || !searchQuery.trim()) return;
    const q = searchQuery.toLowerCase();
    const found = graphData.entities.find(
      e => e.name.toLowerCase().includes(q) || e.id.toLowerCase().includes(q)
    );
    if (found) {
      network.focus(found.id, { scale: 1.4, animation: { duration: 600, easingFunction: 'easeInOutQuad' } });
      onSelectEntity(found);
    }
  }

  function zoomIn() {
    if (!network) return;
    const scale = network.getScale();
    network.moveTo({ scale: scale * 1.3, animation: { duration: 300 } });
  }

  function zoomOut() {
    if (!network) return;
    const scale = network.getScale();
    network.moveTo({ scale: scale / 1.3, animation: { duration: 300 } });
  }

  function fitGraph() {
    if (!network) return;
    network.fit({ animation: { duration: 500 } });
  }

  onMount(() => {
    initNetwork();
  });

  onDestroy(() => {
    if (network) network.destroy();
  });
</script>

<div class="graph-wrapper">
  <!-- Controls Bar -->
  <div class="graph-toolbar">
    <div class="search-box">
      <Search size={14} class="search-icon" />
      <input
        type="text"
        bind:value={searchQuery}
        placeholder="Find entity or memory..."
        on:keydown={e => e.key === 'Enter' && handleSearch()}
      />
    </div>

    <div class="tools-row">
      <button class="tool-btn" class:active={isDagMode} on:click={toggleDagMode} title="Toggle Hierarchical DAG Mode">
        <GitFork size={14} />
        <span>{isDagMode ? 'DAG Mode' : 'Organic Layout'}</span>
      </button>

      <button class="tool-btn" on:click={togglePhysics} title="Freeze/Unfreeze Physics">
        {#if isPhysicsFrozen}
          <Play size={14} />
          <span>Resume Physics</span>
        {:else}
          <Pause size={14} />
          <span>Freeze Physics</span>
        {/if}
      </button>

      <div class="zoom-controls">
        <button class="zoom-btn" on:click={zoomIn} title="Zoom In">
          <ZoomIn size={14} />
        </button>
        <button class="zoom-btn" on:click={zoomOut} title="Zoom Out">
          <ZoomOut size={14} />
        </button>
        <button class="zoom-btn" on:click={fitGraph} title="Fit to Screen">
          <Maximize2 size={14} />
        </button>
      </div>
    </div>
  </div>

  <!-- Vis Canvas -->
  <div class="vis-canvas" bind:this={container}></div>

  <!-- Legend Overlay -->
  <div class="legend-overlay font-mono">
    <div class="legend-title">Graph Legend</div>
    <div class="legend-grid">
      {#each Object.entries(TYPE_COLORS) as [type, color]}
        <div class="legend-item">
          <span class="legend-dot" style="background: {color.bg}; border-color: {color.border}"></span>
          <span class="legend-name">{type}</span>
        </div>
      {/each}
    </div>
  </div>
</div>

<style>
  .graph-wrapper {
    position: relative;
    width: 100%;
    height: calc(100vh - 56px);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .graph-toolbar {
    position: absolute;
    top: 1rem;
    left: 1.25rem;
    right: 1.25rem;
    z-index: 20;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    pointer-events: none;
  }

  .search-box, .tools-row {
    pointer-events: auto;
  }

  .search-box {
    position: relative;
    display: flex;
    align-items: center;
    width: 280px;
    background: rgba(15, 23, 42, 0.85);
    backdrop-filter: blur(8px);
    border-radius: var(--radius-sm);
  }

  .search-box input {
    width: 100%;
    padding-left: 2rem;
    height: 34px;
    font-size: 0.8rem;
  }

  :global(.search-icon) {
    position: absolute;
    left: 0.65rem;
    color: var(--text-muted);
  }

  .tools-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: rgba(15, 23, 42, 0.85);
    backdrop-filter: blur(8px);
    padding: 3px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-subtle);
  }

  .tool-btn {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.35rem 0.65rem;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-secondary);
    font-size: 0.75rem;
  }

  .tool-btn:hover {
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-primary);
  }

  .tool-btn.active {
    background: rgba(56, 189, 248, 0.2);
    color: var(--cyan-400);
    border: 1px solid rgba(56, 189, 248, 0.35);
  }

  .zoom-controls {
    display: flex;
    align-items: center;
    border-left: 1px solid var(--border-subtle);
    padding-left: 0.35rem;
  }

  .zoom-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-muted);
  }

  .zoom-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    color: var(--text-primary);
  }

  .vis-canvas {
    width: 100%;
    height: 100%;
    background: transparent;
  }

  .legend-overlay {
    position: absolute;
    bottom: 1rem;
    left: 1.25rem;
    background: rgba(15, 23, 42, 0.85);
    backdrop-filter: blur(8px);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md);
    padding: 0.65rem 0.85rem;
    z-index: 20;
    pointer-events: none;
  }

  .legend-title {
    font-size: 0.68rem;
    font-weight: 700;
    color: var(--text-muted);
    margin-bottom: 0.4rem;
    text-transform: uppercase;
  }

  .legend-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 0.35rem 0.75rem;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.68rem;
  }

  .legend-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    border: 1px solid transparent;
  }

  .legend-name {
    color: var(--text-secondary);
  }
</style>
