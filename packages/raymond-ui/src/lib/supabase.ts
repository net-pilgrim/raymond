import type { Transaction, KnowledgeGraphData, CoordinationAct, Relation, Entity } from './types';
import { DEMO_TRANSACTIONS, DEMO_GRAPH_DATA } from './demoData';

export const DEFAULT_SUPABASE_URL = 'https://zmocedvkqrcxwkthmwql.supabase.co';
export const DEFAULT_SUPABASE_KEY = 'sb_publishable_Mtm9durpa0BqJilrDDP3Sw_emjdGVfY';

export function getStoredCredentials(): { url: string; key: string } {
  const hash = window.location.hash.replace(/^#/, '');
  const hashParams = new URLSearchParams(hash);
  const queryParams = new URLSearchParams(window.location.search);

  let urlParam = hashParams.get('url') || hashParams.get('supabaseUrl') || queryParams.get('url') || queryParams.get('supabaseUrl') || '';
  let keyParam = hashParams.get('key') || hashParams.get('supabaseKey') || hashParams.get('apikey') || queryParams.get('key') || queryParams.get('supabaseKey') || '';

  let url = urlParam || localStorage.getItem('raymond_supabase_url') || DEFAULT_SUPABASE_URL;
  let key = keyParam || localStorage.getItem('raymond_supabase_key') || DEFAULT_SUPABASE_KEY;

  if (key && (key.startsWith('eyJhbGci') || key.includes('xyzcompany') || key.length < 20)) {
    key = DEFAULT_SUPABASE_KEY;
    localStorage.setItem('raymond_supabase_key', key);
  }

  if (urlParam) localStorage.setItem('raymond_supabase_url', urlParam);
  if (keyParam) localStorage.setItem('raymond_supabase_key', keyParam);

  if (window.location.hash && (urlParam || keyParam)) {
    try {
      history.replaceState(null, document.title, window.location.pathname + window.location.search);
    } catch (_) {}
  }

  return { url: url.replace(/\/+$/, ''), key };
}

export function saveCredentials(url: string, key: string) {
  localStorage.setItem('raymond_supabase_url', url.replace(/\/+$/, ''));
  localStorage.setItem('raymond_supabase_key', key);
}

export async function fetchTransactions(url?: string, key?: string): Promise<Transaction[]> {
  const creds = url && key ? { url: url.replace(/\/+$/, ''), key } : getStoredCredentials();

  try {
    const txRes = await fetch(`${creds.url}/rest/v1/transactions?select=*&order=created_at.desc`, {
      headers: {
        'apikey': creds.key,
        'Authorization': `Bearer ${creds.key}`,
        'Content-Type': 'application/json'
      }
    });

    if (!txRes.ok) {
      return DEMO_TRANSACTIONS;
    }

    const txs: Transaction[] = await txRes.json();

    try {
      const actsRes = await fetch(`${creds.url}/rest/v1/coordination_acts?select=*&order=created_at.asc`, {
        headers: {
          'apikey': creds.key,
          'Authorization': `Bearer ${creds.key}`,
          'Content-Type': 'application/json'
        }
      });
      if (actsRes.ok) {
        const acts: CoordinationAct[] = await actsRes.json();
        const actsByTx: Record<string, CoordinationAct[]> = {};
        for (const act of acts) {
          if (!actsByTx[act.transaction_id]) actsByTx[act.transaction_id] = [];
          actsByTx[act.transaction_id].push(act);
        }
        for (const tx of txs) {
          tx.acts = actsByTx[tx.id] || [];
        }
      }
    } catch (e) {
      console.warn('Could not load coordination acts:', e);
    }

    return txs.length > 0 ? txs : DEMO_TRANSACTIONS;
  } catch (err) {
    return DEMO_TRANSACTIONS;
  }
}

export async function fetchGraphData(url?: string, key?: string): Promise<KnowledgeGraphData> {
  const creds = url && key ? { url: url.replace(/\/+$/, ''), key } : getStoredCredentials();

  try {
    const [entRes, relRes, memRes, memEntRes] = await Promise.all([
      fetch(`${creds.url}/rest/v1/entities?select=*&limit=1000`, {
        headers: { 'apikey': creds.key, 'Authorization': `Bearer ${creds.key}` }
      }),
      fetch(`${creds.url}/rest/v1/relations?select=*&limit=1500`, {
        headers: { 'apikey': creds.key, 'Authorization': `Bearer ${creds.key}` }
      }),
      fetch(`${creds.url}/rest/v1/memories?select=id,content,author_agent,category,tags,created_at&limit=300`, {
        headers: { 'apikey': creds.key, 'Authorization': `Bearer ${creds.key}` }
      }),
      fetch(`${creds.url}/rest/v1/memory_entities?select=*&limit=1000`, {
        headers: { 'apikey': creds.key, 'Authorization': `Bearer ${creds.key}` }
      })
    ]);

    if (!entRes.ok || !relRes.ok) {
      return DEMO_GRAPH_DATA;
    }

    const entities = await entRes.json();
    const relations = await relRes.json();
    const memories = memRes.ok ? await memRes.json() : [];
    const memory_entities = memEntRes.ok ? await memEntRes.json() : [];

    return {
      entities: entities.length > 0 ? entities : DEMO_GRAPH_DATA.entities,
      relations: relations.length > 0 ? relations : DEMO_GRAPH_DATA.relations,
      memories: memories.length > 0 ? memories : DEMO_GRAPH_DATA.memories,
      memory_entities: memory_entities.length > 0 ? memory_entities : DEMO_GRAPH_DATA.memory_entities
    };
  } catch (err) {
    return DEMO_GRAPH_DATA;
  }
}

// --- PERSISTENCE MUTATIONS ---

export async function createRelationInDb(relation: Relation): Promise<{ success: boolean; data?: any; error?: string }> {
  const creds = getStoredCredentials();
  const payload = {
    id: relation.id.startsWith('rel_') ? undefined : relation.id,
    src: relation.src || relation.source_id,
    dst: relation.dst || relation.target_id,
    predicate: relation.predicate,
    valid_from: relation.valid_from || new Date().toISOString(),
    valid_to: relation.valid_to || null,
    metadata: relation.metadata || {}
  };

  try {
    const res = await fetch(`${creds.url}/rest/v1/relations`, {
      method: 'POST',
      headers: {
        'apikey': creds.key,
        'Authorization': `Bearer ${creds.key}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const errText = await res.text();
      return { success: false, error: errText };
    }
    const data = await res.json();
    return { success: true, data: data[0] || payload };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}

export async function deleteRelationFromDb(relationId: string): Promise<{ success: boolean; error?: string }> {
  const creds = getStoredCredentials();
  try {
    const res = await fetch(`${creds.url}/rest/v1/relations?id=eq.${relationId}`, {
      method: 'DELETE',
      headers: {
        'apikey': creds.key,
        'Authorization': `Bearer ${creds.key}`
      }
    });
    if (!res.ok) {
      const errText = await res.text();
      return { success: false, error: errText };
    }
    return { success: true };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}

export async function deleteEntityFromDb(entityId: string): Promise<{ success: boolean; error?: string }> {
  const creds = getStoredCredentials();
  try {
    const res = await fetch(`${creds.url}/rest/v1/entities?id=eq.${entityId}`, {
      method: 'DELETE',
      headers: {
        'apikey': creds.key,
        'Authorization': `Bearer ${creds.key}`
      }
    });
    if (!res.ok) {
      const errText = await res.text();
      return { success: false, error: errText };
    }
    return { success: true };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}
