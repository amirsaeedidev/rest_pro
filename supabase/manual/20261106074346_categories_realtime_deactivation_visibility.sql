-- Categories are public catalog metadata.
-- Customers must be able to observe active -> inactive updates over Postgres Changes.
-- The customer app filters inactive categories before displaying them.
create policy "categories_realtime_snapshot_select"
on public.categories
for select
to anon, authenticated
using (true);
