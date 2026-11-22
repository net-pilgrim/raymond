<script lang="ts">
  import { X, Save, RefreshCw, Key, Database, Sparkles } from '@lucide/svelte';
  import { saveCredentials, getStoredCredentials, DEFAULT_SUPABASE_URL, DEFAULT_SUPABASE_KEY } from '../supabase';

  export let isOpen = false;
  export let onClose: () => void;
  export let onCredentialsSaved: () => void;
  export let onLoadDemo: () => void;

  let currentCreds = getStoredCredentials();
  let supabaseUrl = currentCreds.url;
  let supabaseKey = currentCreds.key;
  let statusMessage = '';

  function handleSave() {
    saveCredentials(supabaseUrl.trim(), supabaseKey.trim());
    statusMessage = 'Credentials saved in localStorage!';
    setTimeout(() => {
      statusMessage = '';
      onCredentialsSaved();
      onClose();
    }, 600);
  }

  function handleResetDefault() {
    supabaseUrl = DEFAULT_SUPABASE_URL;
    supabaseKey = DEFAULT_SUPABASE_KEY;
    saveCredentials(DEFAULT_SUPABASE_URL, DEFAULT_SUPABASE_KEY);
    statusMessage = 'Reset to default Supabase instance!';
    setTimeout(() => {
      statusMessage = '';
      onCredentialsSaved();
      onClose();
    }, 600);
  }
</script>

{#if isOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-backdrop" on:click={onClose}>
    <div class="modal-panel" on:click|stopPropagation>
      <div class="modal-header">
        <div class="title-group">
          <Database size={16} class="header-icon" />
          <h3>Connection Settings</h3>
        </div>
        <button class="close-btn" on:click={onClose}>
          <X size={16} />
        </button>
      </div>

      <div class="modal-body">
        <p class="modal-desc">
          Configure your Supabase endpoint and API key. Credentials remain local in your browser's <code class="font-mono">localStorage</code>.
        </p>

        <div class="form-group">
          <label for="sb-url">Supabase Project URL</label>
          <input
            id="sb-url"
            type="text"
            bind:value={supabaseUrl}
            placeholder="https://xyzcompany.supabase.co"
            class="font-mono"
          />
        </div>

        <div class="form-group">
          <label for="sb-key">Supabase API Key (Anon / Service Role)</label>
          <input
            id="sb-key"
            type="password"
            bind:value={supabaseKey}
            placeholder="eyJhbGciOi..."
            class="font-mono"
          />
        </div>

        {#if statusMessage}
          <div class="status-msg font-mono">{statusMessage}</div>
        {/if}
      </div>

      <div class="modal-footer">
        <button class="btn secondary" on:click={onLoadDemo} title="Switch to offline demo dataset">
          <Sparkles size={14} />
          <span>Load Demo Dataset</span>
        </button>
        <button class="btn primary" on:click={handleSave}>
          <Save size={14} />
          <span>Save & Connect</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(3, 7, 18, 0.7);
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

  .modal-body {
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .modal-desc {
    font-size: 0.78rem;
    color: var(--text-muted);
    line-height: 1.45;
  }

  .modal-desc code {
    color: var(--cyan-400);
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .form-group label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .form-group input {
    height: 36px;
    font-size: 0.8rem;
  }

  .status-msg {
    font-size: 0.75rem;
    color: var(--brand-400);
    padding: 0.45rem 0.65rem;
    background: var(--brand-bg);
    border: 1px solid rgba(16, 185, 129, 0.3);
    border-radius: var(--radius-sm);
  }

  .modal-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
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

  .btn.primary {
    background: var(--brand-500);
    color: #030712;
  }

  .btn.primary:hover {
    background: var(--brand-400);
    box-shadow: 0 0 12px rgba(16, 185, 129, 0.4);
  }

  .btn.secondary {
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-secondary);
    border: 1px solid var(--border-subtle);
  }

  .btn.secondary:hover {
    background: rgba(255, 255, 255, 0.15);
    color: var(--text-primary);
  }
</style>
