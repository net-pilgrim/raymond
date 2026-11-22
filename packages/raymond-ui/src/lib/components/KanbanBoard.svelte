<script lang="ts">
  import type { Transaction } from '../types';
  import TransactionCard from './TransactionCard.svelte';
  import { Search, Filter, Layers, CheckCircle2, Activity, ShieldAlert } from '@lucide/svelte';

  export let transactions: Transaction[] = [];
  export let onSelectTransaction: (tx: Transaction) => void;

  let searchQuery = '';
  let selectedAgent = 'ALL';

  $: allAgents = Array.from(
    new Set(transactions.flatMap(tx => [tx.initiator_id, tx.executor_id]))
  ).filter(Boolean);

  $: filteredTransactions = transactions.filter(tx => {
    if (selectedAgent !== 'ALL' && tx.initiator_id !== selectedAgent && tx.executor_id !== selectedAgent) {
      return false;
    }
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      tx.id.toLowerCase().includes(q) ||
      tx.p_fact_type.toLowerCase().includes(q) ||
      tx.initiator_id.toLowerCase().includes(q) ||
      tx.executor_id.toLowerCase().includes(q) ||
      JSON.stringify(tx.p_fact_spec).toLowerCase().includes(q)
    );
  });

  interface Column {
    id: string;
    title: string;
    states: string[];
    color: string;
    bg: string;
  }

  const columns: Column[] = [
    {
      id: 'requested',
      title: 'Requested',
      states: ['REQUESTED'],
      color: '#fbbf24',
      bg: 'rgba(251, 191, 36, 0.1)',
    },
    {
      id: 'promised',
      title: 'Promised / Conditions',
      states: ['CONDITIONAL_PROMISE', 'PROMISED'],
      color: '#38bdf8',
      bg: 'rgba(56, 189, 248, 0.1)',
    },
    {
      id: 'execution',
      title: 'In Execution',
      states: ['IN_EXECUTION'],
      color: '#818cf8',
      bg: 'rgba(129, 140, 248, 0.1)',
    },
    {
      id: 'declared',
      title: 'Declared / Review',
      states: ['DECLARED'],
      color: '#c084fc',
      bg: 'rgba(192, 132, 252, 0.1)',
    },
    {
      id: 'accepted',
      title: 'Accepted (Kept)',
      states: ['ACCEPTED'],
      color: '#34d399',
      bg: 'rgba(52, 211, 153, 0.1)',
    },
    {
      id: 'closed',
      title: 'Declined / Revoked',
      states: ['DECLINED', 'REJECTED', 'REVOKED'],
      color: '#f43f5e',
      bg: 'rgba(244, 63, 94, 0.1)',
    },
  ];

  function getTxsForColumn(col: Column) {
    return filteredTransactions.filter(tx => col.states.includes(tx.state));
  }

  $: totalTxs = transactions.length;
  $: activeTxs = transactions.filter(t => ['REQUESTED', 'PROMISED', 'CONDITIONAL_PROMISE', 'IN_EXECUTION', 'DECLARED'].includes(t.state)).length;
  $: acceptedTxs = transactions.filter(t => t.state === 'ACCEPTED').length;
  $: completionRate = totalTxs > 0 ? Math.round((acceptedTxs / totalTxs) * 100) : 0;
</script>

<div class="kanban-wrapper">
  <!-- Top Controls & Metrics Bar -->
  <div class="toolbar">
    <div class="filter-controls">
      <div class="search-input-box">
        <Search size={14} class="search-icon" />
        <input
          type="text"
          bind:value={searchQuery}
          placeholder="Filter by ID, P-fact, agent, spec..."
        />
      </div>

      <div class="agent-filter-box">
        <Filter size={14} class="filter-icon" />
        <select bind:value={selectedAgent}>
          <option value="ALL">All Fleet Agents</option>
          {#each allAgents as agent}
            <option value={agent}>{agent}</option>
          {/each}
        </select>
      </div>
    </div>

    <div class="metrics-row font-mono">
      <div class="metric-item">
        <Layers size={13} class="metric-icon" />
        <span class="metric-label">Total:</span>
        <span class="metric-value">{totalTxs}</span>
      </div>
      <div class="metric-item in-flight">
        <Activity size={13} class="metric-icon" />
        <span class="metric-label">In-Flight:</span>
        <span class="metric-value">{activeTxs}</span>
      </div>
      <div class="metric-item kept">
        <CheckCircle2 size={13} class="metric-icon" />
        <span class="metric-label">Kept:</span>
        <span class="metric-value">{acceptedTxs} ({completionRate}%)</span>
      </div>
    </div>
  </div>

  <!-- Board Columns Grid -->
  <div class="columns-container">
    {#each columns as col}
      {@const colTxs = getTxsForColumn(col)}
      <div class="kanban-column">
        <div class="col-header" style="border-top-color: {col.color}">
          <div class="col-title-group">
            <span class="col-title">{col.title}</span>
            <span
              class="col-badge font-mono"
              style="color: {col.color}; background: {col.bg}"
            >
              {colTxs.length}
            </span>
          </div>
        </div>

        <div class="col-cards-list">
          {#if colTxs.length > 0}
            {#each colTxs as tx (tx.id)}
              <TransactionCard transaction={tx} onSelect={onSelectTransaction} />
            {/each}
          {:else}
            <div class="col-empty font-mono">
              No transactions
            </div>
          {/if}
        </div>
      </div>
    {/each}
  </div>
</div>

<style>
  .kanban-wrapper {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow: hidden;
    height: calc(100vh - 56px);
  }

  .toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem 1.25rem;
    background: rgba(15, 23, 42, 0.6);
    border-bottom: 1px solid var(--border-subtle);
    gap: 1rem;
    flex-wrap: wrap;
    flex-shrink: 0;
  }

  .filter-controls {
    display: flex;
    align-items: center;
    gap: 0.65rem;
    flex: 1;
    max-width: 600px;
  }

  .search-input-box, .agent-filter-box {
    position: relative;
    display: flex;
    align-items: center;
  }

  .search-input-box {
    flex: 1;
  }

  .search-input-box input {
    width: 100%;
    padding-left: 2rem;
    height: 32px;
    font-size: 0.8rem;
  }

  .agent-filter-box select {
    padding-left: 2rem;
    height: 32px;
    font-size: 0.8rem;
    cursor: pointer;
  }

  :global(.search-icon), :global(.filter-icon) {
    position: absolute;
    left: 0.65rem;
    color: var(--text-muted);
    pointer-events: none;
  }

  .metrics-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 0.72rem;
  }

  .metric-item {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.25rem 0.6rem;
    background: rgba(30, 41, 59, 0.4);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
  }

  .metric-item.in-flight {
    color: var(--cyan-400);
    border-color: rgba(56, 189, 248, 0.25);
  }

  .metric-item.kept {
    color: var(--brand-400);
    border-color: rgba(52, 211, 153, 0.25);
  }

  .metric-label {
    color: var(--text-muted);
  }

  .metric-value {
    font-weight: 700;
  }

  .columns-container {
    display: grid;
    grid-template-columns: repeat(6, minmax(280px, 1fr));
    gap: 0.85rem;
    padding: 1rem 1.25rem;
    overflow-x: auto;
    overflow-y: hidden;
    flex: 1;
  }

  .kanban-column {
    display: flex;
    flex-direction: column;
    background: rgba(15, 23, 42, 0.45);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md);
    overflow: hidden;
    min-height: 0;
  }

  .col-header {
    padding: 0.75rem 0.85rem;
    background: rgba(15, 23, 42, 0.75);
    border-bottom: 1px solid var(--border-subtle);
    border-top: 3px solid transparent;
  }

  .col-title-group {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .col-title {
    font-size: 0.82rem;
    font-weight: 700;
    color: var(--text-primary);
  }

  .col-badge {
    font-size: 0.7rem;
    font-weight: 700;
    padding: 0.1rem 0.45rem;
    border-radius: var(--radius-full);
  }

  .col-cards-list {
    flex: 1;
    overflow-y: auto;
    padding: 0.75rem;
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }

  .col-empty {
    font-size: 0.72rem;
    color: var(--text-faint);
    text-align: center;
    padding: 2rem 0.5rem;
    border: 1px dashed var(--border-subtle);
    border-radius: var(--radius-sm);
    margin-top: 0.5rem;
  }
</style>
