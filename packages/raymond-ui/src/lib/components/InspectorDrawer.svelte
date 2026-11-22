<script lang="ts">
  import {
    X, Network, FileText, Calendar, Tag, User, Trash2,
    Link2, ArrowRight, ArrowLeft, AlertTriangle, BookOpen, Layers
  } from '@lucide/svelte';
  import { marked } from 'marked';
  import type { Entity, Relation, Memory } from '../types';

  export let selectedItem: any = null;
  export let allEntities: Entity[] = [];
  export let allRelations: Relation[] = [];
  export let allMemories: Memory[] = [];
  export let memoryEntities: Array<{ memory_id: string; entity_id: string }> = [];

  export let onClose: () => void;
  export let onInspectNode: (nodeId: string) => void;
  export let onOpenConnectModal: (sourceEntityId: string) => void;
  export let onFocusNeighborhood: (entityId: string) => void;
  export let onDeleteRelation: (relationId: string) => void;
  export let onDeleteEntity: (entityId: string) => void;

  let showDeleteConfirm = false;

  $: if (selectedItem) {
    showDeleteConfirm = false;
  }

  $: isRelation = Boolean(selectedItem && (selectedItem.predicate || (selectedItem.src && selectedItem.dst)));
  $: isMemory = Boolean(selectedItem && selectedItem.type === 'memory' && !isRelation);
  $: isEntity = Boolean(selectedItem && !isRelation && !isMemory);

  $: relationSrc = isRelation ? (selectedItem.src || selectedItem.source_id) : '';
  $: relationDst = isRelation ? (selectedItem.dst || selectedItem.target_id) : '';
  $: relationPredicate = isRelation ? selectedItem.predicate : '';
  $: relationEvidenceMem = isRelation ? (allMemories || []).find(m => m.id === selectedItem.memory_id || m.id === selectedItem.metadata?.memory_id || m.id === selectedItem.metadata?.grounded_memory_id) : null;

  // Relations matching this entity
  $: outboundRelations = (allRelations || []).filter(r => {
    const src = r.src || (r as any).source_id;
    return selectedItem && src === selectedItem.id;
  });

  $: inboundRelations = (allRelations || []).filter(r => {
    const dst = r.dst || (r as any).target_id;
    return selectedItem && dst === selectedItem.id;
  });

  // Extract Markdown Description on the Entity itself
  $: entityMarkdown = (() => {
    if (!selectedItem || isMemory || isRelation) return '';
    return (
      selectedItem.metadata?.description ||
      selectedItem.metadata?.summary ||
      selectedItem.metadata?.notes ||
      selectedItem.metadata?.content ||
      selectedItem.metadata?.statement ||
      selectedItem.metadata?.details ||
      selectedItem.metadata?.markdown ||
      selectedItem.metadata?.spec ||
      selectedItem.metadata?.text ||
      selectedItem.description ||
      selectedItem.summary ||
      selectedItem.notes ||
      selectedItem.content ||
      ''
    );
  })();

  // Grounded memories
  $: groundedMemories = (() => {
    if (!selectedItem || isMemory || isRelation) return [];
    const entityId = selectedItem.id;
    const memIds = new Set<string>();

    if (selectedItem.metadata?.grounded_memory_id) memIds.add(selectedItem.metadata.grounded_memory_id);
    if (selectedItem.metadata?.memory_id) memIds.add(selectedItem.metadata.memory_id);
    if (selectedItem.metadata?.source_memory_id) memIds.add(selectedItem.metadata.source_memory_id);

    (memoryEntities || []).forEach(me => {
      if (me.entity_id === entityId) memIds.add(me.memory_id);
    });

    outboundRelations.concat(inboundRelations).forEach((r: any) => {
      if (r.memory_id) memIds.add(r.memory_id);
      if (r.metadata?.memory_id) memIds.add(r.metadata.memory_id);
      if (r.metadata?.grounded_memory_id) memIds.add(r.metadata.grounded_memory_id);
    });

    return (allMemories || []).filter(m => memIds.has(m.id));
  })();

  function getEntityName(id: string): string {
    const ent = allEntities.find(e => e.id === id);
    return ent ? ent.name : id;
  }

  function renderMarkdown(md: string): string {
    if (!md) return '';
    try {
      return marked.parse(String(md), { gfm: true, breaks: true, async: false }) as string;
    } catch (_) {
      return String(md);
    }
  }

  function formatTime(iso: string) {
    try {
      const d = new Date(iso);
      return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } catch (_) {
      return iso;
    }
  }
</script>

{#if selectedItem}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="drawer-backdrop" on:click={onClose}>
    <div class="drawer-panel" on:click|stopPropagation>
      <!-- Header -->
      <div class="drawer-header">
        <div class="header-main">
          {#if isRelation}
            <span class="type-badge font-mono relation">relation</span>
            <h2 class="item-title font-mono">{getEntityName(relationSrc)} ➔ {relationPredicate} ➔ {getEntityName(relationDst)}</h2>
          {:else}
            <span class="type-badge font-mono">{selectedItem.type || 'entity'}</span>
            <h2 class="item-title">{selectedItem.name || selectedItem.id}</h2>
          {/if}
        </div>
        <div class="header-actions">
          {#if isEntity}
            <button
              class="hdr-btn"
              on:click={() => onFocusNeighborhood(selectedItem.id)}
              title="Focus 1-Hop Neighborhood"
            >
              <Network size={14} />
              <span>Focus 1-Hop</span>
            </button>
            <button
              class="hdr-btn primary"
              on:click={() => onOpenConnectModal(selectedItem.id)}
              title="Create Relation from this Entity"
            >
              <Link2 size={14} />
              <span>+ Link</span>
            </button>
          {/if}
          <button class="close-btn" on:click={onClose} title="Close inspector">
            <X size={16} />
          </button>
        </div>
      </div>

      <div class="drawer-content">
        <!-- Relation Details View -->
        {#if isRelation}
          <div class="entity-details">
            <div class="detail-row">
              <span class="label">Predicate</span>
              <span class="val font-mono highlight-predicate">{relationPredicate}</span>
            </div>
            <div class="detail-row">
              <span class="label">Source Node</span>
              <button class="target-link font-sans" on:click={() => onInspectNode(relationSrc)}>
                {getEntityName(relationSrc)}
              </button>
            </div>
            <div class="detail-row">
              <span class="label">Target Node</span>
              <button class="target-link font-sans" on:click={() => onInspectNode(relationDst)}>
                {getEntityName(relationDst)}
              </button>
            </div>
            <div class="detail-row">
              <span class="label">Status</span>
              <span class="val font-mono">
                {#if selectedItem.valid_to}
                  <span class="sup-tag font-mono">superseded ({formatTime(selectedItem.valid_to)})</span>
                {:else}
                  <span class="active-tag font-mono">active (since {formatTime(selectedItem.valid_from)})</span>
                {/if}
              </span>
            </div>
          </div>

          <!-- Grounded Evidence Memory for Relation -->
          {#if relationEvidenceMem}
            <div class="section">
              <div class="section-title">
                <FileText size={14} class="sec-icon purple" />
                <span>Grounded Evidence Memory</span>
              </div>
              <div class="mem-snippet-card">
                <div class="mem-meta font-mono">
                  <span class="cat-pill">{relationEvidenceMem.category || 'evidence'}</span>
                  <span class="agent-pill">👤 {relationEvidenceMem.agent_id || relationEvidenceMem.author_agent || 'agent'}</span>
                  <span class="time-faint">{formatTime(relationEvidenceMem.created_at)}</span>
                </div>
                <div class="mem-body prose-dark">
                  {@html renderMarkdown(relationEvidenceMem.content)}
                </div>
                {#if relationEvidenceMem.tags && relationEvidenceMem.tags.length > 0}
                  <div class="mem-tags font-mono">
                    {#each relationEvidenceMem.tags as tag}
                      <span class="tag-chip">#{tag}</span>
                    {/each}
                  </div>
                {/if}
              </div>
            </div>
          {/if}

          <!-- Delete Relation Action -->
          <div class="danger-zone">
            <button
              class="del-entity-btn"
              on:click={() => {
                onDeleteRelation(selectedItem.id);
                onClose();
              }}
            >
              <Trash2 size={13} />
              <span>Delete Relation</span>
            </button>
          </div>

        <!-- Memory Content View (for Gray unlinked memories) -->
        {:else if isMemory}
          <div class="memory-card">
            <div class="meta-row font-mono">
              {#if selectedItem.agent_id || selectedItem.author_agent || selectedItem.metadata?.agent_id}
                <span class="meta-pill author">
                  <User size={12} />
                  <span>{selectedItem.agent_id || selectedItem.author_agent || selectedItem.metadata?.agent_id}</span>
                </span>
              {/if}
              {#if selectedItem.category || selectedItem.metadata?.category}
                <span class="meta-pill category">
                  <Tag size={12} />
                  <span>{selectedItem.category || selectedItem.metadata?.category}</span>
                </span>
              {/if}
              {#if selectedItem.created_at || selectedItem.metadata?.created_at}
                <span class="meta-pill time">
                  <Calendar size={12} />
                  <span>{formatTime(selectedItem.created_at || selectedItem.metadata?.created_at)}</span>
                </span>
              {/if}
            </div>

            <div class="section-title" style="margin-top: 0.65rem;">
              <FileText size={14} class="sec-icon purple" />
              <span>Memory Content</span>
            </div>
            <div class="markdown-card prose-dark">
              {@html renderMarkdown(selectedItem.content || selectedItem.metadata?.full_content || selectedItem.name)}
            </div>

            <div class="unlinked-tip font-mono">
              💡 Drag this memory node onto any entity node to link and ground it permanently!
            </div>
          </div>
        {:else}
          <!-- Entity Details Card -->
          <div class="entity-details">
            <div class="detail-row">
              <span class="label">Entity ID</span>
              <span class="val font-mono">{selectedItem.id}</span>
            </div>
            <div class="detail-row">
              <span class="label">Type</span>
              <span class="val font-mono">{selectedItem.type}</span>
            </div>
            {#if selectedItem.aliases && selectedItem.aliases.length > 0}
              <div class="detail-row">
                <span class="label">Aliases</span>
                <div class="aliases-list">
                  {#each selectedItem.aliases as alias}
                    <span class="alias-pill font-mono">{alias}</span>
                  {/each}
                </div>
              </div>
            {/if}
            <div class="detail-row">
              <span class="label">Connections</span>
              <span class="val font-mono">{outboundRelations.length + inboundRelations.length} links ({groundedMemories.length} memories)</span>
            </div>
          </div>

          <!-- PRIMARY KNOWLEDGE: Entity Description & Knowledge Notes -->
          {#if entityMarkdown}
            <div class="section">
              <div class="section-title">
                <BookOpen size={14} class="sec-icon amber" />
                <span>Description & Knowledge Notes</span>
              </div>
              <div class="markdown-card prose-dark">
                {@html renderMarkdown(entityMarkdown)}
              </div>
            </div>
          {/if}

          <!-- PRIMARY KNOWLEDGE: Grounded Memories (with full Markdown content) -->
          {#if groundedMemories.length > 0}
            <div class="section">
              <div class="section-title">
                <FileText size={14} class="sec-icon purple" />
                <span>Grounded Knowledge & Memories ({groundedMemories.length})</span>
              </div>
              <div class="memories-list">
                {#each groundedMemories as mem}
                  <div class="mem-snippet-card">
                    <div class="mem-meta font-mono">
                      <span class="cat-pill">{mem.category || 'general'}</span>
                      <span class="agent-pill">👤 {mem.agent_id || mem.author_agent || 'agent'}</span>
                      <span class="time-faint">{formatTime(mem.created_at)}</span>
                    </div>
                    <div class="mem-body prose-dark">
                      {@html renderMarkdown(mem.content)}
                    </div>
                    {#if mem.tags && mem.tags.length > 0}
                      <div class="mem-tags font-mono">
                        {#each mem.tags as tag}
                          <span class="tag-chip">#{tag}</span>
                        {/each}
                      </div>
                    {/if}
                  </div>
                {/each}
              </div>
            </div>
          {:else if !entityMarkdown}
            <div class="section">
              <div class="section-title">
                <BookOpen size={14} class="sec-icon amber" />
                <span>Knowledge Notes</span>
              </div>
              <div class="empty-hint font-mono">No markdown description or grounded memories linked to this entity.</div>
            </div>
          {/if}

          <!-- Outbound Relations -->
          <div class="section">
            <div class="section-title">
              <ArrowRight size={14} class="sec-icon cyan" />
              <span>Outbound Relations ({outboundRelations.length})</span>
            </div>
            {#if outboundRelations.length > 0}
              <div class="relations-list">
                {#each outboundRelations as rel}
                  {@const targetId = rel.dst || (rel as any).target_id}
                  {@const isSuperseded = Boolean(rel.valid_to)}
                  <div class="rel-item">
                    <div class="rel-info">
                      <span class="pred-tag font-mono">{rel.predicate}</span>
                      <button
                        class="target-link font-sans"
                        on:click={() => onInspectNode(targetId)}
                        title="Inspect target entity"
                      >
                        {getEntityName(targetId)}
                      </button>
                      {#if isSuperseded}
                        <span class="sup-tag font-mono">superseded</span>
                      {/if}
                    </div>
                    <button
                      class="rel-del-btn"
                      on:click={() => onDeleteRelation(rel.id)}
                      title="Delete this relation"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                {/each}
              </div>
            {:else}
              <div class="empty-hint font-mono">No outbound relations</div>
            {/if}
          </div>

          <!-- Inbound Relations -->
          <div class="section">
            <div class="section-title">
              <ArrowLeft size={14} class="sec-icon emerald" />
              <span>Inbound Relations ({inboundRelations.length})</span>
            </div>
            {#if inboundRelations.length > 0}
              <div class="relations-list">
                {#each inboundRelations as rel}
                  {@const sourceId = rel.src || (rel as any).source_id}
                  {@const isSuperseded = Boolean(rel.valid_to)}
                  <div class="rel-item">
                    <div class="rel-info">
                      <button
                        class="target-link font-sans"
                        on:click={() => onInspectNode(sourceId)}
                        title="Inspect source entity"
                      >
                        {getEntityName(sourceId)}
                      </button>
                      <span class="pred-tag font-mono">{rel.predicate}</span>
                      {#if isSuperseded}
                        <span class="sup-tag font-mono">superseded</span>
                      {/if}
                    </div>
                    <button
                      class="rel-del-btn"
                      on:click={() => onDeleteRelation(rel.id)}
                      title="Delete this relation"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                {/each}
              </div>
            {:else}
              <div class="empty-hint font-mono">No inbound relations</div>
            {/if}
          </div>

          <!-- Raw Metadata Details (collapsible / secondary) -->
          {#if selectedItem.metadata && Object.keys(selectedItem.metadata).length > 0}
            <div class="section">
              <div class="section-title">
                <Layers size={14} class="sec-icon cyan" />
                <span>Raw Metadata</span>
              </div>
              <pre class="meta-json font-mono">{JSON.stringify(selectedItem.metadata, null, 2)}</pre>
            </div>
          {/if}

          <!-- Danger Zone: Delete Entity -->
          <div class="danger-zone">
            {#if !showDeleteConfirm}
              <button
                class="del-entity-btn"
                on:click={() => (showDeleteConfirm = true)}
              >
                <Trash2 size={13} />
                <span>Delete Entity</span>
              </button>
            {:else}
              <div class="confirm-box">
                <div class="confirm-text">
                  <AlertTriangle size={15} class="warn-icon" />
                  <span>Delete <b>{selectedItem.name}</b> and all connected relations?</span>
                </div>
                <div class="confirm-actions">
                  <button class="confirm-no-btn" on:click={() => (showDeleteConfirm = false)}>Cancel</button>
                  <button class="confirm-yes-btn" on:click={() => onDeleteEntity(selectedItem.id)}>
                    Yes, Delete Entity
                  </button>
                </div>
              </div>
            {/if}
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .drawer-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(3, 7, 18, 0.6);
    backdrop-filter: blur(4px);
    z-index: 100;
    display: flex;
    justify-content: flex-end;
  }

  .drawer-panel {
    width: 100%;
    max-width: 540px;
    height: 100%;
    background: #0f172a;
    border-left: 1px solid var(--border-medium);
    display: flex;
    flex-direction: column;
    box-shadow: var(--shadow-lg);
  }

  .drawer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.85rem 1.25rem;
    border-bottom: 1px solid var(--border-subtle);
    background: rgba(15, 23, 42, 0.95);
    gap: 0.75rem;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }

  .hdr-btn {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.25rem 0.55rem;
    border-radius: var(--radius-sm);
    font-size: 0.72rem;
    font-weight: 600;
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-secondary);
  }

  .hdr-btn:hover {
    background: rgba(255, 255, 255, 0.15);
    color: var(--text-primary);
  }

  .hdr-btn.primary {
    background: rgba(16, 185, 129, 0.2);
    color: var(--brand-400);
    border: 1px solid rgba(16, 185, 129, 0.35);
  }

  .hdr-btn.primary:hover {
    background: rgba(16, 185, 129, 0.35);
    color: #ffffff;
  }

  .type-badge {
    font-size: 0.68rem;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--cyan-400);
    letter-spacing: 0.05em;
  }

  .type-badge.relation {
    color: var(--brand-400);
  }

  .highlight-predicate {
    color: var(--cyan-400);
    background: rgba(56, 189, 248, 0.15);
    padding: 0.15rem 0.45rem;
    border-radius: var(--radius-sm);
    font-size: 0.75rem;
  }

  .active-tag {
    color: #34d399;
    background: rgba(16, 185, 129, 0.15);
    padding: 0.1rem 0.35rem;
    border-radius: 2px;
    font-size: 0.65rem;
  }

  .item-title {
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--text-primary);
    margin-top: 0.15rem;
  }

  .close-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.05);
    color: var(--text-muted);
  }

  .close-btn:hover {
    background: rgba(255, 255, 255, 0.15);
    color: var(--text-primary);
  }

  .drawer-content {
    flex: 1;
    overflow-y: auto;
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .markdown-card {
    background: rgba(30, 41, 59, 0.5);
    border: 1px solid var(--border-medium);
    border-radius: var(--radius-md);
    padding: 1rem;
    box-shadow: var(--shadow-sm);
  }

  .unlinked-tip {
    font-size: 0.7rem;
    color: var(--cyan-400);
    background: var(--cyan-bg);
    border: 1px solid rgba(56, 189, 248, 0.25);
    padding: 0.5rem 0.65rem;
    border-radius: var(--radius-sm);
    margin-top: 0.5rem;
  }

  .section {
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
  }

  .section-title {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.78rem;
    font-weight: 700;
    color: var(--text-secondary);
  }

  :global(.sec-icon.cyan) { color: var(--cyan-400); }
  :global(.sec-icon.emerald) { color: var(--brand-400); }
  :global(.sec-icon.purple) { color: var(--purple-400); }
  :global(.sec-icon.amber) { color: var(--amber-400); }

  .relations-list {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .rel-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.45rem 0.65rem;
    background: rgba(30, 41, 59, 0.4);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    gap: 0.5rem;
  }

  .rel-info {
    display: flex;
    align-items: center;
    gap: 0.45rem;
    overflow: hidden;
  }

  .pred-tag {
    font-size: 0.68rem;
    padding: 0.1rem 0.35rem;
    border-radius: 3px;
    background: rgba(56, 189, 248, 0.15);
    color: var(--cyan-400);
    white-space: nowrap;
  }

  .target-link {
    font-size: 0.78rem;
    font-weight: 600;
    color: var(--text-primary);
    background: transparent;
    text-decoration: underline;
    text-underline-offset: 3px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 220px;
    padding: 0;
  }

  .target-link:hover {
    color: var(--brand-400);
  }

  .sup-tag {
    font-size: 0.62rem;
    padding: 0.05rem 0.3rem;
    border-radius: 2px;
    background: rgba(239, 68, 68, 0.15);
    color: #f87171;
  }

  .rel-del-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-muted);
    flex-shrink: 0;
  }

  .rel-del-btn:hover {
    background: rgba(239, 68, 68, 0.2);
    color: #f87171;
  }

  .empty-hint {
    font-size: 0.72rem;
    color: var(--text-faint);
    padding: 0.5rem 0.65rem;
    background: rgba(15, 23, 42, 0.4);
    border-radius: var(--radius-sm);
    border: 1px dashed var(--border-subtle);
  }

  .memories-list {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }

  .mem-snippet-card {
    background: rgba(30, 41, 59, 0.45);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    padding: 0.85rem;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .mem-meta {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.68rem;
    flex-wrap: wrap;
  }

  .cat-pill {
    padding: 0.1rem 0.35rem;
    border-radius: 3px;
    background: rgba(192, 132, 252, 0.15);
    color: var(--purple-400);
    text-transform: uppercase;
    font-weight: 700;
  }

  .agent-pill {
    color: var(--cyan-400);
    font-weight: 600;
  }

  .time-faint {
    color: var(--text-faint);
    margin-left: auto;
  }

  .mem-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.3rem;
    padding-top: 0.35rem;
    border-top: 1px solid var(--border-subtle);
  }

  .tag-chip {
    font-size: 0.65rem;
    color: var(--text-muted);
    background: rgba(255, 255, 255, 0.05);
    padding: 0.05rem 0.35rem;
    border-radius: 3px;
  }

  .entity-details {
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
  }

  .detail-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 0.78rem;
    padding: 0.45rem 0.65rem;
    background: rgba(30, 41, 59, 0.4);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-subtle);
  }

  .label {
    color: var(--text-muted);
  }

  .val {
    color: var(--text-primary);
    font-weight: 600;
  }

  .aliases-list {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
  }

  .alias-pill {
    font-size: 0.68rem;
    padding: 0.1rem 0.35rem;
    background: rgba(255, 255, 255, 0.06);
    border-radius: var(--radius-sm);
    color: var(--cyan-400);
  }

  .meta-json {
    font-size: 0.7rem;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid var(--border-subtle);
    padding: 0.65rem;
    border-radius: var(--radius-sm);
    overflow-x: auto;
    color: var(--text-secondary);
  }

  /* Danger Zone */
  .danger-zone {
    margin-top: 0.5rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border-subtle);
  }

  .del-entity-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.4rem;
    width: 100%;
    padding: 0.45rem;
    border-radius: var(--radius-sm);
    background: rgba(239, 68, 68, 0.1);
    color: #f87171;
    border: 1px solid rgba(239, 68, 68, 0.25);
    font-size: 0.78rem;
  }

  .del-entity-btn:hover {
    background: rgba(239, 68, 68, 0.25);
    color: #ffffff;
  }

  .confirm-box {
    background: rgba(239, 68, 68, 0.12);
    border: 1px solid rgba(239, 68, 68, 0.35);
    border-radius: var(--radius-sm);
    padding: 0.75rem;
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }

  .confirm-text {
    display: flex;
    align-items: center;
    gap: 0.45rem;
    font-size: 0.75rem;
    color: #fca5a5;
  }

  :global(.warn-icon) {
    color: #f87171;
    flex-shrink: 0;
  }

  .confirm-actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.45rem;
  }

  .confirm-no-btn {
    padding: 0.25rem 0.65rem;
    font-size: 0.72rem;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-secondary);
  }

  .confirm-yes-btn {
    padding: 0.25rem 0.65rem;
    font-size: 0.72rem;
    border-radius: var(--radius-sm);
    background: #ef4444;
    color: #ffffff;
  }
</style>
