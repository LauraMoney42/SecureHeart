import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Types
interface EmergencyNotificationData {
  emergencyEventID: string;
  userID: string;
  userFirstName: string;
  heartRate: number;
  severity: 'critical' | 'high' | 'moderate';
  linkedContactTokens: string[]; // FCM tokens of linked contacts
  timestamp: number;
  location?: {
    latitude: number;
    longitude: number;
  };
  shareLocation: boolean;
}

interface ContactLinkRequest {
  type: 'contact_link_request';
  inviterUserID: string;
  inviterFirstName: string;
  invitationCode: string;
  timestamp: number;
}

interface LinkedContact {
  contactUserID: string;
  contactFirstName: string;
  fcmToken: string;
  linkedAt: number;
  shareLocationWithMe: boolean;
  shareMyLocationWithThem: boolean;
}

// MARK: - Emergency Notification Handler (Firebase Push Only)

export const processEmergencyNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data() as EmergencyNotificationData;
    const notificationId = context.params.notificationId;

    console.log(`🚨 Processing emergency notification: ${notificationId}`);
    console.log(`${data.userFirstName} - Heart Rate: ${data.heartRate}, Severity: ${data.severity}`);

    try {
      // Get linked contacts for this user
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(data.userID)
        .get();

      if (!userDoc.exists) {
        throw new Error(`User ${data.userID} not found`);
      }

      const userData = userDoc.data();
      const linkedContacts = userData?.linkedContacts as LinkedContact[] || [];

      console.log(`Found ${linkedContacts.length} linked contacts to notify`);

      // Send push notifications to all linked contacts
      const notificationPromises = linkedContacts.map(contact =>
        sendEmergencyPushNotification(contact, data, notificationId)
      );

      const results = await Promise.allSettled(notificationPromises);

      // Track results
      const notificationStatus: { [key: string]: string } = {};
      results.forEach((result, index) => {
        const contactId = linkedContacts[index].contactUserID;
        if (result.status === 'fulfilled') {
          notificationStatus[contactId] = 'sent';
        } else {
          notificationStatus[contactId] = 'failed';
          console.error(`Failed to notify ${contactId}:`, result.reason);
        }
      });

      // Create emergency event record
      await admin.firestore()
        .collection('emergencyEvents')
        .doc(data.emergencyEventID)
        .set({
          id: data.emergencyEventID,
          userID: data.userID,
          userFirstName: data.userFirstName,
          heartRate: data.heartRate,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          location: data.shareLocation && data.location ? data.location : null,
          contactsNotified: linkedContacts.map(c => c.contactUserID),
          notificationStatus,
          severity: data.severity,
          resolved: false,
          resolvedAt: null
        });

      // Mark notification as processed
      await snapshot.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        results: notificationStatus
      });

      console.log(`✅ Emergency notification ${notificationId} processed successfully`);

    } catch (error) {
      console.error(`❌ Error processing emergency notification ${notificationId}:`, error);

      await snapshot.ref.update({
        processed: false,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });

async function sendEmergencyPushNotification(
  contact: LinkedContact,
  emergencyData: EmergencyNotificationData,
  notificationId: string
): Promise<void> {

  if (!contact.fcmToken) {
    throw new Error(`No FCM token for contact ${contact.contactFirstName}`);
  }

  // Create location text if sharing is enabled
  let locationText = '';
  if (emergencyData.shareLocation && contact.shareLocationWithMe && emergencyData.location) {
    locationText = `\nLocation: ${emergencyData.location.latitude.toFixed(6)}, ${emergencyData.location.longitude.toFixed(6)}`;
  }

  // Generate severity-appropriate message
  const severityEmoji = emergencyData.severity === 'critical' ? '🚨' :
                       emergencyData.severity === 'high' ? '⚠️' : '💛';

  const title = `${severityEmoji} SecureHeart Emergency Alert`;
  const body = `${emergencyData.userFirstName} is experiencing a heart rate emergency: ${emergencyData.heartRate} BPM${locationText}`;

  const payload = {
    notification: {
      title,
      body,
      sound: 'default'
    },
    data: {
      type: 'emergency_alert',
      emergencyEventID: emergencyData.emergencyEventID,
      userID: emergencyData.userID,
      userFirstName: emergencyData.userFirstName,
      heartRate: emergencyData.heartRate.toString(),
      severity: emergencyData.severity,
      timestamp: emergencyData.timestamp.toString(),
      hasLocation: (emergencyData.shareLocation && contact.shareLocationWithMe && emergencyData.location) ? 'true' : 'false',
      latitude: emergencyData.location?.latitude?.toString() || '',
      longitude: emergencyData.location?.longitude?.toString() || ''
    },
    token: contact.fcmToken,
    android: {
      priority: 'high' as const,
      notification: {
        channel_id: 'emergency_alerts',
        priority: 'high' as const
      }
    },
    apns: {
      headers: {
        'apns-priority': '10'
      },
      payload: {
        aps: {
          alert: {
            title,
            body
          },
          sound: 'default',
          badge: 1,
          category: 'EMERGENCY_ALERT'
        }
      }
    }
  };

  await admin.messaging().send(payload);
  console.log(`📱 Emergency push notification sent to ${contact.contactFirstName}`);
}

// MARK: - Contact Linking System

export const processContactLinkRequest = functions.firestore
  .document('linkRequests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data() as ContactLinkRequest;
    const requestId = context.params.requestId;

    console.log(`🔗 Processing contact link request: ${requestId}`);

    try {
      // Store the link request with expiration (24 hours)
      const expirationTime = new Date();
      expirationTime.setHours(expirationTime.getHours() + 24);

      await admin.firestore()
        .collection('pendingLinks')
        .doc(data.invitationCode)
        .set({
          inviterUserID: data.inviterUserID,
          inviterFirstName: data.inviterFirstName,
          invitationCode: data.invitationCode,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(expirationTime),
          used: false
        });

      // Mark request as processed
      await snapshot.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`✅ Contact link request ${requestId} processed - Code: ${data.invitationCode}`);

    } catch (error) {
      console.error(`❌ Error processing contact link request ${requestId}:`, error);

      await snapshot.ref.update({
        processed: false,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });

// MARK: - Link Contacts Function

export const linkContacts = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { invitationCode, contactFirstName, contactFCMToken } = data;
  const contactUserID = context.auth.uid;

  try {
    // Verify invitation code
    const pendingLinkDoc = await admin.firestore()
      .collection('pendingLinks')
      .doc(invitationCode)
      .get();

    if (!pendingLinkDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Invalid invitation code');
    }

    const linkData = pendingLinkDoc.data();
    if (!linkData || linkData.used || linkData.expiresAt.toDate() < new Date()) {
      throw new functions.https.HttpsError('failed-precondition', 'Invitation code has expired or been used');
    }

    const inviterUserID = linkData.inviterUserID;
    const inviterFirstName = linkData.inviterFirstName;

    // Create linked contact relationship (bidirectional)
    const batch = admin.firestore().batch();

    // Add contact to inviter's linked contacts
    const inviterDoc = admin.firestore().collection('users').doc(inviterUserID);
    batch.update(inviterDoc, {
      [`linkedContacts.${contactUserID}`]: {
        contactUserID,
        contactFirstName,
        fcmToken: contactFCMToken,
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
        shareLocationWithMe: false, // Default - user can change in settings
        shareMyLocationWithThem: false // Default - user can change in settings
      }
    });

    // Add inviter to contact's linked contacts
    const contactDoc = admin.firestore().collection('users').doc(contactUserID);
    batch.update(contactDoc, {
      [`linkedContacts.${inviterUserID}`]: {
        contactUserID: inviterUserID,
        contactFirstName: inviterFirstName,
        fcmToken: '', // Will be updated when inviter's FCM token changes
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
        shareLocationWithMe: false, // Default - user can change in settings
        shareMyLocationWithThem: false // Default - user can change in settings
      }
    });

    // Mark invitation as used
    batch.update(pendingLinkDoc.ref, { used: true });

    await batch.commit();

    console.log(`✅ Successfully linked ${contactFirstName} (${contactUserID}) with ${inviterFirstName} (${inviterUserID})`);

    return {
      success: true,
      linkedWith: inviterFirstName,
      message: `You're now linked with ${inviterFirstName} for emergency alerts`
    };

  } catch (error) {
    console.error('❌ Error linking contacts:', error);
    throw error;
  }
});

// MARK: - Cleanup Functions

export const cleanupExpiredLinks = functions.pubsub
  .schedule('0 */6 * * *') // Run every 6 hours
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of expired invitation links');

    const now = admin.firestore.Timestamp.now();
    const expiredLinks = await admin.firestore()
      .collection('pendingLinks')
      .where('expiresAt', '<', now)
      .get();

    const batch = admin.firestore().batch();
    expiredLinks.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`✅ Cleaned up ${expiredLinks.docs.length} expired invitation links`);

    return null;
  });

export const cleanupOldNotifications = functions.pubsub
  .schedule('0 2 * * *') // Run daily at 2 AM
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of old notifications');

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const oldNotifications = await admin.firestore()
      .collection('notifications')
      .where('processedAt', '<', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .where('processed', '==', true)
      .get();

    const batch = admin.firestore().batch();
    oldNotifications.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`✅ Cleaned up ${oldNotifications.docs.length} old notifications`);

    return null;
  });