-- The image budget must never fail open: once used reaches cap, a reservation returns no row
-- and leaves used unchanged. Run by `mise run test:db`; the whole file rolls back.
begin;
select plan(4);

update public.image_budget set used = cap - 1;

select results_eq(
  'update public.image_budget set used = used + 1 where used < cap returning used = cap',
  $$values (true)$$,
  'the last free slot can be reserved'
);

select is_empty(
  'update public.image_budget set used = used + 1 where used < cap returning used',
  'a reservation at the cap returns no row'
);

select ok(
  (select used = cap from public.image_budget),
  'used stays at cap after a refused reservation'
);

select is(
  (select count(*)::int from public.image_budget),
  1,
  'image_budget holds exactly one row'
);

select * from finish();
rollback;
