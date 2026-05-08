# Bootstrap & maintenance scripts

These scripts use the Firebase Admin SDK against a service-account credential.
Both expect `GOOGLE_APPLICATION_CREDENTIALS` and `FIREBASE_PROJECT_ID` in the
environment. Get a service-account key from
**Firebase Console → Project Settings → Service accounts → Generate new private
key** (do NOT commit it).

```bash
cd scripts
npm install
```

## Seed the first super-admin (bootstrap a fresh project)

After deploying the rules + functions to a fresh project, the `users`
collection is empty and nobody can sign in via the app. Run:

```bash
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
FIREBASE_PROJECT_ID=alrasikhoon-57151 \
SUPER_ADMIN_USERNAME=admin \
SUPER_ADMIN_PASSWORD='change-me-now' \
SUPER_ADMIN_NAME='مدير النظام' \
npm run seed-super-admin
```

The super-admin can then sign in via the login screen with the given
username and password, and create teachers from the admin panel.

## Wipe users (destructive)

Clears the `/users` Firestore collection AND the Firebase Auth user pool.
Refuses to touch production unless explicitly opted in.

```bash
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
FIREBASE_PROJECT_ID=alrasikhoon-dev \
npm run wipe-users -- --confirm

# Production (rare — only when intentionally re-provisioning):
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
FIREBASE_PROJECT_ID=alrasikhoon-57151 \
npm run wipe-users -- --confirm --i-know-what-im-doing
```
