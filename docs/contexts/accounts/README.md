# Context: Accounts

> The Accounts context handles user identity, authentication, and session management. It is the entry point for all users into the system — registration, login (via magic link), email management, and GDPR compliance (data export and account anonymization). Other contexts depend on Accounts to know *who* a user is, but not *what role* they play.

## What This Context Owns

- **Domain Concepts:** User (identity + credentials), Scope (caller context with resolved roles), UserRole (parent / provider), UserToken (session, magic link, email change tokens)
- **Data:** `users` table, `users_tokens` table
- **Processes:** Registration, magic link login, email change confirmation, password management, session lifecycle, GDPR data export, GDPR account anonymization

## Key Features

| Feature | Status | Doc |
|---|---|---|
| User Registration | Active | — |
| Magic Link Login | Active | — |
| Email Change | Active | — |
| Password Management | Active | — |
| Locale Preferences | Active | — |
| Sudo Mode | Active | — |
| GDPR Data Export | Active | — |
| GDPR Account Anonymization | Active | — |
| Role Resolution (Scope) | Active | — |
| Permission Enforcement | Planned | — |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Family | `Family.get_parent_by_identity/1` | Called during scope role resolution to check if user has a parent profile |
| Provider | `Provider.get_provider_by_identity/1` | Called during scope role resolution to check if user has a provider profile |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Family, Provider | `user_registered` integration event | Signals that a new user exists; downstream contexts create profiles based on `intended_roles` |
| Family, Provider, Messaging | `user_anonymized` integration event | Signals GDPR deletion; downstream contexts anonymize their own data |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| User | A person with an email and credentials who can log in to the platform |
| Scope | The caller's identity and resolved roles, passed through the app as `@current_scope` |
| Intended Roles | The role(s) a user selects at registration (parent, provider, or both) — determines which profiles are created downstream |
| Magic Link | A time-limited login URL sent to the user's email (expires in 15 minutes) |
| Sudo Mode | A security window (20 minutes after last authentication) required for sensitive operations like password change or account deletion |
| Anonymization | GDPR-compliant replacement of all personal data with placeholder values (`deleted_<id>@anonymized.local`, `"Deleted User"`) |
| Token | A cryptographic artifact for session persistence, magic link verification, or email change confirmation |

## Business Decisions

- **Passwordless-first authentication.** Users register with name + email + role selection. No password is set at registration. Login is via magic link.
- **Passwords are optional.** Users can set a password later in settings, but the primary auth flow is magic link.
- **Magic link tokens expire in 15 minutes.** Session tokens expire in 14 days. Email change tokens expire in 7 days.
- **Sudo mode gates destructive operations.** Password changes and account deletion require recent authentication (within 20 minutes).
- **Account deletion is anonymization, not hard delete.** PII is replaced with placeholder values. Timestamps and non-PII data are preserved for data integrity.
- **Anonymization cascades via events.** The `user_anonymized` integration event triggers downstream contexts to anonymize their own data asynchronously.
- **Roles are resolved at login, not stored on the user.** The Scope struct checks Family and Provider contexts for profile existence to determine active roles.
- **Default role is `:parent`.** If no role is selected during registration, the user is assigned the parent role.
- **Registration requires at least one role.** Users must select parent, provider, or both.
- **Sensitive fields are redacted.** The User schema implements a custom `Inspect` protocol that hides email, name, password, and hashed_password from logs and exceptions.
- **Supported locales: `en` and `de`.**

## Assumptions & Open Questions

- [NEEDS INPUT] How should the system handle a user who selected "provider" at registration but never completes provider onboarding? Is the `intended_roles` field a permanent record or should it evolve?
- [NEEDS INPUT] Should magic link emails be rate-limited? No rate limiting is currently implemented at the context level.
- [NEEDS INPUT] Should the `user_confirmed` and `user_email_changed` domain events also be promoted to integration events? Currently only `user_registered` and `user_anonymized` are published cross-context.

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
