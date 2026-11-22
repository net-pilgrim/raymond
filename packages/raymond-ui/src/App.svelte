<script lang="ts">
  import { onMount } from 'svelte';
  import Navbar from './lib/components/Navbar.svelte';
  import KanbanBoard from './lib/components/KanbanBoard.svelte';
  import GraphView from './lib/components/GraphView.svelte';
  import TransactionDrawer from './lib/components/TransactionDrawer.svelte';
  import InspectorDrawer from './lib/components/InspectorDrawer.svelte';
  import SettingsModal from './lib/components/SettingsModal.svelte';
  import ConnectModal from './lib/components/ConnectModal.svelte';
  import {
    fetchTransactions, fetchGraphData, getStoredCredentials,
    createRelationInDb, deleteRelationFromDb, deleteEntityFromDb
  } from './lib/supabase';
  import { DEMO_TRANSACTIONS, DEMO_GRAPH_DATA } from './lib/demoData';
  import type { Transaction, KnowledgeGraphData, Relation } from './lib/types';

  let activeTab: 'graph' | 'kanban' = 'kanban';
  let connectionStatus: 'connected' | 'demo' | 'error' = 'connected';
  let isSettingsOpen = false;

  let isConnectModalOpen = false;
  let connectInitialSourceId = '';

  let transactions: Transaction[] = DEMO_TRANSACTIONS;
  let graphData: KnowledgeGraphData = DEMO_GRAPH_DATA;

  let selectedTransaction: Transaction | null = null;
  let selectedEntity: any = null;

  let graphViewComponent: GraphView | null = null;

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

  function handleInspectNodeId(nodeId: string) {
    const ent = graphData.entities.find(e => e.id === nodeId);
    if (ent) {
      selectedEntity = ent;
    }
  }

  function handleFocusNeighborhood(entityId: string) {
    if (graphViewComponent && graphViewComponent.focusNeighborhood) {
      graphViewComponent.focusNeighborhood(entityId);
    }
  }

  function openConnectModal(sourceId: string = '') {
    connectInitialSourceId = sourceId;
    isConnectModalOpen = true;
  }

  async function handleCreateRelation(sourceId: string, targetId: string, predicate: string) {
    const newRel: Relation = {
      id: 'rel_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6),
      src: sourceId,
      dst: targetId,
      predicate,
      valid_from: new Date().toISOString(),
      valid_to: null,
      metadata: { created_via: 'manual_dialog', created_at: new Date().toISOString() }
    };

    graphData.relations = [...graphData.relations, newRel];
    graphData = { ...graphData };

    await createRelationInDb(newRel);
  }

  async function handleDeleteRelation(relationId: string) {
    graphData.relations = graphData.relations.filter(r => r.id !== relationId);
    graphData = { ...graphData };

    await deleteRelationFromDb(relationId);
  }

  async function handleDeleteEntity(entityId: string) {
    graphData.entities = graphData.entities.filter(e => e.id !== entityId);
    graphData.relations = graphData.relations.filter(r => {
      const s = r.src || (r as any).source_id;
      const d = r.dst || (r as any).target_id;
      return s !== entityId && d !== entityId;
    });
    graphData = { ...graphData };
    selectedEntity = null;

    await deleteEntityFromDb(entityId);
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
        bind:this={graphViewComponent}
        {graphData}
        onSelectEntity={handleSelectEntity}
        onOpenConnectModal={openConnectModal}
      />
    {/if}
  </main>

  <TransactionDrawer
    transaction={selectedTransaction}
    onClose={() => (selectedTransaction = null)}
  />

  <InspectorDrawer
    selectedItem={selectedEntity}
    allEntities={graphData.entities}
    allRelations={graphData.relations}
    allMemories={graphData.memories}
    memoryEntities={graphData.memory_entities}
    onClose={() => (selectedEntity = null)}
    onInspectNode={handleInspectNodeId}
    onOpenConnectModal={openConnectModal}
    onFocusNeighborhood={handleFocusNeighborhood}
    onDeleteRelation={handleDeleteRelation}
    onDeleteEntity={handleDeleteEntity}
  />

  <ConnectModal
    isOpen={isConnectModalOpen}
    entities={graphData.entities}
    initialSourceId={connectInitialSourceId}
    onClose={() => (isConnectModalOpen = false)}
    onConnect={handleCreateRelation}
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
