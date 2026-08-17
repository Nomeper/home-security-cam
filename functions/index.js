const { getApps, initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore, Timestamp } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { RtcRole, RtcTokenBuilder } = require("agora-token");
const { createHash, randomBytes, randomInt } = require("crypto");

if (!getApps().length) {
  initializeApp();
}

const agoraAppId = defineSecret("AGORA_APP_ID");
const agoraAppCertificate = defineSecret("AGORA_APP_CERTIFICATE");
const tokenTtlSeconds = 15 * 60;
const identifierPattern = /^[A-Za-z0-9_-]{1,40}$/;
const pairingCodePattern = /^[A-F0-9]{24}$/;
const pairingCodeTtlMilliseconds = 10 * 60 * 1000;

function requireIdentifier(value, name) {
  if (typeof value !== "string" || !identifierPattern.test(value)) {
    throw new HttpsError(
      "invalid-argument",
      `${name} must contain 1–40 letters, numbers, underscores, or hyphens.`,
    );
  }
  return value;
}

function requireAgoraUid(value, source) {
  if (!Number.isInteger(value) || value < 1 || value > 0xffffffff) {
    throw new HttpsError(
      "failed-precondition",
      `${source} is missing a valid Agora UID.`,
    );
  }
  return value;
}

function generateAgoraUid() {
  return randomInt(1, 0xffffffff);
}

function generateId(prefix) {
  return `${prefix}_${randomBytes(12).toString("hex")}`;
}

function pairingCodeHash(code) {
  return createHash("sha256").update(code).digest("hex");
}

async function requireActiveOwner(home, uid) {
  const membership = await home.collection("members").doc(uid).get();
  if (
    !membership.exists ||
    membership.data()?.active !== true ||
    membership.data()?.role !== "owner"
  ) {
    throw new HttpsError("permission-denied", "Only the home owner can do this.");
  }
}

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before requesting access.");
  }
  return request.auth.uid;
}

exports.createHome = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);
    const db = getFirestore();
    const homeId = generateId("home");
    const home = db.collection("homes").doc(homeId);

    await db.runTransaction(async (transaction) => {
      transaction.set(home, {
        createdAt: FieldValue.serverTimestamp(),
        ownerUid: uid,
      });
      transaction.set(home.collection("members").doc(uid), {
        active: true,
        agoraUid: generateAgoraUid(),
        joinedAt: FieldValue.serverTimestamp(),
        role: "owner",
      });
    });

    return { homeId };
  },
);

exports.createPairingCode = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);
    const homeId = requireIdentifier(request.data?.homeId, "homeId");
    const target = request.data?.target;
    if (target !== "camera" && target !== "viewer") {
      throw new HttpsError("invalid-argument", "target must be camera or viewer.");
    }

    const db = getFirestore();
    const home = db.collection("homes").doc(homeId);
    await requireActiveOwner(home, uid);

    const code = randomBytes(12).toString("hex").toUpperCase();
    const codeHash = pairingCodeHash(code);
    const deviceId = target === "camera" ? generateId("camera") : null;
    await home.collection("pairingCodes").doc(codeHash).set({
      createdAt: FieldValue.serverTimestamp(),
      createdBy: uid,
      deviceId,
      expiresAt: Timestamp.fromMillis(Date.now() + pairingCodeTtlMilliseconds),
      target,
      usedAt: null,
      usedBy: null,
    });

    return {
      code,
      deviceId,
      expiresAt: Date.now() + pairingCodeTtlMilliseconds,
      target,
    };
  },
);

exports.redeemPairingCode = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);
    const code = request.data?.code;
    if (typeof code !== "string" || !pairingCodePattern.test(code)) {
      throw new HttpsError("invalid-argument", "Invalid pairing code.");
    }
    const homeId = requireIdentifier(request.data?.homeId, "homeId");
    const db = getFirestore();
    const home = db.collection("homes").doc(homeId);
    const codeRef = home.collection("pairingCodes").doc(pairingCodeHash(code));

    return db.runTransaction(async (transaction) => {
      const [homeSnapshot, codeSnapshot] = await Promise.all([
        transaction.get(home),
        transaction.get(codeRef),
      ]);
      if (!homeSnapshot.exists) {
        throw new HttpsError("not-found", "Home not found.");
      }
      if (
        !codeSnapshot.exists ||
        codeSnapshot.data()?.usedAt ||
        codeSnapshot.data()?.expiresAt.toMillis() <= Date.now()
      ) {
        throw new HttpsError("permission-denied", "Pairing code expired or already used.");
      }

      const pairing = codeSnapshot.data();
      const membership = home.collection("members").doc(uid);
      let deviceId = null;
      if (pairing.target === "camera") {
        deviceId = pairing.deviceId;
        transaction.set(home.collection("devices").doc(deviceId), {
          active: true,
          agoraUid: generateAgoraUid(),
          createdAt: FieldValue.serverTimestamp(),
          ownerUid: uid,
        });
      } else {
        transaction.set(membership, {
          active: true,
          agoraUid: generateAgoraUid(),
          joinedAt: FieldValue.serverTimestamp(),
          role: "viewer",
        });
      }
      transaction.update(codeRef, {
        usedAt: FieldValue.serverTimestamp(),
        usedBy: uid,
      });

      return { deviceId, role: pairing.target };
    });
  },
);

exports.listHomeCameras = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);
    const homeId = requireIdentifier(request.data?.homeId, "homeId");
    const home = getFirestore().collection("homes").doc(homeId);
    const membership = await home.collection("members").doc(uid).get();
    if (!membership.exists || membership.data()?.active !== true) {
      throw new HttpsError("permission-denied", "You are not an active home member.");
    }

    const devices = await home.collection("devices").where("active", "==", true).get();
    return {
      cameras: devices.docs.map((device) => ({
        deviceId: device.id,
        agoraUid: requireAgoraUid(device.data().agoraUid, "Camera device"),
      })),
    };
  },
);

exports.sendCameraCommand = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);
    const homeId = requireIdentifier(request.data?.homeId, "homeId");
    const deviceId = requireIdentifier(request.data?.deviceId, "deviceId");
    const type = request.data?.type;
    const desiredState = request.data?.desiredState;
    if (type !== "torch" || typeof desiredState !== "boolean") {
      throw new HttpsError("invalid-argument", "Only a boolean torch command is supported.");
    }

    const db = getFirestore();
    const home = db.collection("homes").doc(homeId);
    await requireActiveOwner(home, uid);
    const device = await home.collection("devices").doc(deviceId).get();
    if (!device.exists || device.data()?.active !== true) {
      throw new HttpsError("not-found", "Active camera not found.");
    }

    const command = home.collection("devices").doc(deviceId).collection("commands").doc();
    const expiresAt = Timestamp.fromMillis(Date.now() + 30 * 1000);
    await command.set({
      createdAt: FieldValue.serverTimestamp(),
      createdBy: uid,
      desiredState,
      expiresAt,
      status: "pending",
      type,
    });
    return { commandId: command.id, expiresAt: expiresAt.toMillis() };
  },
);

exports.acknowledgeCameraCommand = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);
    const homeId = requireIdentifier(request.data?.homeId, "homeId");
    const deviceId = requireIdentifier(request.data?.deviceId, "deviceId");
    const commandId = requireIdentifier(request.data?.commandId, "commandId");
    const succeeded = request.data?.succeeded;
    if (typeof succeeded !== "boolean") {
      throw new HttpsError("invalid-argument", "succeeded must be boolean.");
    }

    const db = getFirestore();
    const device = db.collection("homes").doc(homeId).collection("devices").doc(deviceId);
    const command = device.collection("commands").doc(commandId);
    await db.runTransaction(async (transaction) => {
      const [deviceSnapshot, commandSnapshot] = await Promise.all([
        transaction.get(device),
        transaction.get(command),
      ]);
      if (!deviceSnapshot.exists || deviceSnapshot.data()?.ownerUid !== uid) {
        throw new HttpsError("permission-denied", "This camera does not belong to you.");
      }
      if (!commandSnapshot.exists || commandSnapshot.data()?.status !== "pending") {
        throw new HttpsError("failed-precondition", "Command is no longer pending.");
      }
      transaction.update(command, {
        completedAt: FieldValue.serverTimestamp(),
        status: succeeded ? "executed" : "failed",
      });
    });
    return { acknowledged: true };
  },
);

/**
 * Issues one short-lived token for an authorised camera or viewer.
 *
 * Firestore data required before this function can issue a token:
 *   homes/{homeId}/members/{firebaseUid}: { active: true, agoraUid: number }
 *   homes/{homeId}/devices/{deviceId}: { active: true, ownerUid: firebaseUid, agoraUid: number }
 */
exports.createRtcSession = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
    secrets: [agoraAppId, agoraAppCertificate],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in before requesting RTC access.");
    }

    const homeId = requireIdentifier(request.data?.homeId, "homeId");
    const deviceId = requireIdentifier(request.data?.deviceId, "deviceId");
    const requestedRole = request.data?.role;
    if (requestedRole !== "camera" && requestedRole !== "viewer") {
      throw new HttpsError("invalid-argument", "role must be camera or viewer.");
    }

    const db = getFirestore();
    const home = db.collection("homes").doc(homeId);
    const membership = await home.collection("members").doc(request.auth.uid).get();
    if (!membership.exists || membership.data()?.active !== true) {
      throw new HttpsError("permission-denied", "You are not an active home member.");
    }

    let uid;
    let tokenRole;
    if (requestedRole === "camera") {
      const device = await home.collection("devices").doc(deviceId).get();
      if (
        !device.exists ||
        device.data()?.active !== true ||
        device.data()?.ownerUid !== request.auth.uid
      ) {
        throw new HttpsError(
          "permission-denied",
          "You are not authorised to publish for this camera.",
        );
      }
      uid = requireAgoraUid(device.data()?.agoraUid, "Camera device");
      tokenRole = RtcRole.PUBLISHER;
    } else {
      uid = requireAgoraUid(membership.data()?.agoraUid, "Home membership");
      tokenRole = RtcRole.SUBSCRIBER;
    }

    const channelId = `home_${homeId}`;
    const expiresAt = Math.floor(Date.now() / 1000) + tokenTtlSeconds;
    const token = RtcTokenBuilder.buildTokenWithUid(
      agoraAppId.value(),
      agoraAppCertificate.value(),
      channelId,
      uid,
      tokenRole,
      expiresAt,
      expiresAt,
    );

    return {
      appId: agoraAppId.value(),
      channelId,
      expiresAt,
      role: requestedRole,
      token,
      uid,
    };
  },
);
