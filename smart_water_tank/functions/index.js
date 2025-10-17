// functions/index.js

const {onValueUpdated} = require("firebase-functions/v2/database");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const moment = require("moment-timezone");
const {onCall, onRequest, https} = require("firebase-functions/v2/https");
const crypto = require("crypto");
const {setGlobalOptions} = require("firebase-functions/v2");

setGlobalOptions({ region: "us-central1" });

admin.initializeApp();
const firestore = admin.firestore();

// --- FUNCTION 1: UPDATED with notification preference check ---
exports.levelChangeNotifier = onValueUpdated("/tanks/{userId}/live_data/water_level", async (event) => {
  const userId = event.params.userId;

  // ✅ START: ADDED NOTIFICATION PREFERENCE CHECK
  const settingsRef = admin.database().ref(`/tanks/${userId}/settings/notifications_enabled`);
  const settingsSnapshot = await settingsRef.once("value");
  // If the value is false or doesn't exist, stop the function.
  if (settingsSnapshot.val() !== true) {
    console.log(`Notifications are disabled for user ${userId}. Exiting.`);
    return null;
  }
  // ✅ END: ADDED NOTIFICATION PREFERENCE CHECK

  const levelBefore = event.data.before.val();
  const levelAfter = event.data.after.val();
  if (levelBefore === levelAfter) { return null; }
  const autoModeSnapshot = await admin.database().ref(`/tanks/${userId}/controls/auto_mode`).once("value");
  const isAutoMode = autoModeSnapshot.val();
  const flagsRef = admin.database().ref(`tanks/${userId}/notification_flags`);
  const flagsSnapshot = await flagsRef.once("value");
  const flags = flagsSnapshot.val() || {};
  let { loggedFull = false, loggedEmpty = false } = flags;
  let notificationTitle = null;
  let notificationBody = null;
  if (levelAfter >= 100 && !loggedFull) {
    notificationTitle = "Tank is Full!";
    notificationBody = isAutoMode ? "The tank is full and the motor has been stopped automatically." : "The tank is full! Please turn OFF the motor.";
    loggedFull = true;
  }
  if (levelAfter <= 5 && !loggedEmpty) {
    notificationTitle = "Tank is Almost Empty!";
    notificationBody = isAutoMode ? `The water level is low at ${levelAfter}%. The motor has been started automatically.` : `The water level is low at ${levelAfter}%. Please turn ON the motor.`;
    loggedEmpty = true;
  }
  if (levelAfter < 95) loggedFull = false;
  if (levelAfter > 10) loggedEmpty = false;
  await flagsRef.set({ loggedFull, loggedEmpty });

  if (notificationTitle) {
    const tokensSnapshot = await admin.database().ref(`/tanks/${userId}/fcm_tokens`).once("value");
    if (!tokensSnapshot.exists()) {
      console.log("No FCM tokens found.");
      return null;
    }
    const tokens = Object.keys(tokensSnapshot.val());
    if (tokens.length === 0) {
      console.log("Token array is empty.");
      return null;
    }
    const message = {
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      tokens: tokens,
    };
    try {
      console.log("Attempting to send message with sendEachForMulticast...");
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log("✅✅✅ Successfully sent message!", response);
    } catch (error) {
      console.error("CRITICAL ERROR sending FCM message:", error);
    }
  }
  return null;
});

// --- FUNCTION 2: UPDATED with notification preference check ---
exports.pumpStatusNotifier = onValueUpdated("/tanks/{userId}/controls/pump_status", async (event) => {
  const userId = event.params.userId;

  // ✅ START: ADDED NOTIFICATION PREFERENCE CHECK
  const settingsRef = admin.database().ref(`/tanks/${userId}/settings/notifications_enabled`);
  const settingsSnapshot = await settingsRef.once("value");
  // If the value is false or doesn't exist, stop the function.
  if (settingsSnapshot.val() !== true) {
    console.log(`Notifications are disabled for user ${userId}. Exiting.`);
    return null;
  }
  // ✅ END: ADDED NOTIFICATION PREFERENCE CHECK

  const pumpStatusAfter = event.data.after.val();
  const pumpStatusBefore = event.data.before.val();
  if (pumpStatusAfter === pumpStatusBefore) return null;
  const autoModeSnapshot = await admin.database().ref(`/tanks/${userId}/controls/auto_mode`).once("value");
  const isAutoMode = autoModeSnapshot.val();
  let notificationTitle = "Motor Status Update";
  let notificationBody = "";
  if (pumpStatusAfter === true) {
    notificationBody = isAutoMode ? "The motor has been started automatically due to low water level." : "The motor has been turned ON manually.";
  } else {
    notificationBody = isAutoMode ? "The motor has been stopped automatically because the tank is full." : "The motor has been turned OFF manually.";
  }

  const tokensSnapshot = await admin.database().ref(`/tanks/${userId}/fcm_tokens`).once("value");
  if (!tokensSnapshot.exists()) return null;
  const tokens = Object.keys(tokensSnapshot.val());
  if (tokens.length === 0) return null;
  const message = {
    notification: {
      title: notificationTitle,
      body: notificationBody,
    },
    tokens: tokens,
  };
  return admin.messaging().sendEachForMulticast(message);
});


// --- Other functions remain the same ---

// FUNCTION 3
exports.calculateDailyStats = onSchedule("every day 00:01", async (event) => {
  const timezone = "Asia/Kolkata";
  const yesterday = moment().tz(timezone).subtract(1, 'days').format('YYYY-MM-DD');
  console.log(`Running daily statistics calculation for date: ${yesterday}`);
  const tanksRef = admin.database().ref('/tanks');
  const allTanksSnapshot = await tanksRef.once('value');
  if (!allTanksSnapshot.exists()) {
    console.log("No tanks found in the database. Exiting.");
    return null;
  }
  const allTanks = allTanksSnapshot.val();
  const userIds = Object.keys(allTanks);
  const promises = [];
  for (const userId of userIds) {
    const historyRef = admin.database().ref(`/tanks/${userId}/history/${yesterday}`);
    const promise = historyRef.once('value').then(snapshot => {
      if (!snapshot.exists()) {
        console.log(`No history found for user ${userId} on ${yesterday}.`);
        return null;
      }
      const historyData = snapshot.val();
      let totalWaterConsumed = 0;
      let pumpOnCount = 0;
      let previousLevel = -1;
      let wasPumpOn = false;
      for (const timestampKey in historyData) {
        const entry = historyData[timestampKey];
        if (previousLevel !== -1 && entry.water_level < previousLevel) {
          totalWaterConsumed += (previousLevel - entry.water_level);
        }
        previousLevel = entry.water_level;
        if (entry.pump_status === true && !wasPumpOn) {
          pumpOnCount++;
        }
        wasPumpOn = entry.pump_status;
      }
      const dailyStats = {
        date: yesterday,
        totalWaterConsumed: totalWaterConsumed,
        pumpOnCount: pumpOnCount,
        lastUpdated: admin.database.ServerValue.TIMESTAMP
      };
      console.log(`Calculated stats for user ${userId}:`, dailyStats);
      const dailyStatsRef = admin.database().ref(`/tanks/${userId}/daily_stats/${yesterday}`);
      return dailyStatsRef.set(dailyStats);
    });
    promises.push(promise);
  }
  await Promise.all(promises);
  console.log("Finished daily statistics calculation for all users.");
  return null;
});

// FUNCTION 4
exports.registerDevice = onCall(async (request) => {
  if (!request.auth) {
    throw new https.HttpsError("unauthenticated", "You must be logged in to register a device.");
  }
  const uid = request.auth.uid;
  const hardwareId = request.data.hardwareId;
  if (!hardwareId) {
    throw new https.HttpsError("invalid-argument", "The function must be called with a 'hardwareId' argument.");
  }
  const apiKey = crypto.randomBytes(32).toString("hex");
  const deviceRef = firestore.collection("devices").doc(hardwareId);
  await deviceRef.set({
    uid: uid,
    apiKey: apiKey,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {apiKey: apiKey};
});

// FUNCTION 5
exports.getNewToken = onRequest(async (req, res) => {
  try {
    const apiKey = req.get("Authorization")?.split("Bearer ")[1];
    if (!apiKey) {
      res.status(401).send("Unauthorized: No API key provided.");
      return;
    }
    const devicesRef = firestore.collection("devices");
    const snapshot = await devicesRef.where("apiKey", "==", apiKey).limit(1).get();
    if (snapshot.empty) {
      res.status(403).send("Forbidden: Invalid API key.");
      return;
    }
    const deviceData = snapshot.docs[0].data();
    const uid = deviceData.uid;
    if (!uid) {
      res.status(500).send("Internal Server Error: UID is missing in database.");
      return;
    }
    const firebaseToken = await admin.auth().createCustomToken(uid);
    res.status(200).json({token: firebaseToken});
  } catch (error) {
    console.error("CRITICAL ERROR in getNewToken:", error);
    res.status(500).send("Internal Server Error.");
  }
});

// FUNCTION 6
exports.saveFCMToken = onCall(async (request) => {
  if (!request.auth) {
    throw new https.HttpsError("unauthenticated", "You must be logged in to save a token.");
  }
  const uid = request.auth.uid;
  const token = request.data.token;
  if (!token) {
    throw new https.HttpsError("invalid-argument", "The function must be called with a 'token' argument.");
  }
  const tokenRef = admin.database().ref(`/tanks/${uid}/fcm_tokens/${token}`);
  await tokenRef.set(true);
  console.log(`Successfully saved FCM token for user: ${uid}`);
  return { success: true, message: "Token saved successfully." };
});