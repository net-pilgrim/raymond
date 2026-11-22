<script lang="ts">
  import { Network, LayoutList, RefreshCw, Settings, CheckCircle2, AlertTriangle, Radio, Shield, User as UserIcon } from '@lucide/svelte';
  import type { User } from '@supabase/supabase-js';

  export let activeTab: 'graph' | 'kanban' = 'kanban';
  export let connectionStatus: 'connected' | 'demo' | 'error' = 'connected';
  export let currentUser: User | null = null;
  export let onRefresh: () => void;
  export let onOpenSettings: () => void;
  export let onOpenAuth: () => void;
</script>

<header class="navbar">
  <div class="brand">
    <div class="logo">🕸️</div>
    <div class="brand-text">
      <div class="title">Raymond</div>
      <div class="subtitle">Multi-Agent Protocol & KG</div>
    </div>
  </div>

  <nav class="nav-tabs">
    <button
      class="tab-btn"
      class:active={activeTab === 'kanban'}
      on:click={() => (activeTab = 'kanban')}
    >
      <LayoutList size={16} />
      <span>Transaction Kanban</span>
    </button>
    <button
      class="tab-btn"
      class:active={activeTab === 'graph'}
      on:click={() => (activeTab = 'graph')}
    >
      <Network size={16} />
      <span>Knowledge Graph</span>
    </button>
  </nav>

  <div class="nav-actions">
    <!-- Auth Status / Account Button -->
    {#if currentUser}
      <button class="user-chip-btn font-mono" on:click={onOpenAuth} title="Account & Registered Agents">
        <span class="user-avatar-tiny">{currentUser.email ? currentUser.email.charAt(0).toUpperCase() : 'U'}</span>
        <span class="user-chip-email">{currentUser.email}</span>
      </button>
    {:else}
      <button class="action-btn auth-btn" on:click={onOpenAuth} title="Sign in with Supabase Auth">
        <Shield size={14} class="auth-icon" />
        <span class="auth-text">Sign In</span>
      </button>
    {/if}

    <div class="status-indicator" class:connected={connectionStatus === 'connected'} class:demo={connectionStatus === 'demo'} class:error={connectionStatus === 'error'}>
      <span class="status-dot"></span>
      <span class="status-label">
        {#if connectionStatus === 'connected'}
          Live Supabase
        {:else if connectionStatus === 'demo'}
          Demo Mode
        {:else}
          Connection Error
        {/if}
      </span>
    </div>

    <button class="action-btn" on:click={onRefresh} title="Refresh data">
      <RefreshCw size={15} />
    </button>

    <button class="action-btn settings-btn" on:click={onOpenSettings} title="Connection Settings">
      <Settings size={15} />
      <span class="settings-text">Settings</span>
    </button>
  </div>
</header>

<style>
  .navbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 56px;
    padding: 0 1.25rem;
    background: rgba(15, 23, 42, 0.85);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border-subtle);
    z-index: 40;
    flex-shrink: 0;
  }

  .brand {
    display: flex;
    align-items: center;
    gap: 0.65rem;
  }

  .logo {
    font-size: 1.4rem;
    filter: drop-shadow(0 0 8px rgba(16, 185, 129, 0.4));
  }

  .brand-text .title {
    font-size: 0.95rem;
    font-weight: 800;
    letter-spacing: -0.02em;
    color: var(--text-primary);
  }

  .brand-text .subtitle {
    font-size: 0.68rem;
    font-weight: 500;
    color: var(--text-muted);
    font-family: var(--font-mono);
  }

  .nav-tabs {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    background: rgba(9, 13, 22, 0.6);
    padding: 3px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border-subtle);
  }

  .tab-btn {
    display: flex;
    align-items: center;
    gap: 0.45rem;
    padding: 0.35rem 0.85rem;
    border-radius: var(--radius-sm);
    color: var(--text-muted);
    background: transparent;
    font-size: 0.82rem;
  }

  .tab-btn:hover {
    color: var(--text-primary);
    background: rgba(255, 255, 255, 0.05);
  }

  .tab-btn.active {
    color: var(--brand-400);
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid var(--border-brand);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
  }

  .nav-actions {
    display: flex;
    align-items: center;
    gap: 0.65rem;
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 0.45rem;
    padding: 0.25rem 0.65rem;
    border-radius: var(--radius-full);
    font-size: 0.72rem;
    font-family: var(--font-mono);
    font-weight: 500;
    border: 1px solid transparent;
  }

  .status-indicator.connected {
    background: var(--brand-bg);
    color: var(--brand-400);
    border-color: rgba(16, 185, 129, 0.3);
  }

  .status-indicator.demo {
    background: var(--cyan-bg);
    color: var(--cyan-400);
    border-color: rgba(56, 189, 248, 0.3);
  }

  .status-indicator.error {
    background: var(--rose-bg);
    color: var(--rose-400);
    border-color: rgba(251, 113, 133, 0.3);
  }

  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background-color: currentColor;
    box-shadow: 0 0 6px currentColor;
  }

  .action-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.4rem;
    padding: 0.4rem 0.75rem;
    border-radius: var(--radius-sm);
    background: rgba(30, 41, 59, 0.6);
    color: var(--text-secondary);
    border: 1px solid var(--border-medium);
  }

  .action-btn:hover {
    background: rgba(30, 41, 59, 1);
    color: var(--text-primary);
    border-color: var(--border-strong);
  }

  .auth-btn {
    background: rgba(16, 185, 129, 0.12);
    color: var(--brand-400);
    border-color: rgba(16, 185, 129, 0.35);
  }

  .auth-btn:hover {
    background: rgba(16, 185, 129, 0.25);
    color: #ffffff;
  }

  .auth-text {
    font-size: 0.78rem;
    font-weight: 600;
  }

  :global(.auth-icon) {
    color: var(--brand-400);
  }

  .user-chip-btn {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.3rem 0.65rem;
    border-radius: var(--radius-full);
    background: rgba(30, 41, 59, 0.6);
    border: 1px solid var(--border-medium);
    color: var(--text-primary);
    font-size: 0.72rem;
    max-width: 180px;
  }

  .user-chip-btn:hover {
    background: rgba(30, 41, 59, 1);
    border-color: var(--brand-500);
  }

  .user-avatar-tiny {
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--brand-500);
    color: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.65rem;
    font-weight: 700;
  }

  .user-chip-email {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .settings-btn .settings-text {
    font-size: 0.78rem;
  }
</style>
