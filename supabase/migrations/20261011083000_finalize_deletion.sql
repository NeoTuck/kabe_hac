-- Durable completion is separate from receiving/preparing a deletion request.
create function public.finalize_account_deletion(target_request uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare operation public.account_deletion_operations%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Deletion service role required' using errcode = '42501';
  end if;
  select * into operation from public.account_deletion_operations
    where request_id = target_request for update;
  if not found then raise exception 'Deletion operation not found'; end if;
  if operation.status = 'deleted' then return true; end if;
  if operation.status <> 'processing' then raise exception 'Deletion operation not processing'; end if;
  if operation.user_id is not null and exists(select 1 from auth.users where id=operation.user_id) then
    raise exception 'Auth user still exists; completion refused';
  end if;
  update public.account_deletion_operations set status='deleted', user_id=null,
    completed_at=clock_timestamp() where request_id=target_request;
  return true;
end; $$;
revoke all on function public.finalize_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.finalize_account_deletion(uuid) to service_role;
