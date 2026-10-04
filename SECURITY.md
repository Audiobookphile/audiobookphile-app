# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by opening a [GitHub Security Advisory](https://github.com/Audiobookphile/audiobookphile-app/security/advisories/new) or by emailing the maintainer directly. All reports will be reviewed promptly.

Please include the following in your report:

- Type of issue (e.g., XSS, SQL injection, authentication bypass, insecure direct object reference)
- The affected file, component, or endpoint
- Step-by-step instructions to reproduce the issue
- Potential impact of the vulnerability

## Supported Versions

Security updates are provided for the latest stable version only.

## Scope

This repository covers the Next.js frontend client. The Supabase backend (database, auth, storage) is managed separately. For Supabase-specific security concerns, refer to the [Supabase security documentation](https://supabase.com/docs/guides/platform/security).

### Key Security Boundaries

- `SUPABASE_SERVICE_ROLE_KEY` is used server-side only (Route Handlers and Server Actions). It is never exposed to the browser or included in the client bundle.
- Row Level Security (RLS) is enabled on all Supabase tables. Application-layer checks are a secondary defence.
- Audio files are stored in a private Supabase Storage bucket and accessed only via time-limited signed URLs generated server-side.
- OAuth callbacks are handled via `src/app/auth/callback/route.ts` using `supabase.auth.exchangeCodeForSession()`.

## Acknowledgements

We appreciate the work of security researchers who help keep this project and its users safe.
