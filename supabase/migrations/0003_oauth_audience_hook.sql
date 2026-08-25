-- Bind OAuth access tokens to this MCP resource.
--
-- Supabase issues OAuth access tokens with `aud` set to "authenticated" — the
-- same value every token in the project carries. The MCP server rejects tokens
-- whose audience is not this resource, because without that binding a token
-- minted for some other service could be replayed against the health data
-- (RFC 8707 resource binding; the confused-deputy problem).
--
-- This hook rewrites `aud` to the resource URL, but only for tokens issued to
-- an OAuth client. Tokens from ordinary sessions — the iOS app talking to
-- PostgREST — keep `aud = "authenticated"`, which is what PostgREST and the
-- RLS policies expect. Rewriting those would break the app.

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
begin
  claims := event -> 'claims';

  -- `client_id` is present only on tokens issued through the OAuth 2.1 server.
  if claims ? 'client_id' then
    claims := jsonb_set(
      claims,
      '{aud}',
      to_jsonb('https://mcp.johannesgrof.me/mcp'::text)
    );
    event := jsonb_set(event, '{claims}', claims);
  end if;

  return event;
end;
$$;

comment on function public.custom_access_token_hook(jsonb) is
  'Sets aud to the MCP resource URL for OAuth-issued tokens so the MCP server can audience-bind them. Session tokens are left untouched.';

-- Only the auth admin may run the hook; nobody else should be able to call it.
grant usage on schema public to supabase_auth_admin;

grant execute on function public.custom_access_token_hook(jsonb)
  to supabase_auth_admin;

revoke execute on function public.custom_access_token_hook(jsonb)
  from authenticated, anon, public;
