/**
 * Verifies OAuth 2.1 access tokens issued by Supabase Auth.
 *
 * Supabase acts as the authorization server, so the MCP server needs no
 * identity system of its own: the token's `sub` is the Supabase `auth.uid()`,
 * which is exactly the `user_id` every row is keyed by.
 *
 * Three checks matter, and skipping any of them breaks the trust boundary:
 *   1. Signature, against the project's published JWKS (ES256).
 *   2. Issuer, pinned to this project — a valid token from a *different*
 *      Supabase project must not be accepted.
 *   3. Audience, pinned to this resource. Without it, a token minted for some
 *      other service could be replayed here: the confused-deputy problem
 *      RFC 8707 resource binding exists to prevent.
 */

import { createRemoteJWKSet, jwtVerify, type JWTPayload } from "jose";
import type { AuthInfo } from "@modelcontextprotocol/sdk/server/auth/types.js";
import type { OAuthTokenVerifier } from "@modelcontextprotocol/sdk/server/auth/provider.js";
import { InvalidTokenError } from "@modelcontextprotocol/sdk/server/auth/errors.js";

export interface SupabaseVerifierOptions {
  /** e.g. https://<ref>.supabase.co */
  supabaseUrl: string;
  /** Canonical URL of this MCP resource, used as the expected audience. */
  resourceUrl: string;
  /**
   * Override when the authorization server does not mint resource-bound
   * audiences. Weakens isolation to "any token from this project", so it is
   * only defensible on a single-purpose project.
   */
  expectedAudience?: string;
}

export class SupabaseTokenVerifier implements OAuthTokenVerifier {
  private readonly jwks: ReturnType<typeof createRemoteJWKSet>;
  private readonly issuer: string;
  private readonly audience: string;

  constructor(opts: SupabaseVerifierOptions) {
    const base = opts.supabaseUrl.replace(/\/+$/, "");
    this.issuer = `${base}/auth/v1`;
    this.audience = opts.expectedAudience ?? opts.resourceUrl;
    this.jwks = createRemoteJWKSet(
      new URL(`${base}/auth/v1/.well-known/jwks.json`),
    );
  }

  async verifyAccessToken(token: string): Promise<AuthInfo> {
    let payload: JWTPayload;
    try {
      ({ payload } = await jwtVerify(token, this.jwks, {
        issuer: this.issuer,
        audience: this.audience,
      }));
    } catch (cause) {
      // Every rejection reason — bad signature, wrong issuer, wrong audience,
      // expired, malformed — must surface as InvalidTokenError so the client
      // gets a 401 with WWW-Authenticate and starts the OAuth flow. A 500 here
      // would leave ChatGPT and Claude stuck with no way to recover.
      throw new InvalidTokenError(
        cause instanceof Error ? cause.message : "Token verification failed",
      );
    }

    const userId = payload.sub;
    if (!userId) {
      throw new InvalidTokenError("Token has no subject; cannot scope health data.");
    }

    return {
      token,
      clientId: stringClaim(payload, "client_id") ?? "unknown",
      scopes: parseScopes(payload),
      expiresAt: payload.exp,
      extra: { userId },
    };
  }
}

function stringClaim(payload: JWTPayload, key: string): string | undefined {
  const value = payload[key];
  return typeof value === "string" ? value : undefined;
}

function parseScopes(payload: JWTPayload): string[] {
  const scope = payload.scope;
  if (typeof scope === "string") return scope.split(" ").filter(Boolean);
  if (Array.isArray(scope)) return scope.filter((s): s is string => typeof s === "string");
  return [];
}
