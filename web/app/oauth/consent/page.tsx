import { redirect } from "next/navigation";
import { supabaseServer } from "@/lib/supabase";

/**
 * OAuth 2.1 consent screen.
 *
 * Supabase Auth has no hosted consent UI: it redirects here with an
 * `authorization_id`, and this page is what stands between an AI assistant and
 * a user's health data. Approving is what mints the authorization code.
 */
export default async function ConsentPage({
  searchParams,
}: {
  searchParams: Promise<{ authorization_id?: string }>;
}) {
  const { authorization_id: authorizationId } = await searchParams;

  if (!authorizationId) {
    return (
      <main>
        <h1>Invalid request</h1>
        <p>This link is missing an authorization id. Start again from the app you were connecting.</p>
      </main>
    );
  }

  const supabase = await supabaseServer();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect(
      `/login?redirect=${encodeURIComponent(`/oauth/consent?authorization_id=${authorizationId}`)}`,
    );
  }

  const { data, error } =
    await supabase.auth.oauth.getAuthorizationDetails(authorizationId);

  if (error || !data) {
    return (
      <main>
        <h1>Authorization failed</h1>
        <p>{error?.message ?? "This authorization request is no longer valid."}</p>
      </main>
    );
  }

  // Already consented previously — Supabase returns a redirect instead.
  if (!("authorization_id" in data)) {
    redirect(data.redirect_url);
  }

  const scopes = data.scope?.trim() ? data.scope.trim().split(/\s+/) : [];

  return (
    <main>
      <h1>Connect {data.client.name} to your health data?</h1>
      <p>
        Signed in as <strong>{user.email ?? user.id}</strong>.
      </p>

      <div className="card">
        <div className="row">
          <span>Application</span>
          <span>{data.client.name}</span>
        </div>
        <div className="row">
          <span>Redirects to</span>
          <span className="mono">{data.redirect_uri}</span>
        </div>
        {scopes.length > 0 && (
          <div className="row">
            <span>Scopes</span>
            <span className="mono">{scopes.join(", ")}</span>
          </div>
        )}
      </div>

      <h2>What it will be able to read</h2>
      <p>
        Only the health categories you switched on in the Wavelet app, as daily
        summaries. Categories you have not enabled stay invisible — this
        application cannot see that they exist, and cannot request them later
        without you switching them on yourself.
      </p>
      <p>
        It never receives individual measurements, and your health data is never
        used for advertising or profiling. You can disconnect at any time.
      </p>

      <form action="/api/oauth/decision" method="POST" className="actions">
        <input type="hidden" name="authorization_id" value={authorizationId} />
        <button type="submit" name="decision" value="approve" className="primary">
          Allow access
        </button>
        <button type="submit" name="decision" value="deny">
          Deny
        </button>
      </form>
    </main>
  );
}
