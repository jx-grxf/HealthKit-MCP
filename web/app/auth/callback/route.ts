import { NextResponse } from "next/server";
import { supabaseServer } from "@/lib/supabase";

/** Exchanges the OAuth code from Sign in with Apple for a session cookie. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const redirect = url.searchParams.get("redirect") ?? "/";

  if (!code) {
    return NextResponse.redirect(new URL("/login", url.origin));
  }

  const supabase = await supabaseServer();
  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    return NextResponse.redirect(new URL("/login", url.origin));
  }

  // Only ever bounce to a path on this origin, never an attacker-supplied host.
  const safePath = redirect.startsWith("/") ? redirect : "/";
  return NextResponse.redirect(new URL(safePath, url.origin));
}
