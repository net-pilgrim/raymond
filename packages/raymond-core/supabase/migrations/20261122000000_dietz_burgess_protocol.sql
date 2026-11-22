
-- ==============================================================================
-- 11. Dietz-Burgess Agent Interaction & Handover Protocol
-- Based on Jan Dietz's DEMO Transaction Pattern & Mark Burgess's Promise Theory
-- ==============================================================================

-- 11.1 Transactions Table (State Machine)
create table if not exists public.transactions (
    id text primary key default ('tx_' || to_char(now(), 'YYYYMMDD_') || substr(gen_random_uuid()::text, 1, 8)),
    parent_id text references public.transactions(id) on delete set null,
    session_id text,
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

alter table public.transactions enable row level security;
drop policy if exists "Allow service role full access on transactions" on public.transactions;
create policy "Allow service role full access on transactions" on public.transactions for all to service_role using (true) with check (true);
drop policy if exists "Allow anon access on transactions" on public.transactions;
create policy "Allow anon access on transactions" on public.transactions for all to anon using (true) with check (true);

-- 11.2 Coordination Acts (Immutable Event Audit Log)
create table if not exists public.coordination_acts (
    id bigint generated always as identity primary key,
    transaction_id text not null references public.transactions(id) on delete cascade,
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

create index if not exists idx_coordination_acts_tx on public.coordination_acts(transaction_id);
create index if not exists idx_coordination_acts_actor on public.coordination_acts(actor_id);
create index if not exists idx_coordination_acts_act_type on public.coordination_acts(act_type);
create index if not exists idx_coordination_acts_created_at on public.coordination_acts(created_at desc);

alter table public.coordination_acts enable row level security;
drop policy if exists "Allow service role full access on coordination_acts" on public.coordination_acts;
create policy "Allow service role full access on coordination_acts" on public.coordination_acts for all to service_role using (true) with check (true);
drop policy if exists "Allow anon access on coordination_acts" on public.coordination_acts;
create policy "Allow anon access on coordination_acts" on public.coordination_acts for all to anon using (true) with check (true);

-- 11.3 Standing Promises (Agent Capability Catalog)
create table if not exists public.standing_promises (
    id uuid primary key default gen_random_uuid(),
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

drop trigger if exists set_standing_promises_updated_at on public.standing_promises;
create trigger set_standing_promises_updated_at
    before update on public.standing_promises
    for each row
    execute function update_updated_at_column();

create index if not exists idx_standing_promises_agent on public.standing_promises(agent_id);
create index if not exists idx_standing_promises_capability on public.standing_promises(capability);
create index if not exists idx_standing_promises_active on public.standing_promises(is_active);

alter table public.standing_promises enable row level security;
drop policy if exists "Allow service role full access on standing_promises" on public.standing_promises;
create policy "Allow service role full access on standing_promises" on public.standing_promises for all to service_role using (true) with check (true);
drop policy if exists "Allow anon access on standing_promises" on public.standing_promises;
create policy "Allow anon access on standing_promises" on public.standing_promises for all to anon using (true) with check (true);


