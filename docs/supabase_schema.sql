-- =====================================================================
-- Peculio · Sincronización de pareja (versión 2.0)
-- Pega TODO este archivo en Supabase → SQL Editor → Run.
-- Antes: Authentication → Sign In / Providers → activa "Allow anonymous sign-ins".
-- El servidor solo guarda texto CIFRADO en el teléfono (payload + nonce):
-- no puede leer los gastos.
-- =====================================================================

create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  invite_hash text unique not null,          -- hash del código de invitación (no el código)
  created_at timestamptz not null default now()
);

create table if not exists public.couple_members (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  joined_at timestamptz not null default now(),
  primary key (couple_id, user_id)
);

create table if not exists public.shared_items (
  couple_id uuid not null references public.couples(id) on delete cascade,
  id text not null,                           -- id generado en el teléfono
  author_id uuid not null default auth.uid(),
  kind text not null,                         -- 'expense' | 'settlement'
  payload text not null,                      -- JSON cifrado (base64)
  nonce text not null,
  deleted boolean not null default false,     -- borrado lógico para sincronizar
  updated_at timestamptz not null default now(),
  primary key (couple_id, id)
);

create index if not exists shared_items_updated_idx on public.shared_items (couple_id, updated_at);

alter table public.couples enable row level security;
alter table public.couple_members enable row level security;
alter table public.shared_items enable row level security;

-- ¿El usuario actual pertenece a esta pareja?
create or replace function public.is_member(c uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.couple_members m
    where m.couple_id = c and m.user_id = auth.uid()
  );
$$;

drop policy if exists couples_select on public.couples;
create policy couples_select on public.couples
  for select to authenticated using (public.is_member(id));

drop policy if exists members_select on public.couple_members;
create policy members_select on public.couple_members
  for select to authenticated using (public.is_member(couple_id));

drop policy if exists items_select on public.shared_items;
create policy items_select on public.shared_items
  for select to authenticated using (public.is_member(couple_id));

drop policy if exists items_insert on public.shared_items;
create policy items_insert on public.shared_items
  for insert to authenticated with check (public.is_member(couple_id) and author_id = auth.uid());

drop policy if exists items_update on public.shared_items;
create policy items_update on public.shared_items
  for update to authenticated using (public.is_member(couple_id))
  with check (public.is_member(couple_id));

-- Crear la pareja (la persona que invita).
create or replace function public.create_couple(p_invite_hash text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.couples (invite_hash) values (p_invite_hash) returning id into cid;
  insert into public.couple_members (couple_id, user_id) values (cid, auth.uid());
  return cid;
end;
$$;

-- Unirse con el código de invitación (máximo 2 personas por pareja).
create or replace function public.join_couple(p_invite_hash text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select id into cid from public.couples where invite_hash = p_invite_hash;
  if cid is null then raise exception 'invalid code'; end if;
  if (select count(*) from public.couple_members where couple_id = cid) >= 2
     and not exists (select 1 from public.couple_members where couple_id = cid and user_id = auth.uid()) then
    raise exception 'couple is full';
  end if;
  insert into public.couple_members (couple_id, user_id) values (cid, auth.uid())
  on conflict do nothing;
  return cid;
end;
$$;

-- Solo quien tiene sesión (incluidas las sesiones anónimas de la app) puede ejecutarlas.
revoke execute on function public.create_couple(text) from public, anon;
revoke execute on function public.join_couple(text) from public, anon;
revoke execute on function public.is_member(uuid) from public, anon;
grant execute on function public.create_couple(text) to authenticated;
grant execute on function public.join_couple(text) to authenticated;
grant execute on function public.is_member(uuid) to authenticated;


-- =====================================================================
-- Versión 2.0: ajustes aplicados al proyecto (ya están en tu Supabase).
-- =====================================================================

-- updated_at lo pone el servidor (no depende del reloj del teléfono).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists shared_items_set_updated on public.shared_items;
create trigger shared_items_set_updated
  before insert or update on public.shared_items
  for each row execute function public.set_updated_at();

-- Cada persona solo puede modificar y borrar lo que ella misma escribió.
drop policy if exists items_update on public.shared_items;
create policy items_update on public.shared_items
  for update to authenticated
  using (public.is_member(couple_id) and author_id = auth.uid())
  with check (public.is_member(couple_id) and author_id = auth.uid());

drop policy if exists items_delete on public.shared_items;
create policy items_delete on public.shared_items
  for delete to authenticated
  using (author_id = auth.uid());

-- Cada persona puede salir de la pareja (borra solo su propia membresía).
drop policy if exists members_delete on public.couple_members;
create policy members_delete on public.couple_members
  for delete to authenticated
  using (user_id = auth.uid());

-- Unirse con el código: hasta 4 identidades (2 personas + reinstalaciones).
create or replace function public.join_couple(p_invite_hash text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select id into cid from public.couples where invite_hash = p_invite_hash;
  if cid is null then raise exception 'invalid code'; end if;
  if (select count(*) from public.couple_members where couple_id = cid) >= 4
     and not exists (select 1 from public.couple_members where couple_id = cid and user_id = auth.uid()) then
    raise exception 'couple is full';
  end if;
  insert into public.couple_members (couple_id, user_id) values (cid, auth.uid())
  on conflict do nothing;
  return cid;
end;
$$;

revoke execute on function public.join_couple(text) from public, anon;
grant execute on function public.join_couple(text) to authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;
