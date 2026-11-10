-- Qyra: free replies per user per day (safe to run more than once)
create table if not exists public.qyra_usage (
  device text not null,
  day date not null default (now() at time zone 'utc')::date,
  n int not null default 0,
  primary key (device, day)
);
alter table public.qyra_usage enable row level security;

create or replace function public.qyra_bump(p_device text, p_limit int)
returns int language plpgsql security definer set search_path = public as $$
declare v int;
begin
  insert into qyra_usage (device, day, n) values (p_device, (now() at time zone 'utc')::date, 1)
  on conflict (device, day) do update set n = qyra_usage.n + 1
  returning n into v;
  if v > p_limit then return -1; end if;
  return v;
end $$;

revoke all on function public.qyra_bump(text, int) from public, anon, authenticated;
grant execute on function public.qyra_bump(text, int) to service_role;
grant select, insert, update on table public.qyra_usage to service_role;
