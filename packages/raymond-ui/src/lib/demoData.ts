import type { Transaction, KnowledgeGraphData } from './types';

export const DEMO_TRANSACTIONS: Transaction[] = [
  {
    id: 'tx_20261122_arch001',
    initiator_id: 'architect_agent',
    executor_id: 'security_auditor_agent',
    state: 'REQUESTED',
    p_fact_type: 'security_audit',
    p_fact_spec: {
      scope: 'Supabase Edge MCP Function Authentication',
      guidelines: 'Verify RLS policies and JWT bypass vectors',
      target: 'supabase/functions/mcp/index.ts',
    },
    conditions: [
      { id: 'c1', description: 'Complete static analysis with zero high-severity findings' },
      { id: 'c2', description: 'Deliver report within 4 hours' }
    ],
    review_sla_seconds: 14400,
    deliverables: {},
    evidence: {},
    assessment: {},
    created_at: new Date(Date.now() - 3600000 * 2).toISOString(),
    updated_at: new Date(Date.now() - 3600000 * 2).toISOString(),
    acts: [
      {
        id: 1,
        transaction_id: 'tx_20261122_arch001',
        act_type: 'REQUEST',
        actor_id: 'architect_agent',
        role: 'INITIATOR',
        message: 'Requesting formal security audit of MCP authentication guard before production deploy.',
        payload: { target: 'supabase/functions/mcp/index.ts' },
        created_at: new Date(Date.now() - 3600000 * 2).toISOString(),
      }
    ]
  },
  {
    id: 'tx_20261122_data002',
    initiator_id: 'lead_orchestrator',
    executor_id: 'data_engineer_agent',
    state: 'PROMISED',
    p_fact_type: 'migration_execution',
    p_fact_spec: {
      target_migration: '20261122000000_dietz_burgess_protocol.sql',
      verification: 'Run test queries on public.transactions and public.coordination_acts',
    },
    conditions: [
      { id: 'c1', description: 'Must apply idempotently without dropping existing memories' }
    ],
    review_sla_seconds: 7200,
    deliverables: {},
    evidence: {},
    assessment: {},
    created_at: new Date(Date.now() - 3600000 * 5).toISOString(),
    updated_at: new Date(Date.now() - 3600000 * 3).toISOString(),
    acts: [
      {
        id: 2,
        transaction_id: 'tx_20261122_data002',
        act_type: 'REQUEST',
        actor_id: 'lead_orchestrator',
        role: 'INITIATOR',
        message: 'Execute Dietz-Burgess protocol database migration on staging.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 5).toISOString(),
      },
      {
        id: 3,
        transaction_id: 'tx_20261122_data002',
        act_type: 'PROMISE',
        actor_id: 'data_engineer_agent',
        role: 'EXECUTOR',
        message: 'I promise to apply migration and verify table constraints by 14:00 UTC.',
        payload: { guaranteed_sla_seconds: 3600 },
        created_at: new Date(Date.now() - 3600000 * 3).toISOString(),
      }
    ]
  },
  {
    id: 'tx_20261122_dev003',
    initiator_id: 'product_owner_agent',
    executor_id: 'frontend_agent',
    state: 'IN_EXECUTION',
    p_fact_type: 'ui_implementation',
    p_fact_spec: {
      component: 'KanbanBoard.svelte',
      requirements: 'Multi-column Dietz-Burgess transaction state visualization with drag inspection',
      technology: 'Svelte 5 + bespoke CSS',
    },
    conditions: [
      { id: 'c1', description: 'Zero Tailwind CSS' },
      { id: 'c2', description: 'Responsive drawer inspection' }
    ],
    review_sla_seconds: 7200,
    deliverables: { branch: 'feat/svelte-kanban-board' },
    evidence: { test_suite: 'unit tests passing' },
    assessment: {},
    created_at: new Date(Date.now() - 3600000 * 8).toISOString(),
    updated_at: new Date(Date.now() - 3600000 * 1).toISOString(),
    acts: [
      {
        id: 4,
        transaction_id: 'tx_20261122_dev003',
        act_type: 'REQUEST',
        actor_id: 'product_owner_agent',
        role: 'INITIATOR',
        message: 'Build a dedicated Kanban board in Svelte for tracking agent promises and handovers.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 8).toISOString(),
      },
      {
        id: 5,
        transaction_id: 'tx_20261122_dev003',
        act_type: 'PROMISE',
        actor_id: 'frontend_agent',
        role: 'EXECUTOR',
        message: 'Promised. Building component library with pure CSS design tokens.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 6).toISOString(),
      }
    ]
  },
  {
    id: 'tx_20261122_qa004',
    initiator_id: 'frontend_agent',
    executor_id: 'qa_agent',
    state: 'DECLARED',
    p_fact_type: 'browser_validation',
    p_fact_spec: {
      url: 'http://localhost:5173',
      checks: ['Knowledge Graph rendering', 'Kanban column filtering', 'Audit drawer'],
    },
    conditions: [],
    review_sla_seconds: 3600,
    deliverables: {
      report_url: 'artifacts/qa_report_20261122.md',
      browsers_tested: ['Chromium 125', 'Firefox 128', 'Safari 17.4'],
    },
    evidence: {
      screenshot_timeline: ['kanban_view.png', 'drawer_view.png'],
      exit_code: 0,
    },
    assessment: {},
    created_at: new Date(Date.now() - 3600000 * 12).toISOString(),
    updated_at: new Date(Date.now() - 1800000).toISOString(),
    acts: [
      {
        id: 6,
        transaction_id: 'tx_20261122_qa004',
        act_type: 'REQUEST',
        actor_id: 'frontend_agent',
        role: 'INITIATOR',
        message: 'Validate cross-browser rendering and mobile responsive breakpoints.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 12).toISOString(),
      },
      {
        id: 7,
        transaction_id: 'tx_20261122_qa004',
        act_type: 'DECLARE',
        actor_id: 'qa_agent',
        role: 'EXECUTOR',
        message: 'I declare that browser validation passed with 100% test coverage.',
        payload: { summary: 'All columns render with zero layout shift' },
        created_at: new Date(Date.now() - 1800000).toISOString(),
      }
    ]
  },
  {
    id: 'tx_20261122_core005',
    initiator_id: 'lead_orchestrator',
    executor_id: 'database_agent',
    state: 'ACCEPTED',
    p_fact_type: 'p_fact_grounding',
    p_fact_spec: {
      title: 'HNSW Index Calibration for 768-dim Vectors',
      statement: 'Set m=16, ef_construction=64 on public.memories for optimal recall under free-tier memory constraints.',
    },
    conditions: [],
    review_sla_seconds: 3600,
    deliverables: { sql_patch: 'ALTER INDEX idx_memories_embedding SET (m = 16, ef_construction = 64);' },
    evidence: { p99_latency_ms: 18.4, recall_rate: 0.985 },
    assessment: { verdict: 'ACCEPTED', score: 100, comments: 'Verified on production staging' },
    memory_id: '00000000-0000-0000-0000-000000000001',
    created_at: new Date(Date.now() - 3600000 * 24).toISOString(),
    updated_at: new Date(Date.now() - 3600000 * 20).toISOString(),
    acts: [
      {
        id: 8,
        transaction_id: 'tx_20261122_core005',
        act_type: 'REQUEST',
        actor_id: 'lead_orchestrator',
        role: 'INITIATOR',
        message: 'Calibrate HNSW index parameters.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 24).toISOString(),
      },
      {
        id: 9,
        transaction_id: 'tx_20261122_core005',
        act_type: 'DECLARE',
        actor_id: 'database_agent',
        role: 'EXECUTOR',
        message: 'Parameters set and benchmarked.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 21).toISOString(),
      },
      {
        id: 10,
        transaction_id: 'tx_20261122_core005',
        act_type: 'ACCEPT',
        actor_id: 'lead_orchestrator',
        role: 'INITIATOR',
        message: 'Deliverables verified. Promise kept! Auto-grounded to Knowledge Graph.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 20).toISOString(),
      }
    ]
  },
  {
    id: 'tx_20261122_rev006',
    initiator_id: 'lead_orchestrator',
    executor_id: 'legacy_worker_agent',
    state: 'REVOKED',
    p_fact_type: 'daemon_setup',
    p_fact_spec: { target: 'background polling cron' },
    conditions: [],
    review_sla_seconds: 3600,
    deliverables: {},
    evidence: {},
    assessment: { reason: 'Superseded by pure serverless reactive edge architecture' },
    created_at: new Date(Date.now() - 3600000 * 30).toISOString(),
    updated_at: new Date(Date.now() - 3600000 * 28).toISOString(),
    acts: [
      {
        id: 11,
        transaction_id: 'tx_20261122_rev006',
        act_type: 'REQUEST',
        actor_id: 'lead_orchestrator',
        role: 'INITIATOR',
        message: 'Set up background polling daemon.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 30).toISOString(),
      },
      {
        id: 12,
        transaction_id: 'tx_20261122_rev006',
        act_type: 'REVOKE',
        actor_id: 'lead_orchestrator',
        role: 'INITIATOR',
        message: 'Revoked: Raymond architecture prohibits local background daemon processes.',
        payload: {},
        created_at: new Date(Date.now() - 3600000 * 28).toISOString(),
      }
    ]
  }
];

export const DEMO_GRAPH_DATA: KnowledgeGraphData = {
  entities: [
    { id: 'e1', name: 'Raymond Engine', type: 'system', aliases: ['mnesia', 'raymond-core'] },
    { id: 'e2', name: 'Supabase Edge MCP', type: 'component', aliases: ['mcp-server'] },
    { id: 'e3', name: 'PostgreSQL + pgvector', type: 'technology', aliases: ['supabase-db'] },
    { id: 'e4', name: 'Dietz-Burgess Protocol', type: 'concept', aliases: ['p-facts', 'promise-theory'] },
    { id: 'e5', name: 'Interactive Svelte UI', type: 'component', aliases: ['raymond-ui'] },
    { id: 'e6', name: 'Google Gemini 768-dim', type: 'technology', aliases: ['gemini-embeddings'] },
    { id: 'e7', name: 'Lead Orchestrator', type: 'agent', aliases: ['coordinator'] },
    { id: 'e8', name: 'Zero Tailwind Rule', type: 'decision', aliases: ['pure-css'] },
    { id: 'm1', name: 'Memory: Stateless Agent Coordination', type: 'memory' }
  ],
  relations: [
    { id: 'r1', source_id: 'e1', target_id: 'e2', predicate: 'implements', valid_from: '2026-11-15T00:00:00Z' },
    { id: 'r2', source_id: 'e2', target_id: 'e3', predicate: 'persists_to', valid_from: '2026-11-15T00:00:00Z' },
    { id: 'r3', source_id: 'e2', target_id: 'e4', predicate: 'enforces', valid_from: '2026-11-22T00:00:00Z' },
    { id: 'r4', source_id: 'e1', target_id: 'e5', predicate: 'visualized_by', valid_from: '2026-11-22T00:00:00Z' },
    { id: 'r5', source_id: 'e2', target_id: 'e6', predicate: 'embeds_via', valid_from: '2026-11-15T00:00:00Z' },
    { id: 'r6', source_id: 'e7', target_id: 'e4', predicate: 'coordinates_via', valid_from: '2026-11-22T00:00:00Z' },
    { id: 'r7', source_id: 'e5', target_id: 'e8', predicate: 'follows', valid_from: '2026-11-22T00:00:00Z' },
    { id: 'r8', source_id: 'm1', target_id: 'e4', predicate: 'references', valid_from: '2026-11-22T00:00:00Z' }
  ],
  memories: [
    {
      id: 'm1',
      author_agent: 'lead_orchestrator',
      category: 'architecture',
      tags: ['dietz-burgess', 'coordination', 'p-facts'],
      content: 'Multi-agent fleets must coordinate via explicit Dietz DEMO transaction cycles: Request ➔ Promise ➔ Declare ➔ Accept. Every accepted transaction is permanently recorded and grounded into Raymond Knowledge Graph entities.',
      created_at: '2026-11-22T10:00:00Z'
    }
  ],
  memory_entities: [
    { memory_id: 'm1', entity_id: 'e4' }
  ]
};
