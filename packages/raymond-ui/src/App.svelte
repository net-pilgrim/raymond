<script lang="ts">
  import { onMount } from 'svelte';
  import Navbar from './lib/components/Navbar.svelte';
  import KanbanBoard from './lib/components/KanbanBoard.svelte';
  import GraphView from './lib/components/GraphView.svelte';
  import TransactionDrawer from './lib/components/TransactionDrawer.svelte';
  import InspectorDrawer from './lib/components/InspectorDrawer.svelte';
  import SettingsModal from './lib/components/SettingsModal.svelte';
  import { fetchTransactions, fetchGraphData, getStoredCredentials } from './lib/supabase';
  import { DEMO_TRANSACTIONS, DEMO_GRAPH_DATA } from './lib/demoData';
  import type { Transaction, KnowledgeGraphData } from './lib/types';

  let activeTab: 'graph' | 'kanban' = 'kanban';
  let connectionStatus: 'connected' | 'demo' | 'error' = 'connected';
  let isSettingsOpen = false;

  let transactions: Transaction[] = DEMO_TRANSACTIONS;
  let graphData: KnowledgeGraphData = DEMO_GRAPH_DATA;

  let selectedTransaction: Transaction | null = null;
  let selectedEntity: any = null;

  async function loadData() {
    const creds = getStoredCredentials();
    try {
      const [txs, gData] = await Promise.all([
        fetchTransactions(creds.url, creds.key),
        fetchGraphData(creds.url, creds.key)
      ]);
      transactions = txs;
      graphData = gData;
      connectionStatus = (txs === DEMO_TRANSACTIONS || gData === DEMO_GRAPH_DATA) ? 'demo' : 'connected';
    } catch (e) {
      console.warn('Error loading remote data, using demo:', e);
      transactions = DEMO_TRANSACTIONS;
      graphData = DEMO_GRAPH_DATA;
      connectionStatus = 'demo';
    }
  }

  function handleSelectTransaction(tx: Transaction) {
    selectedTransaction = tx;
  }

  function handleSelectEntity(ent: any) {
    selectedEntity = ent;
  }

  function handleLoadDemo() {
    transactions = DEMO_TRANSACTIONS;
    graphData = DEMO_GRAPH_DATA;
    connectionStatus = 'demo';
    isSettingsOpen = false;
  }

  onMount(() => {
    loadData();
  });
</script>

<div class="app-layout">
  <Navbar
    bind:activeTab
    {connectionStatus}
    onRefresh={loadData}
    onOpenSettings={() => (isSettingsOpen = true)}
  />

  <main class="main-content">
    {#if activeTab === 'kanban'}
      <KanbanBoard
        {transactions}
        onSelectTransaction={handleSelectTransaction}
      />
    {:else}
      <GraphView
        {graphData}
        onSelectEntity={handleSelectEntity}
      />
    {/if}
  </main>

  <TransactionDrawer
    transaction={selectedTransaction}
    onClose={() => (selectedTransaction = null)}
  />

  <InspectorDrawer
    selectedItem={selectedEntity}
    onClose={() => (selectedEntity = null)}
  />

  <SettingsModal
    isOpen={isSettingsOpen}
    onClose={() => (isSettingsOpen = false)}
    onCredentialsSaved={loadData}
    onLoadDemo={handleLoadDemo}
  />
</div>

<style>
  .app-layout {
    width: 100vw;
    height: 100vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .main-content {
    flex: 1;
    overflow: hidden;
    position: relative;
  }
</style>
