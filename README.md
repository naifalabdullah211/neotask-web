# NeoTask

Flutter client and Firebase backend for NeoTask.

## Security-sensitive deployment

The first manager is created by the `bootstrapManager` Cloud Function. Its
setup key must exist in Firebase Secret Manager and must never be stored in
Flutter, Hosting, Git, workflow variables, or a service-account file:

```bash
firebase functions:secrets:set MANAGER_SETUP_KEY --project neotask1-ff5a4
```

The production workflow intentionally deploys in this order:

1. Cloud Functions
2. Firestore Rules
3. Firebase Hosting

If the secret or Functions deployment is unavailable, the workflow stops
before publishing client code that depends on it.
