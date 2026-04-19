# Coverage Manager - Cloud Edition

This package converts the coverage tool into a free-hostable web app using:
- **GitHub Pages** for static hosting
- **Supabase** for database, authentication, audit logging, and finalized records

## Files included
- `index.html` - hosted front-end app
- `schema.sql` - Supabase database schema + RLS policies + triggers
- `README.md` - setup instructions

---

## What this version adds

### Auditability
- cloud-based storage in Supabase
- per-user sign-in
- audit log entries for create / generate / swap / manual assign / lock / remove / finalize / reopen / export
- timestamps on day and assignment records
- finalized-day snapshot for payroll recordkeeping

### Payroll / records
- CSV export
- printable finalized daily record
- totals by date
- totals by pay period
- coverage count by period
- coverage type summary
- unresolved NO SUB summary
- fairness review section

### Day-of operations
- principal dashboard with unfilled classes highlighted
- dean/office period-by-period view
- teacher notice view
- manual assignment / swap / lock / remove tools

---

## Supabase setup

### 1. Create a Supabase project
Create a new project in Supabase.

### 2. Run the SQL schema
Open the **SQL Editor** in Supabase and paste the contents of `schema.sql`.
Run the script.

### 3. Turn on email/password auth
Go to:
- **Authentication**
- **Providers**
- enable **Email** if it is not already enabled

You can create users through the app or directly in the Supabase dashboard.

### 4. Promote user roles
Every new user is created as `principal` by default in this version.
You can change roles manually with SQL, for example:

```sql
update public.profiles
set role = 'secretary'
where email = 'secretary@yourschool.org';
```

Allowed roles:
- `principal`
- `ap`
- `secretary`
- `dean`
- `viewer`

`viewer` can read data but should not be used for editing workflows.

---

## GitHub Pages setup

### 1. Create a GitHub repository
Example: `coverage-manager-cloud`

### 2. Upload the app files
Upload at minimum:
- `index.html`

You should still keep `schema.sql` and `README.md` in the repo for reference.

### 3. Publish with GitHub Pages
In the repo:
- **Settings**
- **Pages**
- choose the branch to publish from (usually `main`)
- save

GitHub will give you a public URL.

---

## Connect the app to Supabase
When the hosted page opens, enter:
- your **Supabase URL**
- your **Supabase anon public key**

Then click **Save Config**.

The app stores these values in the browser so you do not have to re-enter them each time on that device.

---

## First-use workflow

1. Open the hosted page
2. Paste Supabase URL + anon key
3. Sign in
4. Pick a date
5. Mark absent staff and exempt staff
6. Click **Generate / Add Missing Assignments**
7. Review manual changes if needed
8. Finalize the day
9. Export CSV for payroll
10. Print the finalized record to PDF if you need a PDF archive

---

## Important note about finalized days
This version blocks assignment edits after finalization.
If you need to change a finalized day:
1. click **Reopen Day**
2. make edits
3. finalize again

This gives you a cleaner audit trail.

---

## Security note
This app is much more auditable than localStorage, but you should still review whether your intended data belongs in a free public-hosted workflow.
Use care if you plan to store sensitive operational notes.

---

## Suggested next upgrades
If you want the tool to feel closer to a production school office system, the next upgrades should be:
- import teacher/staff roster from CSV
- custom schedule editor instead of hardcoded staff list
- approver signature field for finalized payroll
- PDF export with branded payroll layout
- archive page with all finalized days
- email notification for unresolved NO SUB incidents
- role-specific home screens for principal, AP, payroll secretary, dean
