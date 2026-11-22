-- The total number of Nano Banana calls WearAI may make (docs/spec/data-model.md#image-budget).
-- One row, not owned by a User. Edge Functions reserve a slot before every image call:
--   update image_budget set used = used + 1 where used < cap returning used;
-- No row returned means the budget is used up and the model isn't called.
create table public.image_budget (
  id boolean primary key default true check (id),
  used int not null default 0 check (used >= 0),
  cap int not null check (cap >= 0)
);

comment on table public.image_budget is
  'Single row capping total Nano Banana calls. Raise hosted''s cap with a migration; seed.sql raises local''s.';

-- No client access: only Edge Functions (service role) read or reserve.
alter table public.image_budget enable row level security;
revoke all on table public.image_budget from anon, authenticated;

-- Hosted starts at 30 and never higher. seed.sql raises local to 1000.
insert into public.image_budget (used, cap) values (0, 30);
