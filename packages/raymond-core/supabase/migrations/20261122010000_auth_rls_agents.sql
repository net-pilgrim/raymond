-- ==============================================================================
-- Migration: 20261122010000_auth_rls_agents.sql
-- Raymond Phase 1: Row Level Security (RLS) Foundation & Agents Registry Table
-- ==============================================================================

-- 1. Create Agents Registry Table
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

drop trigger if exists set_agents_updated_at on public.agents;
create trigger set_agents_updated_at
    before update on public.agents
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


-- 2. Add owner_id and visibility columns to core tables
-- Default visibility is 'shared' to ensure seamless backwards compatibility for existing data.

-- 2.1 Memories
alter table public.memories add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.memories add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));
create index if not exists idx_memories_owner_id on public.memories(owner_id);
create index if not exists idx_memories_visibility on public.memories(visibility);

-- 2.2 Entities
alter table public.entities add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.entities add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));
create index if not exists idx_entities_owner_id on public.entities(owner_id);
create index if not exists idx_entities_visibility on public.entities(visibility);

-- 2.3 Relations
alter table public.relations add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.relations add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));
create index if not exists idx_relations_owner_id on public.relations(owner_id);
create index if not exists idx_relations_visibility on public.relations(visibility);

-- 2.4 Memory Entities
alter table public.memory_entities add column if not exists owner_id uuid references auth.users(id) on delete set null;
create index if not exists idx_memory_entities_owner_id on public.memory_entities(owner_id);

-- 2.5 Skills
alter table public.skills add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.skills add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));
create index if not exists idx_skills_owner_id on public.skills(owner_id);
create index if not exists idx_skills_visibility on public.skills(visibility);

-- 2.6 Transactions
alter table public.transactions add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.transactions add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));
create index if not exists idx_transactions_owner_id on public.transactions(owner_id);
create index if not exists idx_transactions_visibility on public.transactions(visibility);

-- 2.7 Coordination Acts
alter table public.coordination_acts add column if not exists owner_id uuid references auth.users(id) on delete set null;
create index if not exists idx_coordination_acts_owner_id on public.coordination_acts(owner_id);

-- 2.8 Standing Promises
alter table public.standing_promises add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.standing_promises add column if not exists visibility text default 'shared' check (visibility in ('private', 'shared'));
create index if not exists idx_standing_promises_owner_id on public.standing_promises(owner_id);
create index if not exists idx_standing_promises_visibility on public.standing_promises(visibility);


-- 3. Row Level Security Policies

-- 3.1 Memories RLS
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
create policy "Anon select shared memories"
    on public.memories for select to anon
    using (visibility = 'shared' or owner_id is null);

-- 3.2 Entities RLS
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
create policy "Anon select shared entities"
    on public.entities for select to anon
    using (visibility = 'shared' or owner_id is null);

-- 3.3 Relations RLS
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
create policy "Anon select shared relations"
    on public.relations for select to anon
    using (visibility = 'shared' or owner_id is null);

-- 3.4 Memory Entities RLS
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
create policy "Anon select memory_entities"
    on public.memory_entities for select to anon
    using (true);

-- 3.5 Skills RLS
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
create policy "Anon select shared skills"
    on public.skills for select to anon
    using (visibility = 'shared' or owner_id is null);

-- 3.6 Transactions RLS
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
create policy "Anon select shared transactions"
    on public.transactions for select to anon
    using (visibility = 'shared' or owner_id is null);

-- 3.7 Coordination Acts RLS
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
create policy "Anon select coordination_acts"
    on public.coordination_acts for select to anon
    using (true);

-- 3.8 Standing Promises RLS
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
create policy "Anon select shared standing_promises"
    on public.standing_promises for select to anon
    using (visibility = 'shared' or owner_id is null);
