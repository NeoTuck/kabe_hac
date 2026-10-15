-- Atomic personal group + first membership, available only to the authenticated owner.
create or replace function public.create_personal_group(group_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_group uuid;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if group_name is null or char_length(trim(group_name)) not between 2 and 120 then
    raise exception 'invalid group name' using errcode = '22023';
  end if;
  insert into public.groups(name, created_by) values(trim(group_name), auth.uid()) returning id into new_group;
  insert into public.group_members(group_id, user_id, role) values(new_group, auth.uid(), 'group_admin');
  return new_group;
end;
$$;
revoke all on function public.create_personal_group(text) from public;
grant execute on function public.create_personal_group(text) to authenticated;
alter publication supabase_realtime add table public.group_members;
