# Cloud Functions (stubs)

Planned functions (Node 20):

- overlapAlerts (onPostWrite): Firestore trigger on `posts/{postId}` create/update.
  - Read window, tags, visibility; precompute `allowedUserIds`.
  - Create `alerts` docs `{ userId, title, body, createdAt }`.
  - Send FCM to tokens in `device_tokens`.

- availabilityAlerts (onAvailabilityWrite): Firestore trigger on `availability/{userId}` write.
  - Find nearby via `presence_geo` geohash prefix + TTL; filter by audience.
  - Create alerts + send FCM.

- linkedinCsvParser (onCsvUpload): Storage trigger on `linkedin_uploads/{uid}/{file}` finalize.
  - If ZIP, extract; find CSV; parse; tokenize emails/phones with server HMAC; write `contact_tokens`.
  - Cleanup temp files.

Setup:
- Run `firebase init functions` in this folder.
- Use Node.js 20 runtime.
- Add server-side HMAC secret (per-user salt via Secret Manager) for tokenization.

Additional endpoint:
- resolveBleToken (callable): input `{ token }` → output `{ allowed, display, degree, peerUid? }`
