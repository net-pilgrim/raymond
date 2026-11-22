<script lang="ts">
  import type { Transaction } from '../types';
  import { X, ArrowRight, Clock, ShieldCheck, FileText, CheckCircle2, AlertCircle, Sparkles } from '@lucide/svelte';

  export let transaction: Transaction | null = null;
  export let onClose: () => void;

  function formatIso(iso: string) {
    try {
      const d = new Date(iso);
      return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } catch (_) {
      return iso;
    }
  }

  function getActIconColor(type: string) {
    switch (type) {
      case 'REQUEST': return '#fbbf24';
      case 'PROMISE': return '#38bdf8';
      case 'DECLARE': return '#c084fc';
      case 'ACCEPT': return '#34d399';
      case 'REJECT': return '#f43f5e';
      case 'REVOKE': return '#ef4444';
      case 'DECLINE': return '#94a3b8';
      default: return '#cbd5e1';
    }
  }
</script>

{#if transaction}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="drawer-backdrop" on:click={onClose}>
    <div class="drawer-panel" on:click|stopPropagation>
      <div class="drawer-header">
        <div class="header-main">
          <div class="tx-tag font-mono">{transaction.id}</div>
          <h2 class="tx-title">{transaction.p_fact_type}</h2>
        </div>
        <button class="close-btn" on:click={onClose} title="Close drawer">
          <X size={18} />
        </button>
      </div>

      <div class="drawer-scroll-body">
        <!-- Overview Grid -->
        <div class="info-card">
          <div class="info-row">
            <span class="info-label">Current State</span>
            <span class="state-pill font-mono">{transaction.state}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Initiator</span>
            <span class="agent-value font-mono initiator">{transaction.initiator_id}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Executor</span>
            <span class="agent-value font-mono executor">{transaction.executor_id}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Created At</span>
            <span class="time-value font-mono">{formatIso(transaction.created_at)}</span>
          </div>
          {#if transaction.review_sla_seconds}
            <div class="info-row">
              <span class="info-label">Review SLA</span>
              <span class="time-value font-mono">{Math.round(transaction.review_sla_seconds / 60)} mins</span>
            </div>
          {/if}
          {#if transaction.memory_id}
            <div class="info-row">
              <span class="info-label">Grounded Memory</span>
              <span class="memory-value font-mono">{transaction.memory_id.slice(0, 8)}...</span>
            </div>
          {/if}
        </div>

        <!-- P-Fact Specification -->
        <div class="section">
          <div class="section-title">
            <FileText size={15} />
            <span>P-Fact Specification</span>
          </div>
          <div class="spec-box font-mono">
            <pre>{JSON.stringify(transaction.p_fact_spec, null, 2)}</pre>
          </div>
        </div>

        <!-- Conditions -->
        {#if transaction.conditions && transaction.conditions.length > 0}
          <div class="section">
            <div class="section-title">
              <ShieldCheck size={15} />
              <span>Contract Conditions</span>
            </div>
            <ul class="conditions-list">
              {#each transaction.conditions as cond}
                <li class="condition-item">
                  <span class="bullet">▸</span>
                  <span>{typeof cond === 'string' ? cond : (cond.description || JSON.stringify(cond))}</span>
                </li>
              {/each}
            </ul>
          </div>
        {/if}

        <!-- Deliverables -->
        {#if transaction.deliverables && Object.keys(transaction.deliverables).length > 0}
          <div class="section">
            <div class="section-title">
              <CheckCircle2 size={15} />
              <span>Deliverables</span>
            </div>
            <div class="spec-box font-mono">
              <pre>{JSON.stringify(transaction.deliverables, null, 2)}</pre>
            </div>
          </div>
        {/if}

        <!-- Evidence -->
        {#if transaction.evidence && Object.keys(transaction.evidence).length > 0}
          <div class="section">
            <div class="section-title">
              <Sparkles size={15} />
              <span>Evidence & Verification</span>
            </div>
            <div class="spec-box font-mono">
              <pre>{JSON.stringify(transaction.evidence, null, 2)}</pre>
            </div>
          </div>
        {/if}

        <!-- Coordination Acts Timeline (Audit Trail) -->
        <div class="section">
          <div class="section-title">
            <Clock size={15} />
            <span>Coordination Acts Audit Trail</span>
          </div>

          {#if transaction.acts && transaction.acts.length > 0}
            <div class="timeline">
              {#each transaction.acts as act}
                <div class="timeline-item">
                  <div class="timeline-dot" style="background: {getActIconColor(act.act_type)}; box-shadow: 0 0 8px {getActIconColor(act.act_type)}"></div>
                  <div class="act-card">
                    <div class="act-header font-mono">
                      <span class="act-type" style="color: {getActIconColor(act.act_type)}">{act.act_type}</span>
                      <span class="act-actor">{act.actor_id} ({act.role})</span>
                      <span class="act-time">{formatIso(act.created_at)}</span>
                    </div>
                    <div class="act-message">{act.message}</div>
                    {#if act.payload && Object.keys(act.payload).length > 0}
                      <pre class="act-payload font-mono">{JSON.stringify(act.payload, null, 2)}</pre>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          {:else}
            <div class="empty-state font-mono">No coordination acts logged yet for this transaction.</div>
          {/if}
        </div>
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
    animation: fadeIn var(--transition-fast) ease-out;
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
    animation: slideIn var(--transition-normal) ease-out;
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes slideIn {
    from { transform: translateX(100%); }
    to { transform: translateX(0); }
  }

  .drawer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-subtle);
    background: rgba(15, 23, 42, 0.95);
  }

  .tx-tag {
    font-size: 0.72rem;
    color: var(--cyan-400);
    letter-spacing: -0.01em;
  }

  .tx-title {
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

  .drawer-scroll-body {
    flex: 1;
    overflow-y: auto;
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .info-card {
    background: rgba(30, 41, 59, 0.5);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md);
    padding: 0.85rem 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.55rem;
  }

  .info-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 0.78rem;
  }

  .info-label {
    color: var(--text-muted);
  }

  .state-pill {
    font-weight: 700;
    font-size: 0.7rem;
    padding: 0.15rem 0.5rem;
    background: rgba(16, 185, 129, 0.15);
    color: var(--brand-400);
    border-radius: var(--radius-full);
    border: 1px solid rgba(16, 185, 129, 0.3);
  }

  .agent-value.initiator {
    color: var(--cyan-400);
  }

  .agent-value.executor {
    color: var(--brand-400);
  }

  .time-value, .memory-value {
    color: var(--text-secondary);
  }

  .section {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .section-title {
    display: flex;
    align-items: center;
    gap: 0.45rem;
    font-size: 0.82rem;
    font-weight: 700;
    color: var(--text-secondary);
  }

  .spec-box {
    background: rgba(9, 13, 22, 0.8);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    padding: 0.75rem;
    overflow-x: auto;
    font-size: 0.75rem;
    color: var(--text-secondary);
  }

  .conditions-list {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .condition-item {
    font-size: 0.78rem;
    color: var(--text-secondary);
    display: flex;
    align-items: flex-start;
    gap: 0.45rem;
    background: rgba(30, 41, 59, 0.3);
    padding: 0.45rem 0.65rem;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-subtle);
  }

  .condition-item .bullet {
    color: var(--cyan-400);
  }

  .timeline {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    position: relative;
    padding-left: 1rem;
    border-left: 2px solid var(--border-medium);
    margin-left: 0.5rem;
  }

  .timeline-item {
    position: relative;
  }

  .timeline-dot {
    position: absolute;
    left: -1.35rem;
    top: 0.45rem;
    width: 10px;
    height: 10px;
    border-radius: 50%;
  }

  .act-card {
    background: rgba(30, 41, 59, 0.5);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    padding: 0.65rem 0.85rem;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .act-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 0.68rem;
    gap: 0.35rem;
  }

  .act-type {
    font-weight: 700;
  }

  .act-actor {
    color: var(--text-secondary);
  }

  .act-time {
    color: var(--text-faint);
  }

  .act-message {
    font-size: 0.78rem;
    color: var(--text-primary);
    line-height: 1.4;
  }

  .act-payload {
    font-size: 0.68rem;
    color: var(--text-muted);
    background: rgba(0, 0, 0, 0.3);
    padding: 0.35rem;
    border-radius: var(--radius-sm);
    overflow-x: auto;
  }

  .empty-state {
    font-size: 0.75rem;
    color: var(--text-faint);
    padding: 1rem;
    text-align: center;
    border: 1px dashed var(--border-subtle);
    border-radius: var(--radius-sm);
  }
</style>
