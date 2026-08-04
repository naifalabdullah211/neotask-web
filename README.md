# NeoTask

Flutter client and Firebase backend for NeoTask.

## Spark-plan deployment

Production stays on Firebase's no-cost Spark plan and does not deploy Cloud
Functions or use Secret Manager. The first-manager setup key is stored only as
an encrypted workflow artifact. During deployment, GitHub Actions decrypts it
in runner memory, writes only its SHA-256 digest to the hidden one-time
`system/manager_bootstrap` document, and deletes the plaintext temporary file.

The manager setup screen hashes the entered key locally. Firestore Rules allow
the manager profile only when one atomic transaction creates the manager lock
and consumes the hidden digest. The plaintext key is never committed, hosted,
or stored in Firestore.

The production workflow deploys in this order:

1. One-time manager setup proof (only while no manager lock exists)
2. Firestore Rules
3. Firebase Hosting

The optional functions in `functions/` are retained for a possible future
Blaze-plan upgrade, but they are not part of the Spark production release.
