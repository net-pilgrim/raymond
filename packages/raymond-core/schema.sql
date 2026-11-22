-- ==============================================================================
-- Supabase Schema for Multi-Agent MCP Memory System (Raymond)
-- Knowledge Graph & Vector Memory Architecture
-- ==============================================================================

-- 1. Enable required extensions
create extension if not exists vector;
create extension if not exists pg_trgm;

-- 1b. Create Agents Registry Table
-- Models per-agent identity owned by Supabase Auth users (auth.users)
create table if not exists public.agents (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid references auth.users(id) on delete cascade not null,
    name text not null,
    display_name text,
    api_key_hash text,
    metadata jsonb default '{}'::jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    constraint unique_agent_per_owner unique(owner_id, name)
);

create index if not exists idx_agents_owner_id on public.agents(owner_id);
create index if not exists idx_agents_name on public.agents(name);

-- 2. Create the memories table
create table if not exists public.memories (
    id uuid primary key default gen_random_uuid(),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    owner_id uuid references auth.users(id) on delete set null, -- Supabase Auth owner
    visibility text default 'shared' not null check (visibility in ('private', 'shared')), -- Access visibility
    agent_id text not null,                       -- ID/Name of the agent that created/owns the memory
    session_id text,                              -- Optional session/workflow/conversation scope
    category text default 'general' not null,     -- e.g. 'fact', 'decision', 'preference', 'instruction', 'reflection', 'summary'
    content text not null,                         -- The memory content / knowledge snippet
    content_hash text,                            -- SHA-256 hash of normalized content to prevent duplicate embeddings
    tags text[] default '{}'::text[] not null,    -- Tags for filtering and grouping
    metadata jsonb default '{}'::jsonb not null,  -- Arbitrary metadata (confidence, context, sources, etc.)
    embedding vector(768)                         -- Vector embedding (768 dimensions for Gemini gemini-embedding-001)
);

-- Ensure columns exist if migrating an existing memories table
alter table public.memories add column if not exists content_hash text;
alter table public.memories add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.memories add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));

-- 3. Automatic timestamp updater trigger
create or replace function update_updated_at_column()
returns trigger as $$
begin
    new.updated_at = timezone('utc'::text, now());
    return new;
end;
$$ language plpgsql;

drop trigger if exists set_agents_updated_at on public.agents;
create trigger set_agents_updated_at
    before update on public.agents
    for each row
    execute function update_updated_at_column();

drop trigger if exists set_memories_updated_at on public.memories;
create trigger set_memories_updated_at
    before update on public.memories
    for each row
    execute function update_updated_at_column();

-- Enable RLS on agents table
alter table public.agents enable row level security;

drop policy if exists "Allow service role full access on agents" on public.agents;
create policy "Allow service role full access on agents"
    on public.agents for all to service_role using (true) with check (true);

drop policy if exists "Users can manage their own agents" on public.agents;
create policy "Users can manage their own agents"
    on public.agents for all to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

drop policy if exists "Anon read access on agents" on public.agents;
create policy "Anon read access on agents"
    on public.agents for select to anon
    using (true);

-- 4. Indexes for high performance querying
create index if not exists idx_memories_owner_id on public.memories(owner_id);
create index if not exists idx_memories_visibility on public.memories(visibility);
create index if not exists idx_memories_agent_id on public.memories(agent_id);
create index if not exists idx_memories_session_id on public.memories(session_id);
create index if not exists idx_memories_category on public.memories(category);
create index if not exists idx_memories_created_at on public.memories(created_at desc);
create index if not exists idx_memories_tags on public.memories using gin(tags);
create index if not exists idx_memories_metadata on public.memories using gin(metadata);
create index if not exists idx_memories_content_hash on public.memories(content_hash);

-- Full-text search index on content
create index if not exists idx_memories_fts on public.memories using gin(to_tsvector('english', content));

-- HNSW Vector index on embedding (using cosine similarity)
create index if not exists idx_memories_embedding on public.memories 
    using hnsw (embedding vector_cosine_ops);

-- 5. RPC function: match_memories (Vector Semantic Search)
create or replace function match_memories (
    query_embedding vector(768),
    match_threshold float default 0.2,
    match_count int default 10,
    filter_agent_id text default null,
    filter_session_id text default null,
    filter_category text default null,
    filter_tags text[] default null
)
returns table (
    id uuid,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    agent_id text,
    session_id text,
    category text,
    content text,
    tags text[],
    metadata jsonb,
    similarity float
)
language plpgsql
as $$
begin
    return query
    select
        m.id,
        m.created_at,
        m.updated_at,
        m.agent_id,
        m.session_id,
        m.category,
        m.content,
        m.tags,
        m.metadata,
        1 - (m.embedding <=> query_embedding) as similarity
    from public.memories m
    where m.embedding is not null
      and (filter_agent_id is null or m.agent_id = filter_agent_id)
      and (filter_session_id is null or m.session_id = filter_session_id)
      and (filter_category is null or m.category = filter_category)
      and (filter_tags is null or m.tags && filter_tags)
      and (1 - (m.embedding <=> query_embedding)) >= match_threshold
    order by m.embedding <=> query_embedding asc
    limit match_count;
end;
$$;

-- 6. RPC function: search_memories_text (Full-Text & Keyword Search fallback)
create or replace function search_memories_text (
    query_text text,
    match_count int default 10,
    filter_agent_id text default null,
    filter_session_id text default null,
    filter_category text default null,
    filter_tags text[] default null
)
returns table (
    id uuid,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    agent_id text,
    session_id text,
    category text,
    content text,
    tags text[],
    metadata jsonb,
    rank float
)
language plpgsql
as $$
begin
    return query
    select
        m.id,
        m.created_at,
        m.updated_at,
        m.agent_id,
        m.session_id,
        m.category,
        m.content,
        m.tags,
        m.metadata,
        ts_rank(to_tsvector('english', m.content), plainto_tsquery('english', query_text))::float as rank
    from public.memories m
    where (filter_agent_id is null or m.agent_id = filter_agent_id)
      and (filter_session_id is null or m.session_id = filter_session_id)
      and (filter_category is null or m.category = filter_category)
      and (filter_tags is null or m.tags && filter_tags)
      and (
          query_text is null 
          or query_text = ''
          or to_tsvector('english', m.content) @@ plainto_tsquery('english', query_text)
          or m.content ilike '%' || query_text || '%'
      )
    order by rank desc, m.created_at desc
    limit match_count;
end;
$$;

-- 7. Row Level Security (RLS) - memories
alter table public.memories enable row level security;
drop policy if exists "Allow service role full access on memories" on public.memories;
create policy "Allow service role full access on memories"
    on public.memories for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users select memories" on public.memories;
create policy "Authenticated users select memories"
    on public.memories for select to authenticated
    using (owner_id = auth.uid() or visibility = 'shared' or owner_id is null);

drop policy if exists "Authenticated users insert memories" on public.memories;
create policy "Authenticated users insert memories"
    on public.memories for insert to authenticated
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users update own memories" on public.memories;
create policy "Authenticated users update own memories"
    on public.memories for update to authenticated
    using (owner_id = auth.uid() or owner_id is null)
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users delete own memories" on public.memories;
create policy "Authenticated users delete own memories"
    on public.memories for delete to authenticated
    using (owner_id = auth.uid());

drop policy if exists "Anon select shared memories" on public.memories;
drop policy if exists "Allow anon access for development on memories" on public.memories;
create policy "Anon select shared memories"
    on public.memories for select to anon
    using (visibility = 'shared' or owner_id is null);

-- ==============================================================================
-- 8. Skills Table (Dynamic Skills Registry exposed via MCP)
-- ==============================================================================
create table if not exists public.skills (
    id uuid primary key default gen_random_uuid(),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    owner_id uuid references auth.users(id) on delete set null,
    visibility text default 'shared' not null check (visibility in ('private', 'shared')),
    name text unique not null,                     -- Unique identifier e.g. 'agent-handover'
    description text not null,                    -- Brief summary of what the skill does
    instructions text not null,                   -- Step-by-step instructions / runbook (Markdown)
    tags text[] default '{}'::text[] not null,    -- Tags for discovery
    author_agent text default 'system' not null,  -- Agent that created or published the skill
    metadata jsonb default '{}'::jsonb not null   -- Arbitrary metadata (version, examples, etc.)
);

alter table public.skills add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.skills add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));

drop trigger if exists set_skills_updated_at on public.skills;
create trigger set_skills_updated_at
    before update on public.skills
    for each row
    execute function update_updated_at_column();

create index if not exists idx_skills_name on public.skills(name);
create index if not exists idx_skills_tags on public.skills using gin(tags);
create index if not exists idx_skills_owner_id on public.skills(owner_id);
create index if not exists idx_skills_visibility on public.skills(visibility);

alter table public.skills enable row level security;
drop policy if exists "Allow service role full access on skills" on public.skills;
create policy "Allow service role full access on skills"
    on public.skills for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users select skills" on public.skills;
create policy "Authenticated users select skills"
    on public.skills for select to authenticated
    using (owner_id = auth.uid() or visibility = 'shared' or owner_id is null);

drop policy if exists "Authenticated users insert skills" on public.skills;
create policy "Authenticated users insert skills"
    on public.skills for insert to authenticated
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users update own skills" on public.skills;
create policy "Authenticated users update own skills"
    on public.skills for update to authenticated
    using (owner_id = auth.uid() or owner_id is null)
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users delete own skills" on public.skills;
create policy "Authenticated users delete own skills"
    on public.skills for delete to authenticated
    using (owner_id = auth.uid());

drop policy if exists "Anon select shared skills" on public.skills;
drop policy if exists "Allow anon access on skills" on public.skills;
create policy "Anon select shared skills"
    on public.skills for select to anon
    using (visibility = 'shared' or owner_id is null);

-- ==============================================================================
-- 9. Knowledge Graph Architecture (Entities, Relations, Memory Grounding)
-- ==============================================================================

-- 9.1 Entities Table
create table if not exists public.entities (
    id uuid primary key default gen_random_uuid(),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    owner_id uuid references auth.users(id) on delete set null,
    visibility text default 'shared' not null check (visibility in ('private', 'shared')),
    name text not null,
    type text default 'concept' not null,          -- e.g. 'concept', 'component', 'decision', 'system', 'agent', 'technology'
    aliases text[] default '{}'::text[] not null,  -- Alternate synonyms, short forms, or casing variants
    metadata jsonb default '{}'::jsonb not null
);

alter table public.entities add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.entities add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));

-- Unique index on normalized (lower name, type)
create unique index if not exists uq_idx_entities_lower_name_type on public.entities (lower(name), type);

drop trigger if exists set_entities_updated_at on public.entities;
create trigger set_entities_updated_at
    before update on public.entities
    for each row
    execute function update_updated_at_column();

create index if not exists idx_entities_name_trgm on public.entities using gin(name gin_trgm_ops);
create index if not exists idx_entities_aliases on public.entities using gin(aliases);
create index if not exists idx_entities_type on public.entities(type);
create index if not exists idx_entities_owner_id on public.entities(owner_id);
create index if not exists idx_entities_visibility on public.entities(visibility);

-- 9.2 Relations Table (Graph Edges with Temporal Validity)
create table if not exists public.relations (
    id uuid primary key default gen_random_uuid(),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    owner_id uuid references auth.users(id) on delete set null,
    visibility text default 'shared' not null check (visibility in ('private', 'shared')),
    src uuid not null references public.entities(id) on delete cascade,
    dst uuid not null references public.entities(id) on delete cascade,
    predicate text not null,                       -- e.g. 'depends_on', 'implements', 'uses', 'replaces', 'relates_to'
    memory_id uuid references public.memories(id) on delete set null, -- Optional evidence memory
    valid_from timestamp with time zone default timezone('utc'::text, now()) not null,
    valid_to timestamp with time zone,             -- null = active; non-null timestamp = superseded/invalidated edge
    metadata jsonb default '{}'::jsonb not null
);

alter table public.relations add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.relations add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));

create index if not exists idx_relations_src on public.relations(src);
create index if not exists idx_relations_dst on public.relations(dst);
create index if not exists idx_relations_predicate on public.relations(predicate);
create index if not exists idx_relations_memory_id on public.relations(memory_id);
create index if not exists idx_relations_valid on public.relations(valid_from, valid_to);
create index if not exists idx_relations_owner_id on public.relations(owner_id);
create index if not exists idx_relations_visibility on public.relations(visibility);

-- 9.3 Memory <-> Entities Junction Table (Grounding)
create table if not exists public.memory_entities (
    memory_id uuid not null references public.memories(id) on delete cascade,
    entity_id uuid not null references public.entities(id) on delete cascade,
    owner_id uuid references auth.users(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (memory_id, entity_id)
);

alter table public.memory_entities add column if not exists owner_id uuid references auth.users(id) on delete set null;

create index if not exists idx_memory_entities_entity_id on public.memory_entities(entity_id);
create index if not exists idx_memory_entities_memory_id on public.memory_entities(memory_id);
create index if not exists idx_memory_entities_owner_id on public.memory_entities(owner_id);

-- 9.4 Row Level Security (RLS) - Knowledge Graph
alter table public.entities enable row level security;
drop policy if exists "Allow service role full access on entities" on public.entities;
create policy "Allow service role full access on entities"
    on public.entities for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users select entities" on public.entities;
create policy "Authenticated users select entities"
    on public.entities for select to authenticated
    using (owner_id = auth.uid() or visibility = 'shared' or owner_id is null);

drop policy if exists "Authenticated users insert entities" on public.entities;
create policy "Authenticated users insert entities"
    on public.entities for insert to authenticated
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users update own entities" on public.entities;
create policy "Authenticated users update own entities"
    on public.entities for update to authenticated
    using (owner_id = auth.uid() or owner_id is null)
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users delete own entities" on public.entities;
create policy "Authenticated users delete own entities"
    on public.entities for delete to authenticated
    using (owner_id = auth.uid());

drop policy if exists "Anon select shared entities" on public.entities;
drop policy if exists "Allow anon access on entities" on public.entities;
create policy "Anon select shared entities"
    on public.entities for select to anon
    using (visibility = 'shared' or owner_id is null);

alter table public.relations enable row level security;
drop policy if exists "Allow service role full access on relations" on public.relations;
create policy "Allow service role full access on relations"
    on public.relations for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users select relations" on public.relations;
create policy "Authenticated users select relations"
    on public.relations for select to authenticated
    using (owner_id = auth.uid() or visibility = 'shared' or owner_id is null);

drop policy if exists "Authenticated users insert relations" on public.relations;
create policy "Authenticated users insert relations"
    on public.relations for insert to authenticated
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users update own relations" on public.relations;
create policy "Authenticated users update own relations"
    on public.relations for update to authenticated
    using (owner_id = auth.uid() or owner_id is null)
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users delete own relations" on public.relations;
create policy "Authenticated users delete own relations"
    on public.relations for delete to authenticated
    using (owner_id = auth.uid());

drop policy if exists "Anon select shared relations" on public.relations;
drop policy if exists "Allow anon access on relations" on public.relations;
create policy "Anon select shared relations"
    on public.relations for select to anon
    using (visibility = 'shared' or owner_id is null);

alter table public.memory_entities enable row level security;
drop policy if exists "Allow service role full access on memory_entities" on public.memory_entities;
create policy "Allow service role full access on memory_entities"
    on public.memory_entities for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users manage memory_entities" on public.memory_entities;
create policy "Authenticated users manage memory_entities"
    on public.memory_entities for all to authenticated
    using (true)
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Anon select memory_entities" on public.memory_entities;
drop policy if exists "Allow anon access on memory_entities" on public.memory_entities;
create policy "Anon select memory_entities"
    on public.memory_entities for select to anon
    using (true);

-- 9.5 RPC: resolve_or_create_entity (Fuzzy Trigram & Alias Resolution)
create or replace function resolve_or_create_entity (
    entity_name text,
    entity_type text default 'concept',
    entity_aliases text[] default '{}'::text[]
)
returns uuid
language plpgsql
as $$
declare
    target_id uuid;
    clean_name text := trim(entity_name);
begin
    -- 1. Try to match lower(name) and type
    select id into target_id
    from public.entities
    where lower(name) = lower(clean_name)
      and type = entity_type
    limit 1;

    -- 2. If not found by type, match by lower(name) alone
    if target_id is null then
        select id into target_id
        from public.entities
        where lower(name) = lower(clean_name)
        limit 1;
    end if;

    -- 3. If not found, check if clean_name exists in any aliases array
    if target_id is null then
        select id into target_id
        from public.entities
        where entity_aliases && aliases
           or clean_name = any(aliases)
        limit 1;
    end if;

    -- 3. If found, merge new aliases
    if target_id is not null then
        if array_length(entity_aliases, 1) > 0 then
            update public.entities
            set aliases = array(
                select distinct unnest(aliases || entity_aliases)
            )
            where id = target_id;
        end if;
        return target_id;
    end if;

    -- 4. Otherwise create new entity
    insert into public.entities (name, type, aliases)
    values (clean_name, entity_type, entity_aliases)
    returning id into target_id;

    return target_id;
end;
$$;

-- 9.6 RPC: traverse_knowledge_graph (Recursive CTE Multi-Hop Graph Traversal)
create or replace function traverse_knowledge_graph (
    root_entity_id uuid,
    max_depth int default 2,
    active_only boolean default true
)
returns table (
    depth int,
    src_id uuid,
    src_name text,
    src_type text,
    predicate text,
    dst_id uuid,
    dst_name text,
    dst_type text,
    relation_id uuid,
    memory_id uuid,
    valid_from timestamp with time zone,
    valid_to timestamp with time zone
)
language sql
as $$
with recursive graph_walk as (
    -- Anchor member (depth 1)
    select
        1 as depth,
        r.id as relation_id,
        r.src as src_id,
        s.name as src_name,
        s.type as src_type,
        r.predicate,
        r.dst as dst_id,
        d.name as dst_name,
        d.type as dst_type,
        r.memory_id,
        r.valid_from,
        r.valid_to,
        array[r.src, r.dst] as visited_entities
    from public.relations r
    join public.entities s on s.id = r.src
    join public.entities d on d.id = r.dst
    where (r.src = root_entity_id or r.dst = root_entity_id)
      and (not active_only or r.valid_to is null or r.valid_to > timezone('utc'::text, now()))

    union all

    -- Recursive member (depth > 1)
    select
        gw.depth + 1 as depth,
        r.id as relation_id,
        r.src as src_id,
        s.name as src_name,
        s.type as src_type,
        r.predicate,
        r.dst as dst_id,
        d.name as dst_name,
        d.type as dst_type,
        r.memory_id,
        r.valid_from,
        r.valid_to,
        gw.visited_entities || case when r.src = any(gw.visited_entities) then r.dst else r.src end
    from public.relations r
    join graph_walk gw on (r.src = gw.dst_id or r.dst = gw.dst_id or r.src = gw.src_id or r.dst = gw.src_id)
    join public.entities s on s.id = r.src
    join public.entities d on d.id = r.dst
    where gw.depth < max_depth
      and r.id != gw.relation_id
      and not (r.src = any(gw.visited_entities) and r.dst = any(gw.visited_entities))
      and (not active_only or r.valid_to is null or r.valid_to > timezone('utc'::text, now()))
)
select distinct
    gw.depth,
    gw.src_id,
    gw.src_name,
    gw.src_type,
    gw.predicate,
    gw.dst_id,
    gw.dst_name,
    gw.dst_type,
    gw.relation_id,
    gw.memory_id,
    gw.valid_from,
    gw.valid_to
from graph_walk gw
order by gw.depth asc;
$$;

-- 9.7 RPC: search_graph_rpc (Keyword / Trigram fuzzy seed -> Graph Expansion)
create or replace function search_graph_rpc (
    query_text text,
    max_depth int default 1,
    active_only boolean default true
)
returns table (
    depth int,
    src_id uuid,
    src_name text,
    src_type text,
    predicate text,
    dst_id uuid,
    dst_name text,
    dst_type text,
    relation_id uuid,
    memory_id uuid
)
language plpgsql
as $$
begin
    return query
    with matched_roots as (
        select e.id
        from public.entities e
        where lower(e.name) = lower(trim(query_text))
           or query_text = any(e.aliases)
           or e.name ilike '%' || query_text || '%'
           or similarity(e.name, query_text) > 0.3
        limit 5
    )
    select distinct
        t.depth,
        t.src_id,
        t.src_name,
        t.src_type,
        t.predicate,
        t.dst_id,
        t.dst_name,
        t.dst_type,
        t.relation_id,
        t.memory_id
    from matched_roots mr
    cross join lateral traverse_knowledge_graph(mr.id, max_depth, active_only) t
    order by t.depth asc;
end;
$$;

-- ==============================================================================
-- 10. Graph & Memory Maintenance RPCs (Clearing Obsolete & Unused Knowledge)
-- ==============================================================================

-- 10.1 RPC: prune_orphaned_entities (Removes entities with zero active relations & zero memories)
create or replace function prune_orphaned_entities (
    dry_run boolean default false
)
returns table (
    orphaned_count int,
    orphaned_ids uuid[]
)
language plpgsql
as $$
declare
    v_ids uuid[];
    v_count int;
begin
    select array_agg(e.id) into v_ids
    from public.entities e
    where not exists (
        select 1 from public.relations r
        where r.src = e.id or r.dst = e.id
    )
    and not exists (
        select 1 from public.memory_entities me
        where me.entity_id = e.id
    );

    v_count := coalesce(array_length(v_ids, 1), 0);

    if not dry_run and v_count > 0 then
        delete from public.entities
        where id = any(v_ids);
    end if;

    return query select v_count, coalesce(v_ids, array[]::uuid[]);
end;
$$;

-- 10.2 RPC: prune_obsolete_knowledge (Bulk cleanup of invalidated links, obsolete memories & orphaned entities)
create or replace function prune_obsolete_knowledge (
    clear_invalidated_relations boolean default true,
    clear_orphaned_entities boolean default true,
    clear_memories boolean default false,
    obsolete_memories_only boolean default true,
    older_than_interval interval default null,
    target_session_id text default null,
    target_category text default null,
    dry_run boolean default false
)
returns table (
    cleared_relations_count int,
    cleared_memories_count int,
    cleared_entities_count int
)
language plpgsql
as $$
declare
    rel_ids uuid[];
    mem_ids uuid[];
    ent_ids uuid[];
    v_rel_count int := 0;
    v_mem_count int := 0;
    v_ent_count int := 0;
begin
    -- 1. Identify invalidated or expired relations
    if clear_invalidated_relations then
        select array_agg(r.id) into rel_ids
        from public.relations r
        where (r.valid_to is not null and r.valid_to <= timezone('utc'::text, now()))
           or (older_than_interval is not null and r.created_at < timezone('utc'::text, now()) - older_than_interval);

        v_rel_count := coalesce(array_length(rel_ids, 1), 0);
        if not dry_run and v_rel_count > 0 then
            delete from public.relations where id = any(rel_ids);
        end if;
    end if;

    -- 2. Identify obsolete memories
    if clear_memories then
        select array_agg(m.id) into mem_ids
        from public.memories m
        where (
            not obsolete_memories_only or (
                coalesce((m.metadata->>'obsolete')::boolean, false) = true
                or m.metadata->>'status' = 'obsolete'
                or coalesce((m.metadata->>'deprecated')::boolean, false) = true
                or coalesce((m.metadata->>'expired')::boolean, false) = true
            )
        )
        and (older_than_interval is null or m.created_at < timezone('utc'::text, now()) - older_than_interval)
        and (target_session_id is null or m.session_id = target_session_id)
        and (target_category is null or m.category = target_category);

        v_mem_count := coalesce(array_length(mem_ids, 1), 0);
        if not dry_run and v_mem_count > 0 then
            delete from public.memories where id = any(mem_ids);
        end if;
    end if;

    -- 3. Identify orphaned entities (0 relations and 0 memories)
    if clear_orphaned_entities then
        select array_agg(e.id) into ent_ids
        from public.entities e
        where not exists (
            select 1 from public.relations r
            where r.src = e.id or r.dst = e.id
        )
        and not exists (
            select 1 from public.memory_entities me
            where me.entity_id = e.id
        );

        v_ent_count := coalesce(array_length(ent_ids, 1), 0);
        if not dry_run and v_ent_count > 0 then
            delete from public.entities where id = any(ent_ids);
        end if;
    end if;

    return query select v_rel_count, v_mem_count, v_ent_count;
end;
$$;

-- ==============================================================================
-- 11. Dietz-Burgess Agent Interaction & Handover Protocol
-- Based on Jan Dietz's DEMO Transaction Pattern & Mark Burgess's Promise Theory
-- ==============================================================================

-- 11.1 Transactions Table (State Machine)
create table if not exists public.transactions (
    id text primary key default ('tx_' || to_char(now(), 'YYYYMMDD_') || substr(gen_random_uuid()::text, 1, 8)),
    parent_id text references public.transactions(id) on delete set null,
    session_id text,
    owner_id uuid references auth.users(id) on delete set null,
    visibility text default 'shared' not null check (visibility in ('private', 'shared')),
    initiator_id text not null,
    executor_id text not null,
    state text not null check (state in (
        'REQUESTED',
        'CONDITIONAL_PROMISE',
        'PROMISED',
        'IN_EXECUTION',
        'DECLARED',
        'REJECTED',
        'ACCEPTED',
        'DECLINED',
        'REVOKED'
    )),
    p_fact_type text not null,
    p_fact_spec jsonb not null,
    conditions jsonb default '[]'::jsonb not null,
    review_sla_seconds integer default 3600,
    deliverables jsonb default '{}'::jsonb not null,
    evidence jsonb default '{}'::jsonb not null,
    assessment jsonb default '{}'::jsonb not null,
    memory_id uuid references public.memories(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.transactions add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.transactions add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));

drop trigger if exists set_transactions_updated_at on public.transactions;
create trigger set_transactions_updated_at
    before update on public.transactions
    for each row
    execute function update_updated_at_column();

create index if not exists idx_transactions_initiator on public.transactions(initiator_id);
create index if not exists idx_transactions_executor on public.transactions(executor_id);
create index if not exists idx_transactions_state on public.transactions(state);
create index if not exists idx_transactions_parent_id on public.transactions(parent_id);
create index if not exists idx_transactions_session_id on public.transactions(session_id);
create index if not exists idx_transactions_created_at on public.transactions(created_at desc);
create index if not exists idx_transactions_owner_id on public.transactions(owner_id);
create index if not exists idx_transactions_visibility on public.transactions(visibility);

alter table public.transactions enable row level security;
drop policy if exists "Allow service role full access on transactions" on public.transactions;
create policy "Allow service role full access on transactions"
    on public.transactions for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users select transactions" on public.transactions;
create policy "Authenticated users select transactions"
    on public.transactions for select to authenticated
    using (owner_id = auth.uid() or visibility = 'shared' or owner_id is null);

drop policy if exists "Authenticated users insert transactions" on public.transactions;
create policy "Authenticated users insert transactions"
    on public.transactions for insert to authenticated
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users update own transactions" on public.transactions;
create policy "Authenticated users update own transactions"
    on public.transactions for update to authenticated
    using (owner_id = auth.uid() or owner_id is null)
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users delete own transactions" on public.transactions;
create policy "Authenticated users delete own transactions"
    on public.transactions for delete to authenticated
    using (owner_id = auth.uid());

drop policy if exists "Anon select shared transactions" on public.transactions;
drop policy if exists "Allow anon access on transactions" on public.transactions;
create policy "Anon select shared transactions"
    on public.transactions for select to anon
    using (visibility = 'shared' or owner_id is null);

-- 11.2 Coordination Acts (Immutable Event Audit Log)
create table if not exists public.coordination_acts (
    id bigint generated always as identity primary key,
    transaction_id text not null references public.transactions(id) on delete cascade,
    owner_id uuid references auth.users(id) on delete set null,
    act_type text not null check (act_type in (
        'REQUEST',
        'PROMISE',
        'DECLINE',
        'FULFILL_CONDITIONS',
        'DECLARE',
        'REJECT',
        'ACCEPT',
        'REVOKE'
    )),
    actor_id text not null,
    role text not null check (role in ('INITIATOR', 'EXECUTOR', 'OBSERVER')),
    message text not null,
    payload jsonb default '{}'::jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.coordination_acts add column if not exists owner_id uuid references auth.users(id) on delete set null;

create index if not exists idx_coordination_acts_tx on public.coordination_acts(transaction_id);
create index if not exists idx_coordination_acts_actor on public.coordination_acts(actor_id);
create index if not exists idx_coordination_acts_act_type on public.coordination_acts(act_type);
create index if not exists idx_coordination_acts_created_at on public.coordination_acts(created_at desc);
create index if not exists idx_coordination_acts_owner_id on public.coordination_acts(owner_id);

alter table public.coordination_acts enable row level security;
drop policy if exists "Allow service role full access on coordination_acts" on public.coordination_acts;
create policy "Allow service role full access on coordination_acts"
    on public.coordination_acts for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users select coordination_acts" on public.coordination_acts;
create policy "Authenticated users select coordination_acts"
    on public.coordination_acts for select to authenticated
    using (true);

drop policy if exists "Authenticated users insert coordination_acts" on public.coordination_acts;
create policy "Authenticated users insert coordination_acts"
    on public.coordination_acts for insert to authenticated
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Anon select coordination_acts" on public.coordination_acts;
drop policy if exists "Allow anon access on coordination_acts" on public.coordination_acts;
create policy "Anon select coordination_acts"
    on public.coordination_acts for select to anon
    using (true);

-- 11.3 Standing Promises (Agent Capability Catalog)
create table if not exists public.standing_promises (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid references auth.users(id) on delete set null,
    visibility text default 'shared' not null check (visibility in ('private', 'shared')),
    agent_id text not null,
    capability text not null,
    description text not null,
    guaranteed_sla_seconds integer,
    prerequisites jsonb default '[]'::jsonb not null,
    is_active boolean default true not null,
    metadata jsonb default '{}'::jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.standing_promises add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.standing_promises add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));

drop trigger if exists set_standing_promises_updated_at on public.standing_promises;
create trigger set_standing_promises_updated_at
    before update on public.standing_promises
    for each row
    execute function update_updated_at_column();

create index if not exists idx_standing_promises_agent on public.standing_promises(agent_id);
create index if not exists idx_standing_promises_capability on public.standing_promises(capability);
create index if not exists idx_standing_promises_active on public.standing_promises(is_active);
create index if not exists idx_standing_promises_owner_id on public.standing_promises(owner_id);
create index if not exists idx_standing_promises_visibility on public.standing_promises(visibility);

alter table public.standing_promises enable row level security;
drop policy if exists "Allow service role full access on standing_promises" on public.standing_promises;
create policy "Allow service role full access on standing_promises"
    on public.standing_promises for all to service_role using (true) with check (true);

drop policy if exists "Authenticated users select standing_promises" on public.standing_promises;
create policy "Authenticated users select standing_promises"
    on public.standing_promises for select to authenticated
    using (owner_id = auth.uid() or visibility = 'shared' or owner_id is null);

drop policy if exists "Authenticated users insert standing_promises" on public.standing_promises;
create policy "Authenticated users insert standing_promises"
    on public.standing_promises for insert to authenticated
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users update own standing_promises" on public.standing_promises;
create policy "Authenticated users update own standing_promises"
    on public.standing_promises for update to authenticated
    using (owner_id = auth.uid() or owner_id is null)
    with check (owner_id = auth.uid() or owner_id is null);

drop policy if exists "Authenticated users delete own standing_promises" on public.standing_promises;
create policy "Authenticated users delete own standing_promises"
    on public.standing_promises for delete to authenticated
    using (owner_id = auth.uid());

drop policy if exists "Anon select shared standing_promises" on public.standing_promises;
drop policy if exists "Allow anon access on standing_promises" on public.standing_promises;
create policy "Anon select shared standing_promises"
    on public.standing_promises for select to anon
    using (visibility = 'shared' or owner_id is null);


