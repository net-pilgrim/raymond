import { createClient, type SupabaseClient, type User, type Session } from '@supabase/supabase-js';
import type { Transaction, KnowledgeGraphData, CoordinationAct, Relation, Entity, Agent } from './types';
import { DEMO_TRANSACTIONS, DEMO_GRAPH_DATA } from './demoData';

export const DEFAULT_SUPABASE_URL = 'https://zmocedvkqrcxwkthmwql.supabase.co';
export const DEFAULT_SUPABASE_KEY = 'sb_publishable_Mtm9durpa0BqJilrDDP3Sw_emjdGVfY';

let supabaseClientInstance: SupabaseClient | null = null;
let currentClientUrl = '';
let currentClientKey = '';

export function getStoredCredentials(): { url: string; key: string } {
  const hash = typeof window !== 'undefined' ? window.location.hash.replace(/^#/, '') : '';
  const hashParams = new URLSearchParams(hash);
  const queryParams = typeof window !== 'undefined' ? new URLSearchParams(window.location.search) : new URLSearchParams();

  let urlParam = hashParams.get('url') || hashParams.get('supabaseUrl') || queryParams.get('url') || queryParams.get('supabaseUrl') || '';
  let keyParam = hashParams.get('key') || hashParams.get('supabaseKey') || hashParams.get('apikey') || queryParams.get('key') || queryParams.get('supabaseKey') || '';

  let url = urlParam || (typeof localStorage !== 'undefined' ? localStorage.getItem('raymond_supabase_url') : '') || DEFAULT_SUPABASE_URL;
  let key = keyParam || (typeof localStorage !== 'undefined' ? localStorage.getItem('raymond_supabase_key') : '') || DEFAULT_SUPABASE_KEY;

  // Clean stale/expired JWT tokens or invalid placeholders
  if (key && (key.startsWith('eyJhbGci') || key.includes('xyzcompany') || key.length < 20)) {
    key = DEFAULT_SUPABASE_KEY;
    if (typeof localStorage !== 'undefined') localStorage.setItem('raymond_supabase_key', key);
  }

  if (urlParam && typeof localStorage !== 'undefined') localStorage.setItem('raymond_supabase_url', urlParam);
  if (keyParam && typeof localStorage !== 'undefined') localStorage.setItem('raymond_supabase_key', keyParam);

  if (typeof window !== 'undefined' && window.location.hash && (urlParam || keyParam)) {
    try {
      history.replaceState(null, document.title, window.location.pathname + window.location.search);
    } catch (_) {}
  }

  return { url: url.replace(/\/+$/, ''), key };
}

export function saveCredentials(url: string, key: string) {
  const cleanUrl = url.replace(/\/+$/, '');
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem('raymond_supabase_url', cleanUrl);
    localStorage.setItem('raymond_supabase_key', key);
  }
  // Reset client so it re-initializes on next call
  supabaseClientInstance = null;
}

export function getSupabaseClient(overrideUrl?: string, overrideKey?: string): SupabaseClient {
  const creds = overrideUrl && overrideKey ? { url: overrideUrl.replace(/\/+$/, ''), key: overrideKey } : getStoredCredentials();

  if (!supabaseClientInstance || currentClientUrl !== creds.url || currentClientKey !== creds.key) {
    currentClientUrl = creds.url;
    currentClientKey = creds.key;
    supabaseClientInstance = createClient(creds.url, creds.key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      }
    });
  }

  return supabaseClientInstance;
}

// --- AUTHENTICATION HELPERS ---

export async function getCurrentSession(): Promise<Session | null> {
  try {
    const client = getSupabaseClient();
    const { data: { session } } = await client.auth.getSession();
    return session;
  } catch {
    return null;
  }
}

export async function getCurrentUser(): Promise<User | null> {
  try {
    const client = getSupabaseClient();
    const { data: { user } } = await client.auth.getUser();
    return user;
  } catch {
    return null;
  }
}

export function onAuthStateChange(callback: (user: User | null, session: Session | null) => void) {
  const client = getSupabaseClient();
  const { data: { subscription } } = client.auth.onAuthStateChange((_event, session) => {
    callback(session?.user || null, session);
  });
  return subscription;
}

export async function signInWithMagicLink(email: string, redirectTo?: string): Promise<{ error: Error | null }> {
  try {
    const client = getSupabaseClient();
    const targetRedirect = redirectTo || (typeof window !== 'undefined' ? window.location.origin + window.location.pathname : undefined);
    const { error } = await client.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: targetRedirect
      }
    });
    return { error };
  } catch (err: any) {
    return { error: err };
  }
}

export async function signInWithOAuth(provider: 'github' | 'google'): Promise<{ error: Error | null }> {
  try {
    const client = getSupabaseClient();
    const { error } = await client.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: typeof window !== 'undefined' ? window.location.origin + window.location.pathname : undefined
      }
    });
    return { error };
  } catch (err: any) {
    return { error: err };
  }
}

export async function signOut(): Promise<{ error: Error | null }> {
  try {
    const client = getSupabaseClient();
    const { error } = await client.auth.signOut();
    return { error };
  } catch (err: any) {
    return { error: err };
  }
}

// Request headers builder including Bearer token if user is signed in
export async function getAuthHeaders(): Promise<Record<string, string>> {
  const creds = getStoredCredentials();
  const session = await getCurrentSession();
  const token = session?.access_token || creds.key;

  return {
    'apikey': creds.key,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };
}

// --- DATA QUERIES ---

export async function fetchTransactions(): Promise<Transaction[]> {
  const creds = getStoredCredentials();
  const headers = await getAuthHeaders();

  try {
    const txRes = await fetch(`${creds.url}/rest/v1/transactions?select=*&order=created_at.desc`, {
      headers
    });

    if (!txRes.ok) {
      return DEMO_TRANSACTIONS;
    }

    const txs: Transaction[] = await txRes.json();

    try {
      const actsRes = await fetch(`${creds.url}/rest/v1/coordination_acts?select=*&order=created_at.asc`, {
        headers
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

export async function fetchGraphData(): Promise<KnowledgeGraphData> {
  const creds = getStoredCredentials();
  const headers = await getAuthHeaders();

  // 1. First attempt: Edge Function graph.json endpoint with Bearer auth token
  try {
    const edgeGraphRes = await fetch(`${creds.url}/functions/v1/mcp/graph.json?limit=1000`, {
      headers
    });
    if (edgeGraphRes.ok) {
      const data = await edgeGraphRes.json();
      if (data && Array.isArray(data.entities) && data.entities.length > 0) {
        return {
          entities: data.entities,
          relations: data.relations || [],
          memories: data.memories || [],
          memory_entities: data.memory_entities || []
        };
      }
    }
  } catch (_) {
    // Fall back to direct REST API
  }

  // 2. Direct Supabase REST queries
  try {
    const [entRes, relRes, memRes, memEntRes] = await Promise.all([
      fetch(`${creds.url}/rest/v1/entities?select=*&limit=1000`, { headers }),
      fetch(`${creds.url}/rest/v1/relations?select=*&limit=1500`, { headers }),
      fetch(`${creds.url}/rest/v1/memories?select=id,owner_id,visibility,agent_id,session_id,category,content,tags,created_at,metadata&order=created_at.desc&limit=300`, { headers }),
      fetch(`${creds.url}/rest/v1/memory_entities?select=*&limit=1000`, { headers })
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
  const headers = await getAuthHeaders();
  const user = await getCurrentUser();

  const payload: any = {
    id: relation.id.startsWith('rel_') ? undefined : relation.id,
    src: relation.src || relation.source_id,
    dst: relation.dst || relation.target_id,
    predicate: relation.predicate,
    valid_from: relation.valid_from || new Date().toISOString(),
    valid_to: relation.valid_to || null,
    metadata: relation.metadata || {}
  };

  if (user) {
    payload.owner_id = user.id;
  }

  try {
    const res = await fetch(`${creds.url}/rest/v1/relations`, {
      method: 'POST',
      headers: {
        ...headers,
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
  const headers = await getAuthHeaders();

  try {
    const res = await fetch(`${creds.url}/rest/v1/relations?id=eq.${relationId}`, {
      method: 'DELETE',
      headers
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
  const headers = await getAuthHeaders();

  try {
    const res = await fetch(`${creds.url}/rest/v1/entities?id=eq.${entityId}`, {
      method: 'DELETE',
      headers
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

// --- AGENTS REGISTRY HELPERS ---

export async function fetchUserAgents(): Promise<Agent[]> {
  const user = await getCurrentUser();
  if (!user) return [];
  const creds = getStoredCredentials();
  const headers = await getAuthHeaders();

  try {
    const res = await fetch(`${creds.url}/rest/v1/agents?owner_id=eq.${user.id}&order=created_at.desc`, {
      headers
    });
    if (!res.ok) return [];
    return await res.json();
  } catch {
    return [];
  }
}

export async function registerAgent(name: string, displayName?: string): Promise<{ success: boolean; data?: Agent; error?: string }> {
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Sign in required to register an agent.' };
  const creds = getStoredCredentials();
  const headers = await getAuthHeaders();

  try {
    const res = await fetch(`${creds.url}/rest/v1/agents`, {
      method: 'POST',
      headers: {
        ...headers,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify({
        owner_id: user.id,
        name: name.trim().toLowerCase(),
        display_name: displayName?.trim() || name.trim()
      })
    });

    if (!res.ok) {
      const err = await res.text();
      return { success: false, error: err };
    }
    const [data] = await res.json();
    return { success: true, data };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}
