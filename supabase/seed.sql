-- Local-only conveniences. db:reset runs this after the migrations; hosted never sees it.

-- Local can try image flows freely: the image provider here is always `fake`.
update public.image_budget set cap = 1000;

-- The agent/test User: agent@wearai.test / wearai-local-only
-- The password is public on purpose: this User exists only on local.
-- Its profiles row and active Stylist arrive with the first product slice that creates those tables.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values (
  '00000000-0000-0000-0000-000000000000',
  'a9e47000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'agent@wearai.test',
  extensions.crypt('wearai-local-only', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}', '{}', now(), now(),
  '', '', '', ''
);

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
) values (
  gen_random_uuid(),
  'a9e47000-0000-4000-8000-000000000001',
  'a9e47000-0000-4000-8000-000000000001',
  'email',
  '{"sub":"a9e47000-0000-4000-8000-000000000001","email":"agent@wearai.test","email_verified":true}',
  now(), now(), now()
);
