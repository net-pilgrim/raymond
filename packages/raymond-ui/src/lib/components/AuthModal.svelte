<script lang="ts">
  import { onMount } from 'svelte';
  import {
    X, Mail, Key, ShieldCheck, LogOut, CheckCircle2,
    AlertCircle, Sparkles, Bot, Plus, Loader2, Copy, Check, Code2
  } from '@lucide/svelte';
  import type { User } from '@supabase/supabase-js';
  import type { Agent } from '../types';
  import {
    signInWithMagicLink, signInWithOAuth, signOut,
    fetchUserAgents, registerAgent, getCurrentSession, getStoredCredentials
  } from '../supabase';

  export let isOpen = false;
  export let currentUser: User | null = null;
  export let onClose: () => void;
  export let onAuthSuccess: () => void;

  let email = '';
  let isLoading = false;
  let statusType: 'idle' | 'success' | 'error' = 'idle';
  let statusMessage = '';

  // Agents list for authenticated user
  let agents: Agent[] = [];
  let isFetchingAgents = false;
  let newAgentName = '';
  let newAgentDisplayName = '';
  let isAddingAgent = false;
  let agentError = '';

  // MCP Token & Config
  let accessToken = '';
  let tokenCopied = false;
  let configCopied = false;
  let activeConfigTab: 'antigravity' | 'claude' | 'cursor' = 'antigravity';
  let creds = getStoredCredentials();

  async function loadAgents() {
    if (!currentUser) return;
    isFetchingAgents = true;
    agents = await fetchUserAgents();
    isFetchingAgents = false;

    const session = await getCurrentSession();
    accessToken = session?.access_token || '';
  }

  $: if (isOpen && currentUser) {
    loadAgents();
  }

  function copyToken() {
    if (!accessToken) return;
    navigator.clipboard.writeText(accessToken);
    tokenCopied = true;
    setTimeout(() => (tokenCopied = false), 2000);
  }

  $: mcpConfigJson = (() => {
    const sseUrl = `${creds.url}/functions/v1/mcp/sse`;
    if (activeConfigTab === 'cursor') {
      return JSON.stringify({
        mcpServers: {
          raymond: {
            url: `${sseUrl}?token=${accessToken || '<YOUR_TOKEN>'}`
          }
        }
      }, null, 2);
    }
    return JSON.stringify({
      mcpServers: {
        raymond: {
          url: sseUrl,
          headers: {
            Authorization: `Bearer ${accessToken || '<YOUR_TOKEN>'}`
          }
        }
      }
    }, null, 2);
  })();

  function copyConfig() {
    navigator.clipboard.writeText(mcpConfigJson);
    configCopied = true;
    setTimeout(() => (configCopied = false), 2000);
  }

  async function handleMagicLink() {
    if (!email || !email.includes('@')) {
      statusType = 'error';
      statusMessage = 'Please enter a valid email address.';
      return;
    }

    isLoading = true;
    statusType = 'idle';
    statusMessage = '';

    const { error } = await signInWithMagicLink(email.trim());
    isLoading = false;

    if (error) {
      statusType = 'error';
      statusMessage = error.message || 'Failed to send magic link. Please try again.';
    } else {
      statusType = 'success';
      statusMessage = `Magic link sent to ${email.trim()}! Please check your inbox to sign in.`;
      email = '';
    }
  }

  async function handleOAuth(provider: 'github' | 'google') {
    isLoading = true;
    const { error } = await signInWithOAuth(provider);
    if (error) {
      isLoading = false;
      statusType = 'error';
      statusMessage = error.message || `Failed to sign in with ${provider}.`;
    }
  }

  async function handleSignOut() {
    isLoading = true;
    await signOut();
    isLoading = false;
    currentUser = null;
    agents = [];
    statusType = 'idle';
    statusMessage = '';
    onAuthSuccess();
    onClose();
  }

  async function handleAddAgent() {
    if (!newAgentName.trim()) {
      agentError = 'Agent identifier name is required.';
      return;
    }

    isAddingAgent = true;
    agentError = '';
    const res = await registerAgent(newAgentName.trim(), newAgentDisplayName.trim());
    isAddingAgent = false;

    if (res.success && res.data) {
      agents = [res.data, ...agents];
      newAgentName = '';
      newAgentDisplayName = '';
    } else {
      agentError = res.error || 'Failed to register agent.';
    }
  }
</script>

{#if isOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-backdrop" on:click={onClose}>
    <div class="modal-panel" on:click|stopPropagation>
      <div class="modal-header">
        <div class="title-group">
          <ShieldCheck size={18} class="header-icon" />
          <h3>{currentUser ? 'Agent Identity & Account' : 'Sign in to Raymond'}</h3>
        </div>
        <button class="close-btn" on:click={onClose}>
          <X size={16} />
        </button>
      </div>

      <div class="modal-body">
        {#if currentUser}
          <!-- Logged in State -->
          <div class="user-card">
            <div class="user-avatar">
              {currentUser.email ? currentUser.email.charAt(0).toUpperCase() : 'U'}
            </div>
            <div class="user-info">
              <div class="user-email font-mono">{currentUser.email}</div>
              <div class="user-id font-mono">User ID: {currentUser.id.slice(0, 12)}...</div>
            </div>
            <button class="signout-btn" on:click={handleSignOut} disabled={isLoading}>
              <LogOut size={14} />
              <span>Sign Out</span>
            </button>
          </div>

          <div class="section-divider"></div>

          <!-- Registered Agents Section -->
          <div class="agents-section">
            <div class="section-header">
              <div class="sec-title">
                <Bot size={15} class="sec-icon cyan" />
                <span>Your Registered Agents ({agents.length})</span>
              </div>
              <span class="subtext">Agents created under your user account for scoped MCP calls</span>
            </div>

            <!-- Agent Creation Form -->
            <div class="add-agent-form">
              <div class="input-row">
                <input
                  type="text"
                  placeholder="agent-name (e.g. antigravity-01)"
                  bind:value={newAgentName}
                  class="font-mono text-xs"
                />
                <input
                  type="text"
                  placeholder="Display Name (optional)"
                  bind:value={newAgentDisplayName}
                  class="text-xs"
                />
                <button class="btn-create" on:click={handleAddAgent} disabled={isAddingAgent}>
                  {#if isAddingAgent}
                    <Loader2 size={13} class="spin" />
                  {:else}
                    <Plus size={13} />
                  {/if}
                  <span>Add Agent</span>
                </button>
              </div>
              {#if agentError}
                <div class="agent-err font-mono">{agentError}</div>
              {/if}
            </div>

            <!-- Agents List -->
            <div class="agents-list">
              {#if isFetchingAgents}
                <div class="loading-state font-mono">Loading agents...</div>
              {:else if agents.length === 0}
                <div class="empty-agents font-mono">
                  No agents registered yet. Register an agent above to attribute memories and transactions.
                </div>
              {:else}
                {#each agents as ag}
                  <div class="agent-row">
                    <div class="agent-left">
                      <Bot size={14} class="agent-avatar" />
                      <div class="agent-meta">
                        <div class="agent-name font-mono">{ag.name}</div>
                        {#if ag.display_name && ag.display_name !== ag.name}
                          <div class="agent-display">{ag.display_name}</div>
                        {/if}
                      </div>
                    </div>
                    <span class="agent-date font-mono">{new Date(ag.created_at).toLocaleDateString()}</span>
                  </div>
                {/each}
              {/if}
            </div>
          </div>

          <div class="section-divider"></div>

          <!-- Raymond MCP Token & Client Configuration -->
          <div class="token-section">
            <div class="section-header">
              <div class="sec-title">
                <Key size={15} class="sec-icon amber" />
                <span>Your Raymond MCP Token & Config</span>
              </div>
              <span class="subtext">Use this Bearer token in your agent config (replaces service_role key)</span>
            </div>

            <!-- Token Bar -->
            <div class="token-bar">
              <input
                type="password"
                readonly
                value={accessToken || 'Loading token...'}
                class="font-mono text-xs token-input"
              />
              <button class="btn-copy" on:click={copyToken} title="Copy Bearer token">
                {#if tokenCopied}
                  <Check size={13} class="text-emerald" />
                  <span>Copied!</span>
                {:else}
                  <Copy size={13} />
                  <span>Copy Token</span>
                {/if}
              </button>
            </div>

            <!-- Config Tabs -->
            <div class="config-tabs">
              <button
                class="cfg-tab-btn"
                class:active={activeConfigTab === 'antigravity'}
                on:click={() => (activeConfigTab = 'antigravity')}
              >
                Antigravity
              </button>
              <button
                class="cfg-tab-btn"
                class:active={activeConfigTab === 'claude'}
                on:click={() => (activeConfigTab = 'claude')}
              >
                Claude Desktop
              </button>
              <button
                class="cfg-tab-btn"
                class:active={activeConfigTab === 'cursor'}
                on:click={() => (activeConfigTab = 'cursor')}
              >
                Cursor
              </button>
            </div>

            <div class="config-snippet-box">
              <pre class="font-mono text-xs">{mcpConfigJson}</pre>
              <button class="copy-snippet-btn font-mono" on:click={copyConfig}>
                {#if configCopied}
                  <Check size={12} class="text-emerald" />
                  <span>Copied JSON</span>
                {:else}
                  <Copy size={12} />
                  <span>Copy Config</span>
                {/if}
              </button>
            </div>
          </div>

        {:else}
          <!-- Unauthenticated / Login Form -->
          <p class="auth-intro">
            Log in via Supabase Auth to access your private memories, ground knowledge graph relations under your identity, and manage multi-agent transactions.
          </p>

          <form on:submit|preventDefault={handleMagicLink} class="auth-form">
            <div class="form-group">
              <label for="auth-email">Email Address</label>
              <div class="input-with-icon">
                <Mail size={15} class="input-icon" />
                <input
                  id="auth-email"
                  type="email"
                  placeholder="name@example.com"
                  bind:value={email}
                  disabled={isLoading}
                  required
                />
              </div>
            </div>

            <button type="submit" class="btn primary full-width" disabled={isLoading}>
              {#if isLoading}
                <Loader2 size={15} class="spin" />
                <span>Sending Magic Link...</span>
              {:else}
                <Mail size={15} />
                <span>Send Magic Link</span>
              {/if}
            </button>
          </form>

          {#if statusMessage}
            <div class="status-box" class:success={statusType === 'success'} class:error={statusType === 'error'}>
              {#if statusType === 'success'}
                <CheckCircle2 size={16} />
              {:else}
                <AlertCircle size={16} />
              {/if}
              <span>{statusMessage}</span>
            </div>
          {/if}

          <div class="oauth-divider">
            <span>or sign in with</span>
          </div>

          <div class="oauth-grid">
            <button class="oauth-btn" on:click={() => handleOAuth('github')} disabled={isLoading}>
              <span>GitHub</span>
            </button>
            <button class="oauth-btn" on:click={() => handleOAuth('google')} disabled={isLoading}>
              <span>Google</span>
            </button>
          </div>

          <div class="guest-action">
            <button class="guest-btn" on:click={onClose}>
              <Sparkles size={13} />
              <span>Continue in Guest / Demo Mode</span>
            </button>
          </div>
        {/if}
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
    max-width: 490px;
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
    color: var(--text-muted);
    background: transparent;
  }

  .close-btn:hover {
    color: var(--text-primary);
    background: rgba(255, 255, 255, 0.08);
  }

  .modal-body {
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .auth-intro {
    font-size: 0.8rem;
    color: var(--text-secondary);
    line-height: 1.45;
  }

  .auth-form {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .form-group label {
    font-size: 0.72rem;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .input-with-icon {
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.input-icon) {
    position: absolute;
    left: 0.75rem;
    color: var(--text-muted);
    pointer-events: none;
  }

  .input-with-icon input {
    width: 100%;
    padding: 0.55rem 0.75rem 0.55rem 2.25rem;
    background: rgba(0, 0, 0, 0.35);
    border: 1px solid var(--border-medium);
    border-radius: var(--radius-sm);
    color: var(--text-primary);
    font-size: 0.82rem;
  }

  .input-with-icon input:focus {
    outline: none;
    border-color: var(--brand-500);
  }

  .btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.45rem;
    padding: 0.6rem 1rem;
    border-radius: var(--radius-sm);
    font-size: 0.82rem;
    font-weight: 600;
    cursor: pointer;
  }

  .btn.primary {
    background: var(--brand-500);
    color: #ffffff;
    border: 1px solid var(--brand-400);
  }

  .btn.primary:hover:not(:disabled) {
    background: var(--brand-600);
  }

  .btn.full-width {
    width: 100%;
  }

  .status-box {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.65rem 0.85rem;
    border-radius: var(--radius-sm);
    font-size: 0.78rem;
    line-height: 1.4;
  }

  .status-box.success {
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid rgba(16, 185, 129, 0.3);
    color: #34d399;
  }

  .status-box.error {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #f87171;
  }

  .oauth-divider {
    display: flex;
    align-items: center;
    text-align: center;
    margin: 0.25rem 0;
  }

  .oauth-divider::before,
  .oauth-divider::after {
    content: '';
    flex: 1;
    border-bottom: 1px solid var(--border-subtle);
  }

  .oauth-divider span {
    padding: 0 0.65rem;
    font-size: 0.68rem;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .oauth-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.5rem;
  }

  .oauth-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.45rem;
    padding: 0.5rem;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    color: var(--text-secondary);
    font-size: 0.78rem;
    font-weight: 600;
  }

  .oauth-btn:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-primary);
  }

  .guest-action {
    display: flex;
    justify-content: center;
    margin-top: 0.25rem;
  }

  .guest-btn {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    background: transparent;
    color: var(--text-muted);
    font-size: 0.75rem;
    text-decoration: underline;
    text-underline-offset: 3px;
  }

  .guest-btn:hover {
    color: var(--brand-400);
  }

  /* Authenticated User Profile Styling */
  .user-card {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.85rem;
    background: rgba(30, 41, 59, 0.5);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
  }

  .user-avatar {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: rgba(16, 185, 129, 0.2);
    border: 1px solid rgba(16, 185, 129, 0.4);
    color: var(--brand-400);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 0.95rem;
  }

  .user-info {
    flex: 1;
    overflow: hidden;
  }

  .user-email {
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .user-id {
    font-size: 0.65rem;
    color: var(--text-muted);
  }

  .signout-btn {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.35rem 0.65rem;
    border-radius: var(--radius-sm);
    background: rgba(239, 68, 68, 0.15);
    color: #f87171;
    border: 1px solid rgba(239, 68, 68, 0.25);
    font-size: 0.72rem;
    font-weight: 600;
  }

  .signout-btn:hover {
    background: rgba(239, 68, 68, 0.25);
  }

  .section-divider {
    height: 1px;
    background: var(--border-subtle);
  }

  .agents-section {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }

  .section-header {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
  }

  .sec-title {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    font-size: 0.78rem;
    font-weight: 700;
    color: var(--text-primary);
  }

  :global(.sec-icon.cyan) {
    color: var(--cyan-400);
  }

  .subtext {
    font-size: 0.68rem;
    color: var(--text-muted);
  }

  .add-agent-form {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .input-row {
    display: flex;
    gap: 0.35rem;
  }

  .input-row input {
    flex: 1;
    padding: 0.4rem 0.6rem;
    background: rgba(0, 0, 0, 0.35);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    color: var(--text-primary);
    font-size: 0.75rem;
  }

  .btn-create {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.4rem 0.65rem;
    border-radius: var(--radius-sm);
    background: rgba(56, 189, 248, 0.15);
    color: var(--cyan-400);
    border: 1px solid rgba(56, 189, 248, 0.3);
    font-size: 0.72rem;
    font-weight: 600;
    white-space: nowrap;
  }

  .btn-create:hover:not(:disabled) {
    background: rgba(56, 189, 248, 0.25);
  }

  .agent-err {
    font-size: 0.68rem;
    color: #f87171;
  }

  .agents-list {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    max-height: 180px;
    overflow-y: auto;
  }

  .agent-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.4rem 0.65rem;
    background: rgba(30, 41, 59, 0.35);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
  }

  .agent-left {
    display: flex;
    align-items: center;
    gap: 0.45rem;
  }

  :global(.agent-avatar) {
    color: var(--cyan-400);
  }

  .agent-name {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--text-primary);
  }

  .agent-display {
    font-size: 0.65rem;
    color: var(--text-muted);
  }

  .agent-date {
    font-size: 0.65rem;
    color: var(--text-faint);
  }

  .token-section {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }

  .token-bar {
    display: flex;
    gap: 0.35rem;
  }

  .token-input {
    flex: 1;
    padding: 0.4rem 0.6rem;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    color: var(--text-secondary);
  }

  .btn-copy {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.4rem 0.65rem;
    border-radius: var(--radius-sm);
    background: rgba(251, 191, 36, 0.15);
    color: var(--amber-400);
    border: 1px solid rgba(251, 191, 36, 0.3);
    font-size: 0.72rem;
    font-weight: 600;
    white-space: nowrap;
  }

  .btn-copy:hover {
    background: rgba(251, 191, 36, 0.25);
  }

  .config-tabs {
    display: flex;
    gap: 0.25rem;
    border-bottom: 1px solid var(--border-subtle);
    padding-bottom: 0.25rem;
  }

  .cfg-tab-btn {
    padding: 0.2rem 0.55rem;
    font-size: 0.68rem;
    font-weight: 600;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-muted);
  }

  .cfg-tab-btn.active {
    background: rgba(255, 255, 255, 0.08);
    color: var(--brand-400);
  }

  .config-snippet-box {
    position: relative;
    background: rgba(0, 0, 0, 0.45);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    padding: 0.65rem;
  }

  .config-snippet-box pre {
    margin: 0;
    color: var(--text-secondary);
    max-height: 140px;
    overflow-y: auto;
    font-size: 0.68rem;
    line-height: 1.4;
  }

  .copy-snippet-btn {
    position: absolute;
    top: 0.4rem;
    right: 0.4rem;
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.2rem 0.45rem;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.1);
    color: var(--text-primary);
    font-size: 0.65rem;
    border: 1px solid var(--border-subtle);
  }

  .copy-snippet-btn:hover {
    background: rgba(255, 255, 255, 0.18);
  }

  .empty-agents, .loading-state {
    font-size: 0.7rem;
    color: var(--text-muted);
    padding: 0.75rem;
    text-align: center;
  }

  :global(.spin) {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
