-- The private Storage bucket progress-photo objects live in (see
-- docs/DATA_MODEL.md "Progress photos — sensitive, consent-gated").
-- `SupabaseBackend+ProgressPhotoRepository.swift` never uploads/reads bytes
-- through this migration's SQL — it stores/resolves paths — but the bucket
-- and its access policies must exist for `createSignedURL`/`upload` calls to
-- succeed and stay scoped to the right people.
--
-- Object paths are expected to be namespaced `<engagement_id>/<photo_id>`,
-- so `storage.foldername(name)` (Supabase's helper splitting an object path
-- on `/`) gives the owning engagement id as the first path segment for the
-- policies below.

insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false)
on conflict (id) do nothing;

create policy "progress_photos_read_client_or_consented_professional"
    on storage.objects for select
    using (
        bucket_id = 'progress-photos'
        and exists (
            select 1 from public.engagements e
            where e.id::text = (storage.foldername(name))[1]
              and (
                  e.client_id = auth.uid()
                  or (e.professional_id = auth.uid() and e.photo_consent_granted)
              )
        )
    );

create policy "progress_photos_write_client_or_professional"
    on storage.objects for insert
    with check (
        bucket_id = 'progress-photos'
        and exists (
            select 1 from public.engagements e
            where e.id::text = (storage.foldername(name))[1]
              and (e.client_id = auth.uid() or e.professional_id = auth.uid())
        )
    );

create policy "progress_photos_delete_client_or_professional"
    on storage.objects for delete
    using (
        bucket_id = 'progress-photos'
        and exists (
            select 1 from public.engagements e
            where e.id::text = (storage.foldername(name))[1]
              and (e.client_id = auth.uid() or e.professional_id = auth.uid())
        )
    );
