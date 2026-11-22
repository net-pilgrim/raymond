<script lang="ts">
  import { X, Network, FileText, Calendar, Tag, User } from '@lucide/svelte';
  import { marked } from 'marked';

  export let selectedItem: any = null;
  export let onClose: () => void;

  function renderMarkdown(md: string) {
    if (!md) return '';
    try {
      return marked.parse(md);
    } catch (_) {
      return md;
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
      <div class="drawer-header">
        <div class="header-main">
          <span class="type-badge font-mono">{selectedItem.type || 'entity'}</span>
          <h2 class="item-title">{selectedItem.name || selectedItem.id}</h2>
        </div>
        <button class="close-btn" on:click={onClose} title="Close inspector">
          <X size={18} />
        </button>
      </div>

      <div class="drawer-content">
        {#if selectedItem.type === 'memory'}
          <div class="memory-card">
            <div class="meta-row font-mono">
              {#if selectedItem.author_agent}
                <span class="meta-pill author">
                  <User size={12} />
                  <span>{selectedItem.author_agent}</span>
                </span>
              {/if}
              {#if selectedItem.category}
                <span class="meta-pill category">
                  <Tag size={12} />
                  <span>{selectedItem.category}</span>
                </span>
              {/if}
              {#if selectedItem.created_at}
                <span class="meta-pill time">
                  <Calendar size={12} />
                  <span>{formatTime(selectedItem.created_at)}</span>
                </span>
              {/if}
            </div>

            <div class="markdown-body prose-dark">
              {@html renderMarkdown(selectedItem.content || selectedItem.name)}
            </div>
          </div>
        {:else}
          <div class="entity-details">
            <div class="detail-row">
              <span class="label">ID</span>
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
            {#if selectedItem.metadata && Object.keys(selectedItem.metadata).length > 0}
              <div class="detail-section">
                <span class="label">Metadata</span>
                <pre class="meta-json font-mono">{JSON.stringify(selectedItem.metadata, null, 2)}</pre>
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
    max-width: 480px;
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
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-subtle);
    background: rgba(15, 23, 42, 0.95);
  }

  .type-badge {
    font-size: 0.68rem;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--cyan-400);
    letter-spacing: 0.05em;
  }

  .item-title {
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--text-primary);
    margin-top: 0.2rem;
  }

  .close-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
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
    gap: 1rem;
  }

  .memory-card {
    background: rgba(30, 41, 59, 0.5);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md);
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
  }

  .meta-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.45rem;
  }

  .meta-pill {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    font-size: 0.7rem;
    padding: 0.2rem 0.5rem;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-secondary);
  }

  .meta-pill.author {
    color: var(--cyan-400);
  }

  .meta-pill.category {
    color: var(--brand-400);
  }

  .entity-details {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .detail-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 0.82rem;
    padding: 0.5rem 0.75rem;
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
    gap: 0.35rem;
  }

  .alias-pill {
    font-size: 0.7rem;
    padding: 0.15rem 0.4rem;
    background: rgba(255, 255, 255, 0.06);
    border-radius: var(--radius-sm);
    color: var(--cyan-400);
  }

  .detail-section {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .meta-json {
    font-size: 0.72rem;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid var(--border-subtle);
    padding: 0.75rem;
    border-radius: var(--radius-sm);
    overflow-x: auto;
    color: var(--text-secondary);
  }
</style>
