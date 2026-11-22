<script lang="ts">
  import { X, Link2, ArrowRight } from '@lucide/svelte';
  import type { Entity, Relation } from '../types';

  export let isOpen = false;
  export let entities: Entity[] = [];
  export let initialSourceId: string = '';
  export let onClose: () => void;
  export let onConnect: (sourceId: string, targetId: string, predicate: string) => void;

  let sourceId = '';
  let targetId = '';
  let selectedPredicate = 'uses';
  let customPredicate = '';
  let errorMessage = '';

  const COMMON_PREDICATES = [
    'uses',
    'depends_on',
    'implements',
    'enforces',
    'replaces',
    'relates_to',
    'connected_to',
    'protects',
    'extends',
    'coordinates_via',
    'visualized_by',
    'custom'
  ];

  $: if (isOpen) {
    sourceId = initialSourceId || (entities.length > 0 ? entities[0].id : '');
    targetId = entities.length > 1 ? (entities[0].id === sourceId ? entities[1].id : entities[0].id) : '';
    selectedPredicate = 'uses';
    customPredicate = '';
    errorMessage = '';
  }

  function handleCreate() {
    errorMessage = '';
    if (!sourceId || !targetId) {
      errorMessage = 'Please select both source and target entities.';
      return;
    }
    if (sourceId === targetId) {
      errorMessage = 'Source and target entities cannot be the same.';
      return;
    }

    const predicate = selectedPredicate === 'custom' ? customPredicate.trim() : selectedPredicate;
    if (!predicate) {
      errorMessage = 'Please specify a predicate.';
      return;
    }

    onConnect(sourceId, targetId, predicate);
    onClose();
  }
</script>

{#if isOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-backdrop" on:click={onClose}>
    <div class="modal-panel" on:click|stopPropagation>
      <div class="modal-header">
        <div class="title-group">
          <Link2 size={16} class="header-icon" />
          <h3>Connect Entities</h3>
        </div>
        <button class="close-btn" on:click={onClose} title="Close modal">
          <X size={16} />
        </button>
      </div>

      <div class="modal-body">
        <div class="form-group">
          <label for="src-select">Source Entity (Origin)</label>
          <select id="src-select" bind:value={sourceId}>
            {#each entities as ent}
              <option value={ent.id}>{ent.name || ent.id} ({ent.type})</option>
            {/each}
          </select>
        </div>

        <div class="predicate-group">
          <label for="pred-select">Relation Predicate</label>
          <select id="pred-select" bind:value={selectedPredicate}>
            {#each COMMON_PREDICATES as pred}
              <option value={pred}>{pred}</option>
            {/each}
          </select>

          {#if selectedPredicate === 'custom'}
            <input
              type="text"
              bind:value={customPredicate}
              placeholder="e.g. manages, verifies, orchestrates"
              class="custom-pred-input font-mono"
            />
          {/if}
        </div>

        <div class="form-group">
          <label for="dst-select">Target Entity (Destination)</label>
          <select id="dst-select" bind:value={targetId}>
            {#each entities as ent}
              <option value={ent.id}>{ent.name || ent.id} ({ent.type})</option>
            {/each}
          </select>
        </div>

        {#if errorMessage}
          <div class="error-msg font-mono">{errorMessage}</div>
        {/if}

        <div class="preview-box font-mono">
          <span class="preview-ent">{entities.find(e => e.id === sourceId)?.name || 'Source'}</span>
          <ArrowRight size={13} class="preview-arrow" />
          <span class="preview-pred">{selectedPredicate === 'custom' ? (customPredicate || 'predicate') : selectedPredicate}</span>
          <ArrowRight size={13} class="preview-arrow" />
          <span class="preview-ent">{entities.find(e => e.id === targetId)?.name || 'Target'}</span>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn cancel" on:click={onClose}>Cancel</button>
        <button class="btn primary" on:click={handleCreate}>
          <Link2 size={14} />
          <span>Create Relation</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(3, 7, 18, 0.75);
    backdrop-filter: blur(6px);
    z-index: 120;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
  }

  .modal-panel {
    width: 100%;
    max-width: 480px;
    background: #0f172a;
    border: 1px solid var(--border-medium);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-lg);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-subtle);
    background: rgba(15, 23, 42, 0.95);
  }

  .title-group {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  :global(.header-icon) {
    color: var(--brand-400);
  }

  .modal-header h3 {
    font-size: 0.95rem;
    font-weight: 700;
    color: var(--text-primary);
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

  .modal-body {
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .form-group, .predicate-group {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--text-secondary);
  }

  select {
    height: 36px;
    font-size: 0.8rem;
    cursor: pointer;
  }

  .custom-pred-input {
    margin-top: 0.4rem;
    height: 34px;
    font-size: 0.78rem;
  }

  .error-msg {
    font-size: 0.75rem;
    color: var(--rose-400);
    padding: 0.45rem 0.65rem;
    background: var(--rose-bg);
    border: 1px solid rgba(244, 63, 94, 0.3);
    border-radius: var(--radius-sm);
  }

  .preview-box {
    display: flex;
    align-items: center;
    gap: 0.45rem;
    background: rgba(9, 13, 22, 0.7);
    border: 1px solid var(--border-subtle);
    padding: 0.65rem 0.85rem;
    border-radius: var(--radius-sm);
    font-size: 0.72rem;
    overflow-x: auto;
  }

  .preview-ent {
    color: var(--text-primary);
    font-weight: 600;
    white-space: nowrap;
  }

  .preview-pred {
    color: var(--cyan-400);
    font-weight: 700;
    background: rgba(56, 189, 248, 0.12);
    padding: 0.1rem 0.4rem;
    border-radius: var(--radius-sm);
    white-space: nowrap;
  }

  :global(.preview-arrow) {
    color: var(--text-faint);
    flex-shrink: 0;
  }

  .modal-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.65rem;
    padding: 0.85rem 1.25rem;
    background: rgba(9, 13, 22, 0.8);
    border-top: 1px solid var(--border-subtle);
  }

  .btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.45rem 0.85rem;
    border-radius: var(--radius-sm);
    font-size: 0.8rem;
    font-weight: 600;
  }

  .btn.cancel {
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-secondary);
  }

  .btn.cancel:hover {
    background: rgba(255, 255, 255, 0.15);
    color: var(--text-primary);
  }

  .btn.primary {
    background: var(--brand-500);
    color: #030712;
  }

  .btn.primary:hover {
    background: var(--brand-400);
  }
</style>
