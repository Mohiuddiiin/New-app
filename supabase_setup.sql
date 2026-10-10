-- DailyBudget Supabase schema
-- Run this complete file in Supabase Dashboard > SQL Editor as project owner.
-- The browser frontend must use only the project's publishable/anon key, never service_role.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = timezone('utc', now()); return new; end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type text not null check (type in ('income','expense')),
  amount numeric(14,2) not null check (amount > 0 and amount < 1000000000000),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  date date not null,
  category text not null check (length(category) between 1 and 120),
  description text not null check (length(description) between 1 and 160),
  payment_method text not null default 'Other' check (length(payment_method) <= 80),
  essential boolean not null default true,
  notes text not null default '' check (length(notes) <= 1000),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index if not exists transactions_owner_date_idx on public.transactions(user_id, date desc);
create index if not exists transactions_owner_category_idx on public.transactions(user_id, category);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category text not null check (length(category) between 1 and 120),
  amount numeric(14,2) not null check (amount > 0 and amount < 1000000000000),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  month text not null check (month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique(user_id, category, month)
);
create index if not exists budgets_owner_month_idx on public.budgets(user_id, month);

create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(name) between 1 and 120),
  amount numeric(14,2) not null check (amount > 0 and amount < 1000000000000),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  due_date date not null,
  recurrence text not null default 'one-time' check (recurrence in ('one-time','weekly','monthly','annually')),
  status text not null default 'upcoming' check (status in ('upcoming','paid')),
  notes text not null default '' check (length(notes) <= 1000),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index if not exists bills_owner_due_idx on public.bills(user_id, due_date);

create table if not exists public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(name) between 1 and 120),
  target_amount numeric(14,2) not null check (target_amount > 0 and target_amount < 1000000000000),
  saved_amount numeric(14,2) not null default 0 check (saved_amount >= 0 and saved_amount < 1000000000000),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  target_date date,
  description text not null default '' check (length(description) <= 240),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index if not exists goals_owner_idx on public.savings_goals(user_id);

create table if not exists public.app_preferences (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  daily_limit numeric(14,2) not null default 50 check (daily_limit >= 0 and daily_limit < 1000000000000),
  rollover boolean not null default false,
  theme text not null default 'light' check (theme in ('light','dark')),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Create a profile row on signup. This function runs with definer rights only for this
-- narrow insert; users still access their own profile through RLS.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name',''))
  on conflict (id) do nothing;
  insert into public.app_preferences (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_dailybudget on auth.users;
create trigger on_auth_user_created_dailybudget
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Enable RLS and strictly scope every operation to the authenticated owner.
alter table public.profiles enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.bills enable row level security;
alter table public.savings_goals enable row level security;
alter table public.app_preferences enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select to authenticated using (id = (select auth.uid()));
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own" on public.profiles for delete to authenticated using (id = (select auth.uid()));

do $$
declare t text;
begin
  foreach t in array array['transactions','budgets','bills','savings_goals'] loop
    execute format('drop policy if exists %I on public.%I', t||'_select_own', t);
    execute format('create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()))', t||'_select_own', t);
    execute format('drop policy if exists %I on public.%I', t||'_insert_own', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t||'_insert_own', t);
    execute format('drop policy if exists %I on public.%I', t||'_update_own', t);
    execute format('create policy %I on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t||'_update_own', t);
    execute format('drop policy if exists %I on public.%I', t||'_delete_own', t);
    execute format('create policy %I on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t||'_delete_own', t);
  end loop;
end $$;

drop policy if exists "preferences_select_own" on public.app_preferences;
create policy "preferences_select_own" on public.app_preferences for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "preferences_insert_own" on public.app_preferences;
create policy "preferences_insert_own" on public.app_preferences for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "preferences_update_own" on public.app_preferences;
create policy "preferences_update_own" on public.app_preferences for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists "preferences_delete_own" on public.app_preferences;
create policy "preferences_delete_own" on public.app_preferences for delete to authenticated using (user_id = (select auth.uid()));

-- No anonymous policies are created. Anonymous visitors cannot read/write private rows.
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles, public.transactions, public.budgets,
  public.bills, public.savings_goals, public.app_preferences to authenticated;

-- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array['profiles','transactions','budgets','bills','savings_goals','app_preferences'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute procedure public.set_updated_at()', t);
  end loop;
end $$;
