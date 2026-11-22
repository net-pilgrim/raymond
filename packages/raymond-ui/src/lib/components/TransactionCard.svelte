<script lang="ts">
  import type { Transaction } from '../types';
  import { ArrowRight, FileCheck, CheckCircle2, Clock, AlertCircle } from '@lucide/svelte';

  export let transaction: Transaction;
  export let onSelect: (tx: Transaction) => void;

  function getStateTheme(state: string) {
    switch (state) {
      case 'REQUESTED':
        return { label: 'Requested', bg: 'rgba(251, 191, 36, 0.15)', text: '#fbbf24', border: 'rgba(251, 191, 36, 0.4)' };
      case 'CONDITIONAL_PROMISE':
        return { label: 'Conditional', bg: 'rgba(96, 165, 250, 0.15)', text: '#60a5fa', border: 'rgba(96, 165, 250, 0.4)' };
      case 'PROMISED':
        return { label: 'Promised', bg: 'rgba(56, 189, 248, 0.15)', text: '#38bdf8', border: 'rgba(56, 189, 248, 0.4)' };
      case 'IN_EXECUTION':
        return { label: 'In Execution', bg: 'rgba(129, 140, 248, 0.15)', text: '#818cf8', border: 'rgba(129, 140, 248, 0.4)' };
      case 'DECLARED':
        return { label: 'Declared', bg: 'rgba(192, 132, 252, 0.15)', text: '#c084fc', border: 'rgba(192, 132, 252, 0.4)' };
      case 'ACCEPTED':
        return { label: 'Accepted (Kept)', bg: 'rgba(16, 185, 129, 0.15)', text: '#34d399', border: 'rgba(16, 185, 129, 0.4)' };
      case 'REJECTED':
        return { label: 'Rejected', bg: 'rgba(244, 63, 94, 0.15)', text: '#f43f5e', border: 'rgba(244, 63, 94, 0.4)' };
      case 'DECLINED':
        return { label: 'Declined', bg: 'rgba(100, 116, 139, 0.15)', text: '#94a3b8', border: 'rgba(100, 116, 139, 0.4)' };
      case 'REVOKED':
        return { label: 'Revoked', bg: 'rgba(239, 68, 68, 0.15)', text: '#ef4444', border: 'rgba(239, 68, 68, 0.4)' };
      default:
        return { label: state, bg: 'rgba(255, 255, 255, 0.1)', text: '#e2e8f0', border: 'rgba(255, 255, 255, 0.2)' };
    }
  }

  $: theme = getStateTheme(transaction.state);
  $: hasDeliverables = transaction.deliverables && Object.keys(transaction.deliverables).length > 0;
  $: hasEvidence = transaction.evidence && Object.keys(transaction.evidence).length > 0;
  $: specSummary = transaction.p_fact_spec?.scope || transaction.p_fact_spec?.title || transaction.p_fact_spec?.statement || transaction.p_fact_spec?.component || 'No detailed spec summary';

  function formatTime(iso: string) {
    try {
      const d = new Date(iso);
      return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } catch (_) {
      return '';
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="card" on:click={() => onSelect(transaction)}>
  <div class="card-header">
    <span class="p-fact-pill font-mono">{transaction.p_fact_type}</span>
    <span
      class="state-badge font-mono"
      style="background: {theme.bg}; color: {theme.text}; border-color: {theme.border}"
    >
      {theme.label}
    </span>
  </div>

  <div class="card-body">
    <div class="tx-id font-mono">{transaction.id}</div>
    <div class="summary-text">{specSummary}</div>
  </div>

  <div class="agents-flow font-mono">
    <span class="agent-pill initiator" title="Initiator: {transaction.initiator_id}">{transaction.initiator_id}</span>
    <ArrowRight size={12} class="flow-icon" />
    <span class="agent-pill executor" title="Executor: {transaction.executor_id}">{transaction.executor_id}</span>
  </div>

  <div class="card-footer">
    <div class="badges-row">
      {#if hasDeliverables}
        <span class="indicator-pill deliverables" title="Has Deliverables">
          <FileCheck size={11} />
          <span>Deliverables</span>
        </span>
      {/if}
      {#if hasEvidence}
        <span class="indicator-pill evidence" title="Has Evidence">
          <CheckCircle2 size={11} />
          <span>Evidence</span>
        </span>
      {/if}
      {#if transaction.acts && transaction.acts.length > 0}
        <span class="indicator-pill acts-count" title="{transaction.acts.length} Coordination Acts">
          {transaction.acts.length} acts
        </span>
      {/if}
    </div>
    <div class="time-stamp font-mono">{formatTime(transaction.updated_at || transaction.created_at)}</div>
  </div>
</div>

<style>
  .card {
    background: var(--bg-card);
    backdrop-filter: blur(8px);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md);
    padding: 0.85rem;
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
    cursor: pointer;
    transition: transform var(--transition-fast), border-color var(--transition-fast), background-color var(--transition-fast), box-shadow var(--transition-fast);
  }

  .card:hover {
    background: var(--bg-card-hover);
    border-color: var(--border-medium);
    transform: translateY(-2px);
    box-shadow: var(--shadow-md);
  }

  .card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
  }

  .p-fact-pill {
    font-size: 0.68rem;
    font-weight: 600;
    padding: 0.15rem 0.45rem;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-secondary);
    border: 1px solid var(--border-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 140px;
  }

  .state-badge {
    font-size: 0.65rem;
    font-weight: 700;
    padding: 0.15rem 0.5rem;
    border-radius: var(--radius-full);
    border: 1px solid transparent;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    white-space: nowrap;
  }

  .card-body {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .tx-id {
    font-size: 0.7rem;
    color: var(--text-faint);
    letter-spacing: -0.01em;
  }

  .summary-text {
    font-size: 0.82rem;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.35;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .agents-flow {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    font-size: 0.7rem;
    padding: 0.35rem 0.5rem;
    background: rgba(15, 23, 42, 0.6);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-subtle);
  }

  .agent-pill {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 90px;
  }

  .agent-pill.initiator {
    color: var(--cyan-400);
  }

  .agent-pill.executor {
    color: var(--brand-400);
  }

  :global(.flow-icon) {
    color: var(--text-faint);
    flex-shrink: 0;
  }

  .card-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
    padding-top: 0.25rem;
    border-top: 1px solid var(--border-subtle);
  }

  .badges-row {
    display: flex;
    align-items: center;
    gap: 0.35rem;
  }

  .indicator-pill {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.65rem;
    padding: 0.12rem 0.35rem;
    border-radius: var(--radius-sm);
    font-weight: 500;
  }

  .indicator-pill.deliverables {
    background: rgba(96, 165, 250, 0.12);
    color: #60a5fa;
  }

  .indicator-pill.evidence {
    background: rgba(52, 211, 153, 0.12);
    color: #34d399;
  }

  .indicator-pill.acts-count {
    background: rgba(255, 255, 255, 0.05);
    color: var(--text-muted);
    font-family: var(--font-mono);
  }

  .time-stamp {
    font-size: 0.68rem;
    color: var(--text-faint);
  }
</style>
