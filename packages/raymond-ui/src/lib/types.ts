export type TransactionState =
  | 'REQUESTED'
  | 'CONDITIONAL_PROMISE'
  | 'PROMISED'
  | 'IN_EXECUTION'
  | 'DECLARED'
  | 'REJECTED'
  | 'ACCEPTED'
  | 'DECLINED'
  | 'REVOKED';

export type CoordinationActType =
  | 'REQUEST'
  | 'PROMISE'
  | 'DECLINE'
  | 'FULFILL_CONDITIONS'
  | 'DECLARE'
  | 'REJECT'
  | 'ACCEPT'
  | 'REVOKE';

export interface CoordinationAct {
  id: number;
  transaction_id: string;
  act_type: CoordinationActType;
  actor_id: string;
  role: 'INITIATOR' | 'EXECUTOR' | 'OBSERVER';
  message: string;
  payload: Record<string, any>;
  created_at: string;
}

export interface Transaction {
  id: string;
  parent_id?: string | null;
  session_id?: string | null;
  initiator_id: string;
  executor_id: string;
  state: TransactionState;
  p_fact_type: string;
  p_fact_spec: Record<string, any>;
  conditions: any[];
  review_sla_seconds: number;
  deliverables: Record<string, any>;
  evidence: Record<string, any>;
  assessment: Record<string, any>;
  memory_id?: string | null;
  created_at: string;
  updated_at: string;
  acts?: CoordinationAct[];
}

export interface Entity {
  id: string;
  name: string;
  type: 'concept' | 'component' | 'technology' | 'decision' | 'agent' | 'system' | 'tool' | 'memory' | string;
  aliases?: string[];
  metadata?: Record<string, any>;
  created_at?: string;
  updated_at?: string;
}

export interface Relation {
  id: string;
  src?: string;
  dst?: string;
  source_id?: string;
  target_id?: string;
  predicate: string;
  valid_from?: string;
  valid_to?: string | null;
  metadata?: Record<string, any>;
}

export interface Memory {
  id: string;
  content: string;
  author_agent?: string;
  category?: string;
  tags?: string[];
  created_at: string;
}

export interface KnowledgeGraphData {
  entities: Entity[];
  relations: Relation[];
  memories: Memory[];
  memory_entities: Array<{ memory_id: string; entity_id: string }>;
}
