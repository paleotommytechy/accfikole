-- PROPOSED ONLY — not automatically applied to production.
-- Supabase security advisors report RLS disabled on these public tables.
-- This script preserves the existing task/task-assignment behavior while
-- tightening gallery metadata writes and keeping app settings readable.

alter table public.tasks enable row level security;
alter table public.tasks_assignments enable row level security;
alter table public.gallery_images enable row level security;
alter table public.app_settings enable row level security;

-- gallery_images currently allows every authenticated user to write every row.
drop policy if exists "Allow authenticated users to upload images" on public.gallery_images;
drop policy if exists "Allow authenticated users to update images" on public.gallery_images;
drop policy if exists "Allow authenticated users to delete images" on public.gallery_images;

create policy "Media and admins can insert gallery images"
on public.gallery_images
for insert
to authenticated
with check (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role in ('admin', 'media')
  )
);

create policy "Media and admins can update gallery images"
on public.gallery_images
for update
to authenticated
using (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role in ('admin', 'media')
  )
)
with check (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role in ('admin', 'media')
  )
);

create policy "Media and admins can delete gallery images"
on public.gallery_images
for delete
to authenticated
using (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role in ('admin', 'media')
  )
);

-- app_settings is not referenced by the current dashboard source. Preserve its
-- existing read visibility while restricting writes to admins.
create policy "Public can read app settings"
on public.app_settings
for select
to public
using (true);

create policy "Admins can manage app settings"
on public.app_settings
for all
to authenticated
using (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role = 'admin'
  )
)
with check (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role = 'admin'
  )
);
