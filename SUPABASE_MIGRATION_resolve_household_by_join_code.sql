-- Stateless household join-code resolver for authenticated users.
create or replace function public.resolve_household_by_join_code(code_prefix text)
returns table (
  id uuid,
  name text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized text;
begin
  normalized := upper(trim(coalesce(code_prefix, '')));
  if left(normalized, 2) = 'H-' then
    normalized := substr(normalized, 3);
  end if;

  if normalized !~ '^[A-F0-9]{8}$' then
    return;
  end if;

  return query
  select h.id, h.name
  from public.households h
  where upper(left(h.id::text, 8)) = normalized
  order by h.created_at asc;
end;
$$;

grant execute on function public.resolve_household_by_join_code(text) to authenticated;
