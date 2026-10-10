# DailyBudget — Personal Finance Tracker

A responsive, single-file frontend for manual personal-finance tracking, hosted on GitHub Pages, with Supabase Auth and PostgreSQL as the private data backend.

## Included files

- `index.html` — all app HTML, CSS, and application JavaScript in one file; Supabase JS and Chart.js are loaded from CDNs.
- `supabase_setup.sql` — tables, constraints, indexes, signup defaults, and row-level security (RLS) policies.
- `.gitignore` — common local/editor files excluded from Git.

## Current feature set

- Email/password signup, sign-in, sign-out, and password-reset email flow (requires Supabase Auth configuration).
- Dashboard cards for balance, today’s income/expenses, daily budget remaining, monthly income/expenses, recent transactions, category spending, and upcoming bills.
- Transaction create/edit/delete, search, category/type filters, and date-range filters.
- Daily budget and spending threshold indicators.
- Monthly category budgets and usage indicators.
- Bills with due dates, recurrence labels, overdue/upcoming/paid status, and explicit manual “mark paid” behavior.
- Savings goals with progress.
- Reports with charts, essential/non-essential comparison, data-based insights, and CSV exports.
- Currency preferences, light/dark theme, and export/delete-data controls.
- Responsive layout for desktop and mobile.

## Important limitations (read before using)

This is a functional starter application, not a financial institution or audited production product. The app requires your own Supabase project before authentication and data features work. It does not include bank connections, automatic bill scheduling, push notifications, multi-currency conversion, automated rollover math, or bank-verified balances. The rollover switch currently saves the preference but does not change the daily-limit calculation. Recurrence is stored as a bill attribute; the app does not auto-generate future bill instances or expenses. Marking a bill paid does not create a transaction. A credit card purchase and card repayment can still be double-counted if you enter both as expenses; enter the purchase as the expense and use notes or another workflow for repayment tracking.

The frontend’s account “Delete all app records” action deletes the user's budgeting records but does not delete the Supabase Auth identity. Auth user deletion requires a trusted server-side Admin API operation or a carefully designed Edge Function with strict authorization. Never put a Supabase service-role key in `index.html`.

The app has not been run against your Supabase project because no project credentials were provided. Verify the SQL and major flows in a test project before relying on it for personal financial records.

## 1. Create and configure Supabase

1. Create a project at [Supabase](https://supabase.com/).
2. Open **SQL Editor**, paste and run all of `supabase_setup.sql`.
3. Open **Project Settings → API** (or the API Keys page) and copy:
   - Project URL, e.g. `https://abcdefgh.supabase.co`
   - Publishable key (preferred) or legacy `anon` key.
4. Edit the two constants near the top of `index.html`:
   ```js
   const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY';
   ```
   Replace the placeholders with your project's real URL and public key. These are intended for browser use. **Never** use a `service_role` key or database password here.
5. In Supabase **Authentication → URL Configuration**, set the Site URL to your deployed GitHub Pages URL, for example `https://YOUR_GITHUB_NAME.github.io/YOUR_REPOSITORY/`. Add that URL to Redirect URLs. During local testing, also add the local URL you use.
6. In **Authentication → Providers**, ensure Email auth is enabled. Configure email verification and SMTP as appropriate. Supabase's default email service may be rate-limited.

## 2. Publish to GitHub Pages

No npm, Node, or build step is required.

1. Create a new GitHub repository.
2. Upload `index.html`, `supabase_setup.sql`, `README.md`, and `.gitignore` to the repository root.
3. Open **Settings → Pages**.
4. Choose **Deploy from a branch**, select your default branch and `/ (root)`, then Save.
5. Wait for the published URL and use that exact URL in Supabase Auth's Site URL and Redirect URLs.
6. Visit the site, create an account, and verify your email if enabled.

GitHub Pages is public hosting. Anyone can view the frontend source and see the Supabase URL and public/publishable key. That is expected; privacy comes from Supabase Auth and correctly enforced RLS policies, not from hiding the frontend. Do not commit secrets.

## 3. Run locally without a build

You can open `index.html` directly for basic inspection, but authentication redirects and browser security rules are best tested from a local static server or the GitHub Pages URL. A static server is optional and does not require a build. If testing from localhost, add that exact origin/redirect URL in Supabase.

## 4. Data security model

- Each data row is linked to `auth.users(id)` through `user_id`, with cascade deletion if the auth user is deleted.
- RLS is enabled on every user-specific table.
- Select/update/delete policies restrict access to `auth.uid()`. Insert and update checks also require the authenticated user to own the row, preventing changing `user_id` to another user.
- No anonymous policies are created.
- Browser access uses only a publishable/anon key; that key is not a secret.
- User-entered text is escaped before being rendered as HTML.
- CSV export quotes cells and neutralizes formula-leading values.
- Do not store bank passwords, full payment-card numbers, or financial account credentials.
- This app does not send transaction information to AI services.

For a public release, also configure strong account/password policy, email delivery, abuse protection, backups, monitoring that avoids logging sensitive values, and a privacy policy. Consider independent security review before inviting public users.

## 5. Backup and export

From **Settings → Export all**, download CSV files for transactions, budgets, bills, and savings goals. CSV export is useful for personal backups, but it is not a full database backup and does not include authentication accounts or every preference. Store exports somewhere private and encrypted.

For a full backend backup, use Supabase's database backup/PITR features available for your plan, or securely export the database from an authorized admin environment. Never put database credentials in the public repository.

## 6. Account deletion

The in-app “Delete all app records” action removes rows from the budgeting tables for the signed-in user. It intentionally does not delete the Auth identity. To support complete account deletion, add a server-side Supabase Edge Function that validates the caller's JWT, requires a clear confirmation, and uses a server-side secret to delete only that caller's Auth user. Keep the secret in Edge Function secrets, never in the browser. Test deletion and retention requirements before launch.

## 7. Testing checklist

Use a fresh test project and two separate accounts:

- [ ] Sign up, verify email (if enabled), sign in, reset password, sign out.
- [ ] Add/edit/delete income and expense records; test invalid and zero amounts.
- [ ] Check today/month calculations with transactions on different dates.
- [ ] Add monthly category budgets and verify usage and duplicate prevention.
- [ ] Add bills, mark paid, and confirm no duplicate transaction is created.
- [ ] Add and edit savings goals.
- [ ] Confirm charts and CSV export use only the current user's records.
- [ ] Sign in as account B and verify account A's records are never visible.
- [ ] Attempt direct API requests as anon and as a different authenticated user; verify RLS denies access.
- [ ] Test mobile layouts, dark mode, empty states, and data export.
- [ ] Verify SQL grants and RLS after any schema changes.

## Troubleshooting

- **“Setup needed”**: replace the two constants in `index.html`.
- **Data load fails**: run the SQL file, check Supabase project URL/key, and inspect browser console for schema or RLS errors.
- **Signup does not log in automatically**: expected when email verification is enabled; verify the email and then sign in.
- **Email redirect fails**: add the exact deployed URL under Supabase Auth Redirect URLs.
- **No chart appears**: confirm CDN access is available and inspect browser console.
