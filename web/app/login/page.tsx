"use client";

import { createBrowserClient } from "@supabase/ssr";
import { useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

function LoginForm() {
  const params = useSearchParams();
  const redirectTo = params.get("redirect") ?? "/";
  const [error, setError] = useState<string | null>(null);

  async function signIn() {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    );
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "apple",
      options: {
        redirectTo: `${window.location.origin}/auth/callback?redirect=${encodeURIComponent(redirectTo)}`,
      },
    });
    if (error) setError(error.message);
  }

  return (
    <main>
      <h1>Sign in to Wavelet</h1>
      <p>
        Wavelet uses Sign in with Apple — the same account the iPhone app uses.
        There is no password to create or leak.
      </p>
      <div className="actions">
        <button className="primary" onClick={signIn}>
          Sign in with Apple
        </button>
      </div>
      {error && <p style={{ color: "#d1444a" }}>{error}</p>}
    </main>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<main><h1>Sign in to Wavelet</h1></main>}>
      <LoginForm />
    </Suspense>
  );
}
