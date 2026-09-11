-- Live driver position for active runs (household observers).
create table if not exists public.run_driver_positions (
  run_id uuid primary key references public.runs(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  driver_id uuid,
  latitude double precision not null,
  longitude double precision not null,
  speed_mps double precision,
  heading_degrees double precision,
  updated_at timestamptz not null default now()
);

create index if not exists run_driver_positions_household_id_idx
  on public.run_driver_positions (household_id);

alter table public.run_driver_positions enable row level security;
