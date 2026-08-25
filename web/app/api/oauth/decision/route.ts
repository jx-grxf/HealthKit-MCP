import { NextResponse } from "next/server";
import { supabaseServer } from "@/lib/supabase";

/**
 * Applies the user's decision and bounces back to the OAuth client.
 *
 * POST-only and session-bound: the decision is taken from the signed-in user's
 * cookies, so a link cannot be crafted that approves access on someone's behalf.
 */
export async function POST(request: Request) {
  const form = await request.formData();
  const decision = form.get("decision");
  const authorizationId = form.get("authorization_id");

  if (typeof authorizationId !== "string" || !authorizationId) {
    return NextResponse.json({ error: "missing authorization_id" }, { status: 400 });
  }

  const supabase = await supabaseServer();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "not authenticated" }, { status: 401 });
  }

  // Anything that is not an explicit approval is treated as a denial.
  const approving = decision === "approve";
  const { data, error } = approving
    ? await supabase.auth.oauth.approveAuthorization(authorizationId)
    : await supabase.auth.oauth.denyAuthorization(authorizationId);

  if (error || !data) {
    return NextResponse.json(
      { error: error?.message ?? "authorization failed" },
      { status: 400 },
    );
  }

  return NextResponse.redirect(data.redirect_url, { status: 303 });
}
