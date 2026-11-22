<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import type { KnowledgeGraphData, Entity, Relation } from '../types';
  import { Network } from 'vis-network';
  import { DataSet } from 'vis-data';
  import {
    Search, ZoomIn, ZoomOut, Maximize2, Play, Pause, GitFork,
    Activity, Camera, Eye, EyeOff, RotateCcw, X, Undo2, Link2
  } from '@lucide/svelte';

  export let graphData: KnowledgeGraphData;
  export let onSelectEntity: (entity: any) => void;
  export let onOpenConnectModal: (sourceEntityId?: string) => void = () => {};

  export function focusNeighborhood(entityId: string) {
    focusCenterEntityId = entityId;
    focusHopDepth = 1;
    updateGraph();
    if (network) {
      network.focus(entityId, { scale: 1.2, animation: { duration: 500, easingFunction: 'easeInOutQuad' } });
    }
  }

  let container: HTMLDivElement;
  let network: Network | null = null;
  let nodesDataSet = new DataSet<any>([]);
  let edgesDataSet = new DataSet<any>([]);
  let lastGraphDataRef: KnowledgeGraphData | null = null;

  let isPhysicsActive = true;
  let isDagMode = false;
  let showSuperseded = true;
  let searchQuery = '';

  // Hop Focus Neighborhood Mode
  let focusCenterEntityId: string | null = null;
  let focusHopDepth = 1;
  let focusCenterName = '';

  // Type Filters
  let activeTypeFilters: Set<string> = new Set();

  // Drag-to-Connect Floating Indicator
  let isDraggingNode = false;
  let dropTargetName = '';
  let dropPillX = 0;
  let dropPillY = 0;
  let showDropPill = false;

  // Non-blocking Toast Notification
  let toastMessage = '';
  let toastType: 'info' | 'success' | 'warning' = 'info';
  let toastAction: { label: string; onClick: () => void } | null = null;
  let showToast = false;
  let toastTimeout: any = null;

  // Graph topology stats
  let visibleEntitiesCount = 0;
  let visibleRelationsCount = 0;
  let supersededRelationsCount = 0;

  const TYPE_STYLES: Record<string, { bg: string; border: string; highlight: string }> = {
    concept: { bg: '#8b5cf6', border: '#a78bfa', highlight: '#c4b5fd' },
    component: { bg: '#0284c7', border: '#38bdf8', highlight: '#7dd3fc' },
    technology: { bg: '#059669', border: '#34d399', highlight: '#6ee7b7' },
    decision: { bg: '#d97706', border: '#fbbf24', highlight: '#fde68a' },
    agent: { bg: '#e11d48', border: '#fb7185', highlight: '#fda4af' },
    system: { bg: '#4f46e5', border: '#818cf8', highlight: '#a5b4fc' },
    tool: { bg: '#0d9488', border: '#2dd4bf', highlight: '#5eead4' },
    algorithm: { bg: '#ec4899', border: '#f472b6', highlight: '#fbfe8' },
    protocol: { bg: '#06b6d4', border: '#67e8f9', highlight: '#cffafe' },
    library: { bg: '#3b82f6', border: '#60a5fa', highlight: '#bfdbfe' },
    memory: { bg: '#475569', border: '#94a3b8', highlight: '#cbd5e1' },
    default: { bg: '#334155', border: '#64748b', highlight: '#94a3b8' }
  };

  function getTypeStyle(type: string) {
    const key = (type || 'concept').toLowerCase();
    if (TYPE_STYLES[key]) return TYPE_STYLES[key];
    let hash = 0;
    for (let i = 0; i < key.length; i++) hash = key.charCodeAt(i) + ((hash << 5) - hash);
    const h = Math.abs(hash) % 360;
    return {
      bg: `hsl(${h}, 65%, 48%)`,
      border: `hsl(${h}, 75%, 68%)`,
      highlight: `hsl(${h}, 85%, 82%)`
    };
  }

  function triggerToast(msg: string, type: 'info' | 'success' | 'warning' = 'info', action?: { label: string; onClick: () => void }) {
    toastMessage = msg;
    toastType = type;
    toastAction = action || null;
    showToast = true;
    if (toastTimeout) clearTimeout(toastTimeout);
    toastTimeout = setTimeout(() => {
      showToast = false;
    }, 5500);
  }

  // --- UNLINKED MEMORY EXTRACTION ---
  function getUnlinkedMemoryEntities(): Entity[] {
    const linkedMemIds = new Set<string>();
    const existingEntityIds = new Set((graphData.entities || []).map(e => e.id));

    (graphData.memory_entities || []).forEach(me => {
      if (me.memory_id && existingEntityIds.has(me.entity_id)) linkedMemIds.add(me.memory_id);
    });
    (graphData.relations || []).forEach((r: any) => {
      if (r.memory_id) linkedMemIds.add(r.memory_id);
    });

    return (graphData.memories || [])
      .filter(m => !linkedMemIds.has(m.id))
      .map(m => {
        const firstLine = (m.content || '').split('\n').find(l => l.trim().length > 0) || '';
        const cleaned = firstLine.replace(/^[#*\-\d.\s]+/, '').trim();
        const label = cleaned.length <= 28 ? (cleaned || `Memory (${m.category || 'general'})`) : cleaned.slice(0, 26) + '…';
        return {
          id: m.id,
          name: label,
          type: 'memory',
          aliases: m.tags || [],
          content: m.content,
          agent_id: m.agent_id || m.author_agent,
          author_agent: m.agent_id || m.author_agent,
          metadata: {
            ...m,
            memory_id: m.id,
            category: m.category,
            agent_id: m.agent_id || m.author_agent,
            author_agent: m.agent_id || m.author_agent,
            created_at: m.created_at,
            full_content: m.content,
            is_unlinked_memory: true
          }
        };
      });
  }

  // --- NEIGHBORHOOD ISOLATION (1-HOP / 2-HOP) ---
  function computeHopNeighborhood(centerId: string, maxHops = 1): Set<string> {
    const visited = new Set<string>([centerId]);
    let currentBorder = new Set<string>([centerId]);

    for (let hop = 0; hop < maxHops; hop++) {
      const nextBorder = new Set<string>();
      for (const rel of (graphData.relations || [])) {
        if (!showSuperseded && rel.valid_to) continue;
        const src = rel.src || (rel as any).source_id;
        const dst = rel.dst || (rel as any).target_id;
        if (!src || !dst) continue;

        if (currentBorder.has(src) && !visited.has(dst)) {
          visited.add(dst);
          nextBorder.add(dst);
        }
        if (currentBorder.has(dst) && !visited.has(src)) {
          visited.add(src);
          nextBorder.add(src);
        }
      }
      currentBorder = nextBorder;
      if (currentBorder.size === 0) break;
    }
    return visited;
  }

  function getNodeDisplayName(nodeId: string): string {
    const ent = (graphData.entities || []).find(e => e.id === nodeId);
    if (ent) return ent.name;
    const mem = getUnlinkedMemoryEntities().find(m => m.id === nodeId);
    if (mem) return mem.name;
    return nodeId;
  }

  // --- GRAPH RENDERING & DATASET UPDATES ---
  function updateGraph() {
    if (!network || !graphData) return;

    const unlinkedMems = getUnlinkedMemoryEntities();
    const allGraphNodes = [...(graphData.entities || []), ...unlinkedMems];

    // 1. Hop Neighborhood Filtering
    let allowedEntityIds: Set<string> | null = null;
    if (focusCenterEntityId) {
      allowedEntityIds = computeHopNeighborhood(focusCenterEntityId, focusHopDepth);
      const center = allGraphNodes.find(e => e.id === focusCenterEntityId);
      focusCenterName = center ? center.name : focusCenterEntityId;
    }

    // 2. Filter Entities by Type & Neighborhood
    const filteredEntities = allGraphNodes.filter(ent => {
      if (allowedEntityIds && !allowedEntityIds.has(ent.id)) return false;
      if (activeTypeFilters.size > 0 && !activeTypeFilters.has((ent.type || 'concept').toLowerCase())) return false;
      return true;
    });

    const visibleEntityIds = new Set(filteredEntities.map(e => e.id));

    // 3. Filter Relations
    let supCount = 0;
    const filteredRelations = (graphData.relations || []).filter(rel => {
      const src = rel.src || (rel as any).source_id;
      const dst = rel.dst || (rel as any).target_id;
      if (!src || !dst) return false;

      const isSuperseded = Boolean(rel.valid_to);
      if (isSuperseded) supCount++;
      if (!showSuperseded && isSuperseded) return false;
      if (!visibleEntityIds.has(src) || !visibleEntityIds.has(dst)) return false;
      return true;
    });

    supersededRelationsCount = supCount;
    visibleEntitiesCount = filteredEntities.length;
    visibleRelationsCount = filteredRelations.length;

    // 4. Degree Map for dynamic node sizing
    const degreeMap = new Map<string, number>();
    (graphData.relations || []).forEach(r => {
      const src = r.src || (r as any).source_id;
      const dst = r.dst || (r as any).target_id;
      if (src && dst && (!r.valid_to || showSuperseded)) {
        degreeMap.set(src, (degreeMap.get(src) || 0) + 1);
        degreeMap.set(dst, (degreeMap.get(dst) || 0) + 1);
      }
    });

    // 5. Vis Nodes
    const nodeItems = filteredEntities.map(ent => {
      const style = getTypeStyle(ent.type);
      const degree = degreeMap.get(ent.id) || 0;
      const isMemory = ent.type === 'memory';
      const nodeSize = isMemory ? 14 : Math.min(36, Math.max(16, 16 + degree * 2.2));

      return {
        id: ent.id,
        label: ent.name || ent.id,
        shape: isMemory ? 'box' : 'dot',
        size: isMemory ? undefined : nodeSize,
        borderWidth: 2,
        color: {
          background: style.bg,
          border: style.border,
          highlight: {
            background: style.highlight,
            border: '#ffffff'
          }
        },
        font: {
          color: '#f8fafc',
          face: 'Plus Jakarta Sans',
          size: isMemory ? 11 : (degree >= 5 ? 14 : 12),
          strokeWidth: 3,
          strokeColor: '#090d16'
        },
        margin: isMemory ? 7 : undefined,
        shadow: {
          enabled: true,
          color: style.bg,
          size: degree >= 4 ? 20 : 10,
          x: 0,
          y: 0
        },
        data: ent
      };
    });

    // 6. Vis Edges
    const edgeItems = filteredRelations.map(rel => {
      const src = rel.src || (rel as any).source_id;
      const dst = rel.dst || (rel as any).target_id;
      const isSuperseded = Boolean(rel.valid_to);

      return {
        id: rel.id,
        from: src,
        to: dst,
        label: rel.predicate,
        arrows: {
          to: { enabled: true, scaleFactor: 0.85 }
        },
        dashes: isSuperseded ? [5, 5] : false,
        width: isSuperseded ? 1.5 : (rel.predicate === 'implements' || rel.predicate === 'enforces' ? 2.5 : 2),
        color: {
          color: isSuperseded ? '#ef4444' : 'rgba(56, 189, 248, 0.75)',
          highlight: isSuperseded ? '#fda4af' : '#67e8f9',
          opacity: isSuperseded ? 0.45 : 0.95
        },
        font: {
          color: isSuperseded ? '#fca5a5' : '#94a3b8',
          face: 'JetBrains Mono',
          size: 10,
          strokeColor: '#090d16',
          strokeWidth: 3,
          align: 'middle'
        },
        data: rel
      };
    });

    // Update persistent DataSets in-place to completely prevent screen flickering
    nodesDataSet.clear();
    nodesDataSet.add(nodeItems);
    edgesDataSet.clear();
    edgesDataSet.add(edgeItems);
  }

  // --- INITIALIZE VIS NETWORK ONCE ---
  function initNetwork() {
    if (!container || network) return;

    const data = {
      nodes: nodesDataSet,
      edges: edgesDataSet
    };

    const options = {
      physics: {
        enabled: isPhysicsActive,
        solver: 'forceAtlas2Based',
        forceAtlas2Based: {
          gravitationalConstant: -70,
          centralGravity: 0.01,
          springLength: 130,
          springConstant: 0.08,
          damping: 0.7,
          avoidOverlap: 0.8
        },
        stabilization: {
          iterations: 140,
          updateInterval: 25
        }
      },
      layout: {
        hierarchical: isDagMode ? {
          direction: 'UD',
          sortMethod: 'directed',
          levelSeparation: 130,
          nodeSpacing: 160
        } : false
      },
      interaction: {
        hover: true,
        tooltipDelay: 120,
        zoomView: true,
        dragView: true
      }
    };

    network = new Network(container, data, options as any);

    // Click handler
    network.on('click', params => {
      if (params.nodes && params.nodes.length > 0) {
        const nodeId = params.nodes[0];
        const allGraphNodes = [...(graphData?.entities || []), ...getUnlinkedMemoryEntities()];
        const ent = allGraphNodes.find(e => e.id === nodeId);
        if (ent) onSelectEntity(ent);
      } else if (params.edges && params.edges.length > 0) {
        const edgeId = params.edges[0];
        const rel = (graphData?.relations || []).find(r => r.id === edgeId);
        if (rel) {
          onSelectEntity(rel);
        }
      }
    });

    // Double-click handler for 1-hop neighborhood isolation
    network.on('doubleClick', params => {
      if (params.nodes && params.nodes.length > 0) {
        const nodeId = params.nodes[0];
        focusCenterEntityId = (focusCenterEntityId === nodeId) ? null : nodeId;
        focusHopDepth = 1;
        updateGraph();
        network?.focus(nodeId, { scale: 1.2, animation: { duration: 500, easingFunction: 'easeInOutQuad' } });
      }
    });

    // Hover cursor
    network.on('hoverNode', () => { if (container) container.style.cursor = 'pointer'; });
    network.on('blurNode', () => { if (container) container.style.cursor = 'default'; });

    // Drag-to-Connect Interaction
    let draggedNodeId: string | null = null;
    let hoverTargetNodeId: string | null = null;

    network.on('dragStart', params => {
      if (params.nodes && params.nodes.length > 0) {
        draggedNodeId = params.nodes[0];
        network?.setOptions({ physics: { enabled: false } });
      } else {
        draggedNodeId = null;
      }
      hoverTargetNodeId = null;
    });

    network.on('dragging', params => {
      if (!draggedNodeId || !network) return;
      const pointerCanvas = params.pointer.canvas;
      const allPositions = network.getPositions();
      let closestId: string | null = null;
      let minDist = Infinity;

      for (const [id, pos] of Object.entries(allPositions)) {
        if (id === draggedNodeId) continue;
        const d = Math.hypot(pos.x - pointerCanvas.x, pos.y - pointerCanvas.y);
        if (d < minDist) {
          minDist = d;
          closestId = id;
        }
      }

      if (closestId && minDist <= 55) {
        hoverTargetNodeId = closestId;
        dropTargetName = getNodeDisplayName(closestId);
        dropPillX = params.pointer.DOM.x + 18;
        dropPillY = params.pointer.DOM.y - 14;
        showDropPill = true;
        if (container) container.style.cursor = 'copy';
      } else {
        hoverTargetNodeId = null;
        showDropPill = false;
        if (container) container.style.cursor = 'pointer';
      }
    });

    network.on('dragEnd', params => {
      showDropPill = false;
      if (container) container.style.cursor = 'default';

      if (draggedNodeId && hoverTargetNodeId && draggedNodeId !== hoverTargetNodeId) {
        handleDropConnect(draggedNodeId, hoverTargetNodeId);
      }

      if (isPhysicsActive) {
        network?.setOptions({ physics: { enabled: true } });
      }
      draggedNodeId = null;
      hoverTargetNodeId = null;
    });

    updateGraph();
  }

  // --- DRAG-TO-CONNECT RELATION CREATION ---
  async function handleDropConnect(srcId: string, dstId: string) {
    if (srcId === dstId) return;

    const existing = (graphData.relations || []).find(r => {
      const s = r.src || (r as any).source_id;
      const d = r.dst || (r as any).target_id;
      return !r.valid_to && ((s === srcId && d === dstId) || (s === dstId && d === srcId)) && r.predicate === 'connected_to';
    });

    if (existing) {
      triggerToast('Nodes are already linked with "connected_to"', 'info');
      return;
    }

    const srcName = getNodeDisplayName(srcId);
    const dstName = getNodeDisplayName(dstId);

    const newRel: Relation = {
      id: 'rel_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6),
      src: srcId,
      dst: dstId,
      predicate: 'connected_to',
      valid_from: new Date().toISOString(),
      valid_to: null,
      metadata: { created_via: 'drag_and_drop', created_at: new Date().toISOString() }
    };

    graphData.relations = [...(graphData.relations || []), newRel];
    updateGraph();

    triggerToast(`Connected <b>${srcName}</b> ➔ <code>connected_to</code> ➔ <b>${dstName}</b>`, 'success', {
      label: 'Undo',
      onClick: () => {
        graphData.relations = graphData.relations.filter(r => r.id !== newRel.id);
        updateGraph();
        triggerToast('Link creation undone', 'info');
      }
    });
  }

  // --- CONTROLS ---
  function togglePhysics() {
    isPhysicsActive = !isPhysicsActive;
    if (network) network.setOptions({ physics: { enabled: isPhysicsActive } });
  }

  function toggleDagMode() {
    isDagMode = !isDagMode;
    if (network) {
      network.setOptions({
        layout: {
          hierarchical: isDagMode ? {
            direction: 'UD',
            sortMethod: 'directed',
            levelSeparation: 130,
            nodeSpacing: 160
          } : false
        }
      });
      updateGraph();
    }
  }

  function toggleSuperseded() {
    showSuperseded = !showSuperseded;
    updateGraph();
  }

  function clearFocusMode() {
    focusCenterEntityId = null;
    updateGraph();
    setTimeout(fitGraph, 200);
  }

  function setHopDepth(depth: number) {
    focusHopDepth = depth;
    updateGraph();
  }

  function toggleTypeFilter(type: string) {
    const key = type.toLowerCase();
    if (activeTypeFilters.has(key)) {
      activeTypeFilters.delete(key);
    } else {
      activeTypeFilters.add(key);
    }
    activeTypeFilters = new Set(activeTypeFilters);
    updateGraph();
  }

  function handleSearch() {
    if (!network || !searchQuery.trim()) return;
    const q = searchQuery.toLowerCase();
    const found = (graphData.entities || []).find(
      e => e.name.toLowerCase().includes(q) || e.id.toLowerCase().includes(q)
    );
    if (found) {
      network.focus(found.id, { scale: 1.4, animation: { duration: 600, easingFunction: 'easeInOutQuad' } });
      onSelectEntity(found);
    }
  }

  function zoomIn() {
    if (!network) return;
    network.moveTo({ scale: network.getScale() * 1.3, animation: { duration: 250, easingFunction: 'easeInOutQuad' } });
  }

  function zoomOut() {
    if (!network) return;
    network.moveTo({ scale: network.getScale() / 1.3, animation: { duration: 250, easingFunction: 'easeInOutQuad' } });
  }

  function fitGraph() {
    if (!network) return;
    network.fit({ animation: { duration: 500, easingFunction: 'easeInOutQuad' } });
  }

  function exportCanvasToPng() {
    if (!container) return;
    const canvas = container.querySelector('canvas');
    if (!canvas) return;
    const link = document.createElement('a');
    link.download = `raymond-knowledge-graph-${Date.now()}.png`;
    link.href = canvas.toDataURL('image/png');
    link.click();
    triggerToast('Screenshot exported successfully!', 'success');
  }

  // Reactive data sync when graphData prop changes externally
  $: if (network && graphData && graphData !== lastGraphDataRef) {
    lastGraphDataRef = graphData;
    updateGraph();
  }

  onMount(() => {
    initNetwork();
  });

  onDestroy(() => {
    if (network) {
      network.destroy();
      network = null;
    }
    if (toastTimeout) clearTimeout(toastTimeout);
  });
</script>

<div class="graph-wrapper">
  <!-- Top Toolbar -->
  <div class="graph-toolbar">
    <div class="left-tools">
      <div class="search-box">
        <Search size={14} class="search-icon" />
        <input
          type="text"
          bind:value={searchQuery}
          placeholder="Search entities, components, technologies..."
          on:keydown={e => e.key === 'Enter' && handleSearch()}
        />
      </div>

      <div class="stats-pill font-mono">
        <Activity size={13} class="stats-icon" />
        <span class="count-num">{visibleEntitiesCount}</span> entities
        <span class="dot">·</span>
        <span class="count-num cyan">{visibleRelationsCount}</span> relations
      </div>
    </div>

    <div class="right-tools">
      <button
        class="tool-btn link-action-btn"
        on:click={() => onOpenConnectModal('')}
        title="Manually connect two entities"
      >
        <Link2 size={13} />
        <span>+ Link</span>
      </button>

      <button
        class="tool-btn"
        class:active={showSuperseded}
        on:click={toggleSuperseded}
        title="Toggle superseded historical relations ({supersededRelationsCount} links)"
      >
        {#if showSuperseded}
          <Eye size={13} />
          <span>Superseded ({supersededRelationsCount})</span>
        {:else}
          <EyeOff size={13} />
          <span>Superseded ({supersededRelationsCount})</span>
        {/if}
      </button>

      <button
        class="tool-btn"
        class:active={isDagMode}
        on:click={toggleDagMode}
        title="Toggle Hierarchical DAG Mode"
      >
        <GitFork size={13} />
        <span>{isDagMode ? 'DAG Mode' : 'Organic'}</span>
      </button>

      <button class="tool-btn" on:click={togglePhysics} title="Freeze/Resume Physics Simulation">
        {#if isPhysicsActive}
          <Pause size={13} />
          <span>Freeze</span>
        {:else}
          <Play size={13} />
          <span>Physics</span>
        {/if}
      </button>

      <button class="tool-btn" on:click={exportCanvasToPng} title="Export PNG Screenshot">
        <Camera size={13} />
        <span>Screenshot</span>
      </button>

      <div class="zoom-controls">
        <button class="zoom-btn" on:click={zoomIn} title="Zoom In"><ZoomIn size={14} /></button>
        <button class="zoom-btn" on:click={zoomOut} title="Zoom Out"><ZoomOut size={14} /></button>
        <button class="zoom-btn" on:click={fitGraph} title="Fit to Screen"><Maximize2 size={14} /></button>
      </div>
    </div>
  </div>

  <!-- Neighborhood Focus Banner -->
  {#if focusCenterEntityId}
    <div class="focus-banner font-mono">
      <div class="focus-info">
        <span class="focus-badge">Neighborhood Focus</span>
        <span class="focus-target">{focusCenterName}</span>
      </div>
      <div class="hop-toggle-group">
        <button class="hop-btn" class:active={focusHopDepth === 1} on:click={() => setHopDepth(1)}>1-Hop</button>
        <button class="hop-btn" class:active={focusHopDepth === 2} on:click={() => setHopDepth(2)}>2-Hop</button>
        <button class="clear-focus-btn" on:click={clearFocusMode} title="Reset to full graph view">
          <X size={13} />
          <span>Show Full Graph</span>
        </button>
      </div>
    </div>
  {/if}

  <!-- Entity Type Filter Chips -->
  <div class="type-filter-bar">
    {#each ['concept', 'component', 'technology', 'decision', 'agent', 'system', 'tool', 'memory'] as type}
      {@const style = getTypeStyle(type)}
      {@const isActive = activeTypeFilters.size === 0 || activeTypeFilters.has(type)}
      <button
        class="type-chip font-mono"
        class:active={isActive}
        style="border-color: {style.border}; color: {isActive ? style.border : '#64748b'}; background: {isActive ? 'rgba(15, 23, 42, 0.85)' : 'rgba(15, 23, 42, 0.4)'}"
        on:click={() => toggleTypeFilter(type)}
      >
        <span class="chip-dot" style="background: {style.bg}"></span>
        <span>{type}</span>
      </button>
    {/each}
  </div>

  <!-- Vis Canvas -->
  <div class="vis-canvas" bind:this={container}></div>

  <!-- Drag-to-Connect Floating Drop Snapping Tooltip -->
  {#if showDropPill}
    <div
      class="drop-connect-pill font-mono"
      style="left: {dropPillX}px; top: {dropPillY}px;"
    >
      <Link2 size={13} class="pill-icon" />
      <span>Drop on <b>{dropTargetName}</b> to create <code class="rel-tag">connected_to</code></span>
    </div>
  {/if}

  <!-- Non-blocking Action Toast -->
  {#if showToast}
    <div class="toast-card font-mono" class:success={toastType === 'success'} class:info={toastType === 'info'}>
      <div class="toast-content">
        {@html toastMessage}
      </div>
      {#if toastAction}
        <button class="toast-btn" on:click={toastAction.onClick}>
          <Undo2 size={12} />
          <span>{toastAction.label}</span>
        </button>
      {/if}
    </div>
  {/if}
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
    top: 0.85rem;
    left: 1.25rem;
    right: 1.25rem;
    z-index: 20;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    pointer-events: none;
    flex-wrap: wrap;
  }

  .left-tools, .right-tools {
    pointer-events: auto;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .search-box {
    position: relative;
    display: flex;
    align-items: center;
    width: 290px;
    background: rgba(15, 23, 42, 0.85);
    backdrop-filter: blur(10px);
    border-radius: var(--radius-sm);
  }

  .search-box input {
    width: 100%;
    padding-left: 2rem;
    height: 32px;
    font-size: 0.78rem;
  }

  :global(.search-icon) {
    position: absolute;
    left: 0.65rem;
    color: var(--text-muted);
  }

  .stats-pill {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.25rem 0.6rem;
    font-size: 0.7rem;
    color: var(--text-muted);
    background: rgba(15, 23, 42, 0.85);
    backdrop-filter: blur(10px);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-subtle);
  }

  :global(.stats-icon) {
    color: var(--brand-400);
  }

  .stats-pill .count-num {
    font-weight: 700;
    color: var(--text-primary);
  }

  .stats-pill .count-num.cyan {
    color: var(--cyan-400);
  }

  .right-tools {
    background: rgba(15, 23, 42, 0.85);
    backdrop-filter: blur(10px);
    padding: 3px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-subtle);
  }

  .tool-btn {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.3rem 0.6rem;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-secondary);
    font-size: 0.72rem;
  }

  .tool-btn.link-action-btn {
    background: rgba(16, 185, 129, 0.15);
    color: var(--brand-400);
    border: 1px solid rgba(16, 185, 129, 0.35);
  }

  .tool-btn.link-action-btn:hover {
    background: rgba(16, 185, 129, 0.3);
    color: #ffffff;
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
    padding-left: 0.25rem;
  }

  .zoom-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-muted);
  }

  .zoom-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    color: var(--text-primary);
  }

  /* Neighborhood Focus Mode Banner */
  .focus-banner {
    position: absolute;
    top: 3.5rem;
    left: 50%;
    transform: translateX(-50%);
    z-index: 25;
    display: flex;
    align-items: center;
    gap: 0.85rem;
    background: rgba(15, 23, 42, 0.95);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(56, 189, 248, 0.4);
    padding: 0.35rem 0.85rem;
    border-radius: var(--radius-full);
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
  }

  .focus-badge {
    font-size: 0.68rem;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--cyan-400);
    padding: 0.15rem 0.4rem;
    background: rgba(56, 189, 248, 0.15);
    border-radius: var(--radius-sm);
  }

  .focus-target {
    font-size: 0.78rem;
    font-weight: 700;
    color: var(--text-primary);
  }

  .hop-toggle-group {
    display: flex;
    align-items: center;
    gap: 0.35rem;
  }

  .hop-btn {
    padding: 0.2rem 0.45rem;
    font-size: 0.68rem;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-secondary);
  }

  .hop-btn.active {
    background: var(--cyan-400);
    color: #030712;
    font-weight: 700;
  }

  .clear-focus-btn {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.2rem 0.5rem;
    font-size: 0.68rem;
    border-radius: var(--radius-sm);
    background: rgba(239, 68, 68, 0.2);
    color: #fca5a5;
    border: 1px solid rgba(239, 68, 68, 0.3);
  }

  .clear-focus-btn:hover {
    background: rgba(239, 68, 68, 0.4);
    color: #ffffff;
  }

  /* Type Filter Chips */
  .type-filter-bar {
    position: absolute;
    bottom: 1rem;
    left: 1.25rem;
    z-index: 20;
    display: flex;
    align-items: center;
    gap: 0.4rem;
    flex-wrap: wrap;
    max-width: 75%;
    pointer-events: auto;
  }

  .type-chip {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.2rem 0.55rem;
    border-radius: var(--radius-full);
    border: 1px solid transparent;
    font-size: 0.68rem;
    font-weight: 600;
    backdrop-filter: blur(8px);
  }

  .type-chip:hover {
    filter: brightness(1.2);
  }

  .chip-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }

  .vis-canvas {
    width: 100%;
    height: 100%;
    background: transparent;
  }

  /* Floating Drag-to-Connect Snapping Tooltip */
  .drop-connect-pill {
    position: fixed;
    z-index: 50;
    pointer-events: none;
    display: flex;
    align-items: center;
    gap: 0.45rem;
    background: rgba(6, 78, 59, 0.95);
    border: 1px solid #10b981;
    color: #a7f3d0;
    padding: 0.35rem 0.65rem;
    border-radius: var(--radius-sm);
    font-size: 0.72rem;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.6);
  }

  :global(.pill-icon) {
    color: #34d399;
  }

  .rel-tag {
    background: rgba(0, 0, 0, 0.3);
    padding: 0.1rem 0.3rem;
    border-radius: 3px;
    color: #ffffff;
  }

  /* Toast */
  .toast-card {
    position: fixed;
    bottom: 3.5rem;
    right: 1.5rem;
    z-index: 60;
    display: flex;
    align-items: center;
    gap: 0.65rem;
    background: rgba(15, 23, 42, 0.95);
    border: 1px solid var(--border-medium);
    padding: 0.55rem 0.85rem;
    border-radius: var(--radius-md);
    font-size: 0.75rem;
    box-shadow: var(--shadow-lg);
  }

  .toast-card.success {
    border-color: rgba(16, 185, 129, 0.5);
    color: var(--text-primary);
  }

  .toast-btn {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.25rem 0.5rem;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.1);
    color: var(--cyan-400);
    font-weight: 700;
  }

  .toast-btn:hover {
    background: rgba(255, 255, 255, 0.2);
    color: #ffffff;
  }
</style>
