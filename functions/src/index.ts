import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import * as crypto from 'crypto';
import AdmZip from 'adm-zip';
import { parse } from 'csv-parse/sync';

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
const storage = admin.storage();

// Callable: resolve BLE token -> masked identity + degree if allowed
export const resolveBleToken = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const token = (data?.token as string | undefined)?.trim();
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  if (!token) throw new functions.https.HttpsError('invalid-argument', 'token required');

  const tokenDoc = await db.collection('ble_tokens').doc(token).get();
  if (!tokenDoc.exists) return { allowed: false };
  const tokenData = tokenDoc.data() as any;
  const peerUid: string | undefined = tokenData.userId;
  const expireAt: admin.firestore.Timestamp | undefined = tokenData.expireAt;
  if (!peerUid) return { allowed: false };
  if (expireAt && expireAt.toDate() < new Date()) return { allowed: false };

  const edge = await db.collection('graph_edges').doc(`${uid}_${peerUid}`).get();
  const isFirstDegree = edge.exists;
  const isSecondDegree = false; // stub

  if (!isFirstDegree && !isSecondDegree) {
    return { allowed: false };
  }

  const profile = await db.collection('profiles').doc(peerUid).get();
  const name: string = (profile.data()?.name as string | undefined) ?? 'Putrace User';
  const initials = name
    .split(' ')
    .map((p) => p.trim()[0])
    .filter(Boolean)
    .join('')
    .slice(0, 2)
    .toUpperCase();

  return {
    allowed: true,
    peerUid,
    degree: isFirstDegree ? 'first' : 'second',
    display: `${initials} (${isFirstDegree ? '1st' : '2nd'})`,
  };
});

// Build graph from contact tokens: create 1st/2nd-degree connections
export const buildGraphFromTokens = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async () => {
    const now = new Date();
    const batch = db.batch();
    
    // Get all contact tokens
    const tokensSnap = await db.collection('contact_tokens').get();
    const tokensByUser = new Map<string, Set<string>>();
    
    // Group tokens by user
    tokensSnap.docs.forEach((doc) => {
      const data = doc.data();
      const userId = data.userId as string;
      const token = data.token as string;
      if (!tokensByUser.has(userId)) {
        tokensByUser.set(userId, new Set());
      }
      tokensByUser.get(userId)!.add(token);
    });
    
    // Find matches between users
    const processed = new Set<string>();
    for (const [userId1, tokens1] of tokensByUser.entries()) {
      for (const [userId2, tokens2] of tokensByUser.entries()) {
        if (userId1 === userId2) continue;
        
        const pairKey = [userId1, userId2].sort().join('_');
        if (processed.has(pairKey)) continue;
        processed.add(pairKey);
        
        // Check for token matches (shared contacts)
        const intersection = new Set([...tokens1].filter(x => tokens2.has(x)));
        if (intersection.size > 0) {
          // Create 1st-degree connection
          const edgeId = `${userId1}_${userId2}`;
          batch.set(db.collection('graph_edges').doc(edgeId), {
            ownerId: userId1,
            peerUid: userId2,
            degree: 1,
            sharedContacts: intersection.size,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          // Create reverse edge
          const reverseEdgeId = `${userId2}_${userId1}`;
          batch.set(db.collection('graph_edges').doc(reverseEdgeId), {
            ownerId: userId2,
            peerUid: userId1,
            degree: 1,
            sharedContacts: intersection.size,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }
    
    await batch.commit();
    console.log(`Built graph with ${processed.size} connections`);
    return null;
  });

// Precompute post audience: expand visibility/groupIds into allowedUserIds
export const precomputePostAudience = functions.firestore
  .document('posts/{postId}')
  .onWrite(async (change) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;
    const authorId = after.authorId as string;
    const visibility = after.visibility as string;
    const groupIds = (after.groupIds as string[] | undefined) ?? [];

    const allowed = new Set<string>();

    if (visibility === 'custom') {
      for (const gid of groupIds) {
        const g = await db
          .collection('audiences')
          .doc(authorId)
          .collection('groups')
          .doc(gid)
          .get();
        const members = ((g.data()?.memberUserIds as string[]) ?? []);
        members.forEach((u) => allowed.add(u));
      }
    }

    if (visibility === 'firstDegree' || visibility === 'secondDegree') {
      const edgesSnap = await db
        .collection('graph_edges')
        .where('ownerId', '==', authorId)
        .limit(1000)
        .get();
      edgesSnap.docs.forEach((d) => allowed.add((d.data().peerUid as string)));
      if (visibility === 'secondDegree') {
        const first = Array.from(allowed);
        for (const f of first) {
          const e2 = await db
            .collection('graph_edges')
            .where('ownerId', '==', f)
            .limit(200)
            .get();
          e2.docs.forEach((d) => allowed.add((d.data().peerUid as string)));
        }
      }
    }

    allowed.delete(authorId);

    await change.after.ref.set(
      { allowedUserIds: Array.from(allowed) },
      { merge: true }
    );
  });

// Overlap alerts: intelligent matching based on tags, time, and location
export const overlapAlerts = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap) => {
    const post = snap.data();
    const allowed: string[] = (post.allowedUserIds as string[] | undefined) ?? [];
    if (!allowed.length) return;

    const title = 'New plan from your network';
    const postBody = (post.text as string | undefined)?.slice(0, 80) ?? '';
    const tags = (post.tags as string[] | undefined) ?? [];
    const startAt = post.startAt?.toDate() as Date;
    const endAt = post.endAt?.toDate() as Date;

    // Find overlapping posts for better context
    const overlaps = await db.collection('posts')
      .where('authorId', 'in', allowed)
      .where('startAt', '<=', endAt)
      .where('endAt', '>=', startAt)
      .get();
    
    const tagMatches = overlaps.docs.filter(doc => {
      const postTags = doc.data().tags as string[] ?? [];
      return postTags.some(tag => tags.includes(tag));
    });

    let alertBody = postBody;
    if (tagMatches.length > 0) {
      alertBody += `\n\n🎯 ${tagMatches.length} similar plans found!`;
    }

    await Promise.all(
      allowed.map(async (userId) => {
        await db.collection('alerts').add({
          userId,
          title,
          body: alertBody,
          route: '/putrace/posts',
          postId: snap.id,
          type: 'new_post',
          hasOverlaps: tagMatches.length > 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        const tokensSnap = await db
          .collection('device_tokens')
          .where('userId', '==', userId)
          .limit(500)
          .get();
        const tokens = tokensSnap.docs.map((d) => (d.data().token as string));
        if (tokens.length) {
          await messaging.sendEachForMulticast({
            tokens,
            notification: { title, body: alertBody },
            data: { 
              route: '/putrace/posts',
              postId: snap.id,
              type: 'new_post'
            },
          });
        }
      })
    );
  });

// Availability alerts: notify eligible nearby 1st-degree contacts
export const availabilityAlerts = functions.firestore
  .document('availability/{userId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;
    
    const userId = context.params.userId as string;
    const open = after.open as boolean | undefined;
    if (!open) return;

    const audience = after.audience as string | undefined;
    const customGroupIds = (after.customGroupIds as string[] | undefined) ?? [];
    
    let eligibleUsers: string[] = [];
    
    if (audience === 'firstDegree' || audience === 'secondDegree') {
      const edgesSnap = await db
        .collection('graph_edges')
        .where('ownerId', '==', userId)
        .where('degree', '==', audience === 'firstDegree' ? 1 : 2)
        .limit(1000)
        .get();
      eligibleUsers = edgesSnap.docs.map((d) => (d.data().peerUid as string));
    } else if (audience === 'custom' && customGroupIds.length > 0) {
      const groupsSnap = await db
        .collection('audiences')
        .where('id', 'in', customGroupIds)
        .get();
      for (const group of groupsSnap.docs) {
        const members = (group.data().memberUserIds as string[] ?? []);
        eligibleUsers.push(...members);
      }
    }
    
    if (!eligibleUsers.length) return;

    const title = 'Contact is available to connect';
    let body = 'Someone in your network is nearby and open to connect';
    const until = after.until?.toDate() as Date | undefined;
    
    if (until) {
      body += ` until ${until.toLocaleTimeString()}`;
    }

    await Promise.all(
      eligibleUsers.map(async (peer) => {
        await db.collection('alerts').add({
          userId: peer,
          title,
          body,
          route: '/putrace/nearby',
          type: 'availability',
          sourceUserId: userId,
          expiresAt: until,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        const tokensSnap = await db
          .collection('device_tokens')
          .where('userId', '==', peer)
          .limit(500)
          .get();
        const tokens = tokensSnap.docs.map((d) => (d.data().token as string));
        if (tokens.length) {
          await messaging.sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: { 
              route: '/putrace/nearby',
              type: 'availability',
              sourceUserId: userId
            },
          });
        }
      })
    );
  });

// Callable function: parse LinkedIn GDPR CSV/ZIP uploads and write contact_tokens
export const linkedinCsvParser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { filePath, bucketName } = data;
  if (!filePath || !bucketName) {
    throw new functions.https.HttpsError('invalid-argument', 'filePath and bucketName are required');
  }
  
  const uid = context.auth.uid;
  const match = filePath.match(/^linkedin_uploads\/(.+?)\//);
  if (!match) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid file path format');
  }

  const bucket = storage.bucket(bucketName);
  const [buffer] = await bucket.file(filePath).download();

    let csvBuffers: Buffer[] = [];
    if (filePath.endsWith('.zip')) {
      const zip = new AdmZip(buffer);
      const entries = zip.getEntries();
      for (const e of entries) {
        if (/Connections\.csv$/i.test(e.entryName)) {
          csvBuffers.push(e.getData());
        }
      }
    } else if (filePath.endsWith('.csv')) {
      csvBuffers.push(buffer);
    }

    if (!csvBuffers.length) return;

    const tokensBatch: { email?: string; phone?: string }[] = [];

    for (const b of csvBuffers) {
      const rows = parse(b, { columns: true, skip_empty_lines: true });
      for (const row of rows) {
        const email = (row['Email Address'] || row['Email'] || '').toString().trim().toLowerCase();
        const phone = (row['Phone Number'] || '').toString().trim();
        tokensBatch.push({ email: email || undefined, phone: phone || undefined });
      }
    }

    const hmac = (value: string) =>
      crypto.createHmac('sha256', uid).update(value).digest('hex');

    const writes: Promise<any>[] = [];
    for (const t of tokensBatch) {
      if (t.email) {
        const token = hmac(`email:${t.email}`);
        writes.push(
          db.collection('contact_tokens').doc(`${uid}_em_${token}`).set({
            userId: uid,
            kind: 'email',
            token,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true })
        );
      }
      if (t.phone) {
        const token = hmac(`phone:${t.phone}`);
        writes.push(
          db.collection('contact_tokens').doc(`${uid}_ph_${token}`).set({
            userId: uid,
            kind: 'phone',
            token,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true })
        );
      }
    }

    await Promise.all(writes);

    // Optional: delete uploaded file after parsing
    await bucket.file(filePath).delete({ ignoreNotFound: true });
  });

// Scheduled cleanup: remove expired presence, BLE tokens, and old data
export const cleanupEphemeral = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const now = new Date();
    const batch = db.batch();
    
    // Clean up expired presence
    const presence = await db.collection('presence_geo')
      .where('expireAt', '<', now)
      .limit(500)
      .get();
    presence.docs.forEach((d) => batch.delete(d.ref));

    // Clean up expired BLE tokens
    const ble = await db.collection('ble_tokens')
      .where('expireAt', '<', now)
      .limit(500)
      .get();
    ble.docs.forEach((d) => batch.delete(d.ref));

    // Clean up old alerts (older than 30 days)
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const oldAlerts = await db.collection('alerts')
      .where('createdAt', '<', thirtyDaysAgo)
      .limit(500)
      .get();
    oldAlerts.docs.forEach((d) => batch.delete(d.ref));

    // Clean up expired availability statuses
    const expiredAvailability = await db.collection('availability')
      .where('until', '<', now)
      .limit(500)
      .get();
    expiredAvailability.docs.forEach((d) => {
      batch.update(d.ref, { open: false, until: null });
    });

    await batch.commit();
    console.log(`Cleaned up ${presence.docs.length + ble.docs.length + oldAlerts.docs.length} expired items`);
    return null;
  });
