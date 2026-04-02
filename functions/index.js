const admin = require('firebase-admin');
const { onDocumentCreated, onDocumentCreated: onDocCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();
const PENALTY_SKIP_GOLD_COST = 80;
const HOSPITAL_SKIP_MIN_TP = 35;
const HOSPITAL_PENALTY_MINUTES = 45;
const PRISON_PENALTY_MINUTES = 10;
const HOSPITAL_PENALTY_SEC = HOSPITAL_PENALTY_MINUTES * 60;
const PRISON_PENALTY_SEC = PRISON_PENALTY_MINUTES * 60;
const MALAMADRE_UID = 'herTAikcrQOKmnM2aYSjwGqliPl2';
const MALAMADRE_MIN_GOLD = 2000000;
const GOLD_OVERRIDE_BY_UID = Object.freeze({
  // Malamadre: always keep at least 2M gold server-side.
  [MALAMADRE_UID]: MALAMADRE_MIN_GOLD,
});

function normalizePenaltyStatus(rawStatus) {
  const s = String(rawStatus || 'active').trim().toLowerCase();
  return s === 'hospital' || s === 'prison' ? s : 'active';
}

function penaltySecondsForStatus(rawStatus) {
  const status = normalizePenaltyStatus(rawStatus);
  return status === 'prison' ? PRISON_PENALTY_SEC : HOSPITAL_PENALTY_SEC;
}

function resolvePenaltyStatus(data, nowEpoch = Math.floor(Date.now() / 1000)) {
  const status = normalizePenaltyStatus(data?.status);
  const statusUntilEpoch = Math.max(
    0,
    Number(
      data?.statusUntilEpoch ??
      (data?.statusUntil?.seconds
        ? data.statusUntil.seconds
        : 0) ??
      0,
    ),
  );
  if (statusUntilEpoch > nowEpoch) {
    return { status, statusUntilEpoch };
  }
  return { status: 'active', statusUntilEpoch: 0 };
}

function asInt(value, fallback = 0) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.trunc(n);
}

function forcedGoldMinForUid(uid) {
  const cleanUid = String(uid ?? '').trim();
  if (cleanUid === MALAMADRE_UID) {
    return MALAMADRE_MIN_GOLD;
  }
  return asInt(GOLD_OVERRIDE_BY_UID[cleanUid], 0);
}

function safeText(value, fallback = '', maxLen = 32) {
  const cleaned = String(value ?? '')
    .replace(/[\u0000-\u001F\u007F]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!cleaned) return fallback;
  return cleaned.substring(0, maxLen);
}

const ASSIGNABLE_GANG_ROLES = ['Sağ Kol', 'Kaptan', 'Tetikçi', 'Asker', 'Üye'];

function normalizeGangRole(raw, fallback = 'Üye') {
  const value = String(raw ?? '')
    .trim()
    .toLowerCase();
  switch (value) {
    case 'lider':
    case 'leader':
      return 'Lider';
    case 'sağ kol':
    case 'sag kol':
    case 'right hand':
    case 'underboss':
      return 'Sağ Kol';
    case 'kaptan':
    case 'captain':
      return 'Kaptan';
    case 'tetikçi':
    case 'tetikci':
    case 'hitman':
      return 'Tetikçi';
    case 'asker':
    case 'soldier':
      return 'Asker';
    case 'üye':
    case 'uye':
    case 'member':
      return 'Üye';
    default:
      return fallback;
  }
}

function hasOwn(obj, key) {
  return Object.prototype.hasOwnProperty.call(obj || {}, key);
}

function turkeyDayKey(epochSec) {
  const normalized = Math.max(0, asInt(epochSec, 0));
  return Math.floor((normalized + (3 * 60 * 60)) / (24 * 60 * 60));
}

function sanitizeIdFromMap(raw, mapObj, fallback = '') {
  const id = String(raw ?? '').trim();
  if (!id) return fallback;
  return hasOwn(mapObj, id) ? id : fallback;
}

function sanitizeProfileSyncInput({ uid, previous, input, nowEpoch }) {
  const prev = previous || {};
  const firstSync = !previous || Object.keys(previous).length === 0;
  const starterCash = 5000;
  const starterGold = 1000;
  const prevUpdatedEpoch = Math.max(
    0,
    asInt(prev.lastServerSyncEpoch, asInt(prev.updatedAt?.seconds, nowEpoch)),
  );
  const elapsedSec = firstSync
    ? (24 * 60 * 60)
    : clamp(nowEpoch - prevUpdatedEpoch, 1, 7 * 24 * 60 * 60);

  const reasons = [];
  const markClamp = (reason) => {
    if (!reasons.includes(reason)) reasons.push(reason);
  };

  const clampUpward = ({
    prevValue,
    requestedValue,
    maxIncrease,
    minValue,
    maxValue,
    reason,
  }) => {
    const req = clamp(asInt(requestedValue, prevValue), minValue, maxValue);
    if (firstSync) return req;
    const cap = clamp(prevValue + Math.max(0, maxIncrease), minValue, maxValue);
    if (req > cap) {
      markClamp(reason);
      return cap;
    }
    return req;
  };

  const prevPower = clamp(asInt(prev.power, 1), 1, 500000);
  const prevCash = clamp(asInt(prev.cash, 0), 0, 100000000);
  const prevGold = clamp(asInt(prev.gold, 0), 0, 100000000);
  const prevXp = clamp(asInt(prev.xp, 0), 0, 100000000);
  const prevWins = clamp(asInt(prev.wins, 0), 0, 1000000);
  const prevGangWins = clamp(asInt(prev.gangWins, 0), 0, 1000000);
  const prevLevel = clamp(asInt(prev.level, 1), 1, 2000);
  const prevRank = clamp(asInt(prev.rank, 0), 0, 5000);

  const maxPowerIncrease = Math.min(7000, 30 + Math.trunc(elapsedSec / 15));
  const maxCashIncrease = Math.min(2500000, 30000 + Math.trunc(elapsedSec * 220));
  const maxGoldIncrease = Math.min(100000, 40 + Math.trunc(elapsedSec * 4));
  const maxXpIncrease = Math.min(500000, 1200 + Math.trunc(elapsedSec * 40));
  const maxWinsIncrease = Math.min(40, 1 + Math.trunc(elapsedSec / 300));
  const maxGangWinsIncrease = Math.min(40, 1 + Math.trunc(elapsedSec / 300));
  const maxLevelIncrease = Math.min(50, 1 + Math.trunc(elapsedSec / 1800));
  const maxRankIncrease = Math.min(50, 1 + Math.trunc(elapsedSec / 1800));

  const power = clampUpward({
    prevValue: prevPower,
    requestedValue: input.power,
    maxIncrease: maxPowerIncrease,
    minValue: 1,
    maxValue: 500000,
    reason: 'power_gain_clamped',
  });

  const rawCash = clampUpward({
    prevValue: prevCash,
    requestedValue: input.cash,
    maxIncrease: maxCashIncrease,
    minValue: 0,
    maxValue: 100000000,
    reason: 'cash_gain_clamped',
  });
  const cash = firstSync ? Math.max(starterCash, rawCash) : rawCash;

  const rawGold = clampUpward({
    prevValue: prevGold,
    requestedValue: input.gold,
    maxIncrease: maxGoldIncrease,
    minValue: 0,
    maxValue: 100000000,
    reason: 'gold_gain_clamped',
  });
  let gold = firstSync ? Math.max(starterGold, rawGold) : rawGold;
  const forcedGoldMin = forcedGoldMinForUid(uid);
  if (forcedGoldMin > 0 && gold < forcedGoldMin) {
    gold = forcedGoldMin;
    markClamp('gold_override_applied');
  }

  const xp = clampUpward({
    prevValue: prevXp,
    requestedValue: input.xp,
    maxIncrease: maxXpIncrease,
    minValue: 0,
    maxValue: 100000000,
    reason: 'xp_gain_clamped',
  });

  const wins = clampUpward({
    prevValue: prevWins,
    requestedValue: input.wins,
    maxIncrease: maxWinsIncrease,
    minValue: 0,
    maxValue: 1000000,
    reason: 'wins_gain_clamped',
  });

  const gangWins = clampUpward({
    prevValue: prevGangWins,
    requestedValue: input.gangWins,
    maxIncrease: maxGangWinsIncrease,
    minValue: 0,
    maxValue: 1000000,
    reason: 'gang_wins_gain_clamped',
  });

  const level = clampUpward({
    prevValue: prevLevel,
    requestedValue: input.level,
    maxIncrease: maxLevelIncrease,
    minValue: 1,
    maxValue: 2000,
    reason: 'level_gain_clamped',
  });

  const rank = clampUpward({
    prevValue: prevRank,
    requestedValue: input.rank,
    maxIncrease: maxRankIncrease,
    minValue: 0,
    maxValue: 5000,
    reason: 'rank_gain_clamped',
  });

  const maxEnergy = clamp(asInt(input.maxEnergy, asInt(prev.maxEnergy, 120)), 100, 500);
  const maxTp = clamp(asInt(input.maxTp, asInt(prev.maxTp, 120)), 100, 500);
  const currentEnergy = clamp(
    asInt(input.currentEnergy, asInt(prev.currentEnergy, maxEnergy)),
    0,
    maxEnergy,
  );
  const currentTp = clamp(
    asInt(input.currentTp, asInt(prev.currentTp, maxTp)),
    0,
    maxTp,
  );
  const attackEnergyCost = clamp(
    asInt(input.attackEnergyCost, asInt(prev.attackEnergyCost, 20)),
    12,
    24,
  );

  const prevPenalty = resolvePenaltyStatus(prev, nowEpoch);
  const requestedStatus = normalizePenaltyStatus(input.status);
  const requestedStatusUntilEpoch = Math.max(
    0,
    asInt(
      input.statusUntilEpoch,
      asInt(input.statusUntil?.seconds, 0),
    ),
  );
  const maxPenaltyUntilEpoch = nowEpoch + (2 * 60 * 60);

  let status = prevPenalty.status;
  let statusUntilEpoch = prevPenalty.statusUntilEpoch;

  if (status === 'active') {
    if (requestedStatus !== 'active' && requestedStatusUntilEpoch > nowEpoch) {
      status = requestedStatus;
      statusUntilEpoch = clamp(requestedStatusUntilEpoch, nowEpoch + 60, maxPenaltyUntilEpoch);
      if (requestedStatusUntilEpoch > statusUntilEpoch) {
        markClamp('status_until_clamped');
      }
    }
  } else if (requestedStatus === status && requestedStatusUntilEpoch > statusUntilEpoch) {
    statusUntilEpoch = clamp(requestedStatusUntilEpoch, statusUntilEpoch, maxPenaltyUntilEpoch);
    if (requestedStatusUntilEpoch > statusUntilEpoch) {
      markClamp('status_extend_clamped');
    }
  } else if (requestedStatus === 'active') {
    markClamp('status_clear_blocked');
  }

  if (statusUntilEpoch <= nowEpoch) {
    status = 'active';
    statusUntilEpoch = 0;
  }

  const todayVipShieldDayKey = turkeyDayKey(nowEpoch);
  const prevVipShieldLastUseDayKey = clamp(asInt(prev.vipShieldLastUseDayKey, 0), 0, todayVipShieldDayKey);
  const requestedVipShieldLastUseDayKey = clamp(
    asInt(input.vipShieldLastUseDayKey, prevVipShieldLastUseDayKey),
    0,
    todayVipShieldDayKey,
  );
  const prevShieldUntil = Math.max(0, asInt(prev.shieldUntilEpoch, 0));
  const requestedShieldUntil = clamp(
    Math.max(0, asInt(input.shieldUntilEpoch, prevShieldUntil)),
    0,
    nowEpoch + (6 * 60 * 60),
  );
  let shieldUntilEpoch = prevShieldUntil;
  let vipShieldLastUseDayKey = prevVipShieldLastUseDayKey;
  if (requestedShieldUntil > prevShieldUntil) {
    if (prevVipShieldLastUseDayKey >= todayVipShieldDayKey) {
      markClamp('shield_daily_limit_blocked');
    } else {
      shieldUntilEpoch = requestedShieldUntil;
      vipShieldLastUseDayKey = todayVipShieldDayKey;
    }
  } else if (requestedShieldUntil < prevShieldUntil && prevShieldUntil > nowEpoch) {
    markClamp('shield_reduce_blocked');
  }
  if (requestedVipShieldLastUseDayKey > vipShieldLastUseDayKey) {
    vipShieldLastUseDayKey = requestedVipShieldLastUseDayKey;
  }
  if (shieldUntilEpoch <= nowEpoch) {
    shieldUntilEpoch = 0;
  }

  const displayName = safeText(input.displayName ?? input.name, safeText(prev.displayName ?? prev.name, 'Oyuncu', 24), 24);
  const avatarId = safeText(input.avatarId, safeText(prev.avatarId, '', 32), 32);

  const equippedWeaponId = sanitizeIdFromMap(
    input.equippedWeaponId,
    WEAPON_ARCHETYPE_BY_ID,
    sanitizeIdFromMap(prev.equippedWeaponId, WEAPON_ARCHETYPE_BY_ID, ''),
  );
  const combatWeaponId = sanitizeIdFromMap(
    input.combatWeaponId,
    WEAPON_ARCHETYPE_BY_ID,
    equippedWeaponId || sanitizeIdFromMap(prev.combatWeaponId, WEAPON_ARCHETYPE_BY_ID, ''),
  );
  const equippedKnifeId = sanitizeIdFromMap(
    input.equippedKnifeId,
    WEAPON_ARCHETYPE_BY_ID,
    sanitizeIdFromMap(prev.equippedKnifeId, WEAPON_ARCHETYPE_BY_ID, ''),
  );
  const equippedArmorId = sanitizeIdFromMap(
    input.equippedArmorId,
    ARMOR_ARCHETYPE_BY_ID,
    sanitizeIdFromMap(prev.equippedArmorId, ARMOR_ARCHETYPE_BY_ID, ''),
  );
  const equippedVehicleId = sanitizeIdFromMap(
    input.equippedVehicleId,
    VEHICLE_ARCHETYPE_BY_ID,
    sanitizeIdFromMap(prev.equippedVehicleId, VEHICLE_ARCHETYPE_BY_ID, ''),
  );

  const gangId = safeText(prev.gangId, '', 64);
  const gangName = safeText(prev.gangName, '', 32);
  const gangRole = safeText(prev.gangRole, '', 16);

  const lastLoginEpoch = clamp(
    asInt(input.lastLoginEpoch, asInt(prev.lastLoginEpoch, nowEpoch)),
    0,
    nowEpoch,
  );

  const online = Boolean(input.online);
  const score = Math.trunc((power * 12) + (wins * 900) + (gangWins * 1200) + (cash / 2000));

  return {
    flagged: reasons.length > 0,
    reasons,
    profile: {
      uid,
      name: displayName,
      displayName,
      avatarId,
      power,
      level,
      rank,
      cash,
      gold,
      xp,
      wins,
      gangWins,
      currentEnergy,
      maxEnergy,
      attackEnergyCost,
      currentTp,
      maxTp,
      status,
      statusUntilEpoch,
      statusUntil: statusUntilEpoch > 0
        ? admin.firestore.Timestamp.fromDate(new Date(statusUntilEpoch * 1000))
        : null,
      shieldUntilEpoch,
      vipShieldLastUseDayKey,
      equippedWeaponId,
      equippedKnifeId,
      equippedArmorId,
      equippedVehicleId,
      combatWeaponId,
      gangId,
      gangName,
      gangRole,
      lastLoginEpoch,
      online,
      score,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastServerSyncEpoch: nowEpoch,
      // Prevent client from escalating privileges.
      isBot: prev.isBot === true,
    },
  };
}

exports.secureSyncProfile = onCall({ invoker: 'public' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Giriş yapman gerekiyor');
  }

  const input = request.data || {};
  const nowEpoch = Math.floor(Date.now() / 1000);
  const userRef = db.collection('users').doc(uid);
  const eventRef = db.collection('security_events').doc();

  const outcome = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const previous = userSnap.exists ? (userSnap.data() || {}) : {};
    if (previous.isBot === true) {
      throw new HttpsError('permission-denied', 'Bot profili senkronlanamaz');
    }

    const sanitized = sanitizeProfileSyncInput({
      uid,
      previous,
      input,
      nowEpoch,
    });

    tx.set(userRef, sanitized.profile, { merge: true });

    if (sanitized.flagged) {
      tx.set(eventRef, {
        uid,
        type: 'profile_sync_clamped',
        reasons: sanitized.reasons,
        requested: {
          power: asInt(input.power, 0),
          cash: asInt(input.cash, 0),
          gold: asInt(input.gold, 0),
          xp: asInt(input.xp, 0),
          level: asInt(input.level, 0),
          rank: asInt(input.rank, 0),
          wins: asInt(input.wins, 0),
          gangWins: asInt(input.gangWins, 0),
          status: String(input.status ?? ''),
          statusUntilEpoch: asInt(input.statusUntilEpoch, 0),
        },
        applied: {
          power: sanitized.profile.power,
          cash: sanitized.profile.cash,
          gold: sanitized.profile.gold,
          xp: sanitized.profile.xp,
          level: sanitized.profile.level,
          rank: sanitized.profile.rank,
          wins: sanitized.profile.wins,
          gangWins: sanitized.profile.gangWins,
          status: sanitized.profile.status,
          statusUntilEpoch: sanitized.profile.statusUntilEpoch,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      flagged: sanitized.flagged,
      reasons: sanitized.reasons,
      profile: {
        power: sanitized.profile.power,
        cash: sanitized.profile.cash,
        gold: sanitized.profile.gold,
        xp: sanitized.profile.xp,
        level: sanitized.profile.level,
        rank: sanitized.profile.rank,
        wins: sanitized.profile.wins,
        gangWins: sanitized.profile.gangWins,
        status: sanitized.profile.status,
        statusUntilEpoch: sanitized.profile.statusUntilEpoch,
      },
    };
  });

  return { ok: true, ...outcome };
});

exports.secureSkipPenalty = onCall({ invoker: 'public' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Giriş yapman gerekiyor');
  }

  const penalty = normalizePenaltyStatus(request.data?.penalty);
  if (penalty === 'active') {
    throw new HttpsError('invalid-argument', 'Geçersiz ceza tipi');
  }

  const nowEpoch = Math.floor(Date.now() / 1000);
  const userRef = db.collection('users').doc(uid);

  const outcome = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'Oyuncu profili bulunamadı');
    }

    const user = userSnap.data() || {};
    if (user.isBot === true) {
      throw new HttpsError('permission-denied', 'Bot profili için işlem yapılamaz');
    }

    const statusInfo = resolvePenaltyStatus(user, nowEpoch);
    const currentStatus = statusInfo.status;
    const currentGold = Math.max(0, asInt(user.gold, 0));
    const maxTp = clamp(asInt(user.maxTp, 120), 100, 500);
    const currentTp = clamp(asInt(user.currentTp, maxTp), 0, maxTp);

    if (currentStatus === 'active') {
      tx.set(userRef, {
        status: 'active',
        statusUntilEpoch: 0,
        statusUntil: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastServerSyncEpoch: nowEpoch,
      }, { merge: true });
      return {
        ok: true,
        alreadyActive: true,
        status: 'active',
        statusUntilEpoch: 0,
        gold: currentGold,
        currentTp,
        cost: 0,
      };
    }

    if (currentStatus !== penalty) {
      throw new HttpsError(
        'failed-precondition',
        penalty === 'prison'
          ? 'Şu an hapiste değilsin.'
          : 'Şu an hastanede değilsin.',
      );
    }

    if (currentGold < PENALTY_SKIP_GOLD_COST) {
      throw new HttpsError('failed-precondition', 'Yeterli altın yok');
    }

    const nextGold = currentGold - PENALTY_SKIP_GOLD_COST;
    const patch = {
      gold: nextGold,
      status: 'active',
      statusUntilEpoch: 0,
      statusUntil: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastServerSyncEpoch: nowEpoch,
    };

    let nextCurrentTp = currentTp;
    if (penalty === 'hospital') {
      nextCurrentTp = Math.max(currentTp, Math.min(maxTp, HOSPITAL_SKIP_MIN_TP));
      patch.currentTp = nextCurrentTp;
    }

    tx.set(userRef, patch, { merge: true });

    return {
      ok: true,
      alreadyActive: false,
      status: 'active',
      statusUntilEpoch: 0,
      gold: nextGold,
      currentTp: nextCurrentTp,
      cost: PENALTY_SKIP_GOLD_COST,
    };
  });

  return outcome;
});

exports.assignGangMemberRole = onCall({ invoker: 'public' }, async (request) => {
  const actorUid = String(request.auth?.uid ?? '').trim();
  if (!actorUid) {
    throw new HttpsError('unauthenticated', 'Giriş yapman gerekiyor');
  }

  const gangId = safeText(request.data?.gangId, '', 64);
  const targetUid = safeText(request.data?.targetUid, '', 64);
  const requestedRole = normalizeGangRole(request.data?.role, '');

  if (!gangId || !targetUid || !requestedRole) {
    throw new HttpsError('invalid-argument', 'Geçersiz kartel rütbe isteği');
  }
  if (!ASSIGNABLE_GANG_ROLES.includes(requestedRole)) {
    throw new HttpsError('invalid-argument', 'Bu rütbe atanamaz');
  }

  const gangRef = db.collection('gangs').doc(gangId);
  const targetMemberRef = gangRef.collection('members').doc(targetUid);
  const targetUserRef = db.collection('users').doc(targetUid);

  const result = await db.runTransaction(async (tx) => {
    const gangSnap = await tx.get(gangRef);
    if (!gangSnap.exists) {
      throw new HttpsError('not-found', 'Kartel bulunamadı');
    }
    const gang = gangSnap.data() || {};
    const ownerId = safeText(gang.ownerId, '', 64);
    if (!ownerId) {
      throw new HttpsError('failed-precondition', 'Kartel lideri bulunamadı');
    }

    const isOwner = ownerId === actorUid;
    if (!isOwner) {
      throw new HttpsError('permission-denied', 'Bu işlem için yetkin yok');
    }

    const targetMemberSnap = await tx.get(targetMemberRef);
    if (!targetMemberSnap.exists) {
      throw new HttpsError('not-found', 'Bu oyuncu kartelde bulunamadı');
    }
    const targetMember = targetMemberSnap.data() || {};
    const currentRole = normalizeGangRole(targetMember.role, 'Üye');
    const targetIsOwner = targetUid === ownerId || currentRole === 'Lider';
    if (targetIsOwner) {
      throw new HttpsError('failed-precondition', 'Lider rütbesi değiştirilemez');
    }

    if (currentRole === requestedRole) {
      return { ok: true, role: requestedRole, unchanged: true };
    }

    tx.update(targetMemberRef, {
      role: requestedRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const targetUserSnap = await tx.get(targetUserRef);
    if (targetUserSnap.exists) {
      const targetGangId = safeText(targetUserSnap.data()?.gangId, '', 64);
      if (targetGangId === gangId) {
        tx.set(targetUserRef, {
          gangRole: requestedRole,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }

    tx.set(db.collection('gang_role_events').doc(), {
      gangId,
      actorUid,
      targetUid,
      fromRole: currentRole,
      toRole: requestedRole,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, role: requestedRole, unchanged: false };
  });

  return {
    ok: true,
    gangId,
    targetUid,
    role: result.role,
    unchanged: result.unchanged === true,
  };
});

function isBotUid(uid) {
  return String(uid ?? '').trim().startsWith('bot_');
}

const GLOBAL_CHAT_ROOM_ID = 'global';

async function writeInboxMessage(uid, payload) {
  const targetUid = String(uid ?? '').trim();
  if (!targetUid || isBotUid(targetUid)) return;
  const now = admin.firestore.Timestamp.now();
  await db
    .collection('users')
    .doc(targetUid)
    .collection('inbox')
    .add({
      ...payload,
      isRead: false,
      createdAt: now,
    });
}

exports.sendInboxDirectMessage = onCall({ invoker: 'public' }, async (request) => {
  const fromId = String(request.auth?.uid ?? '').trim();
  if (!fromId) {
    throw new HttpsError('unauthenticated', 'Giriş yapman gerekiyor.');
  }

  const toId = safeText(request.data?.toUid, '', 64);
  const rawText = safeText(request.data?.text, '', 400);
  if (!toId) {
    throw new HttpsError('invalid-argument', 'Geçerli bir oyuncu seç.');
  }
  if (toId === fromId) {
    throw new HttpsError('invalid-argument', 'Kendine mesaj gönderemezsin.');
  }
  if (!rawText) {
    throw new HttpsError('invalid-argument', 'Mesaj boş olamaz.');
  }
  if (isBotUid(fromId) || isBotUid(toId)) {
    throw new HttpsError('failed-precondition', 'Bu oyuncuya mesaj gönderemezsin.');
  }

  const fromUserRef = db.collection('users').doc(fromId);
  const toUserRef = db.collection('users').doc(toId);
  const fromFriendRef = fromUserRef.collection('friends').doc(toId);
  const toFriendRef = toUserRef.collection('friends').doc(fromId);

  const [fromUserSnap, toUserSnap, fromFriendSnap, toFriendSnap] = await Promise.all([
    fromUserRef.get(),
    toUserRef.get(),
    fromFriendRef.get(),
    toFriendRef.get(),
  ]);

  if (!fromUserSnap.exists) {
    throw new HttpsError('failed-precondition', 'Profilin bulunamadı.');
  }
  if (!toUserSnap.exists) {
    throw new HttpsError('not-found', 'Oyuncu bulunamadı.');
  }
  if (toUserSnap.data()?.isBot === true) {
    throw new HttpsError('failed-precondition', 'Bot oyunculara mesaj gönderemezsin.');
  }

  const areFriends = fromFriendSnap.exists || toFriendSnap.exists;
  if (!areFriends) {
    throw new HttpsError('failed-precondition', 'Sadece arkadaşına mesaj gönderebilirsin.');
  }

  const fromName = safeText(
    fromUserSnap.data()?.displayName ?? fromUserSnap.data()?.name,
    'Oyuncu',
    32,
  );
  const toName = safeText(
    toUserSnap.data()?.displayName ?? toUserSnap.data()?.name,
    'Oyuncu',
    32,
  );
  const threadId = [fromId, toId].sort().join('__');
  const now = admin.firestore.Timestamp.now();

  const receiverRef = toUserRef.collection('inbox').doc();
  const senderRef = fromUserRef.collection('inbox').doc();

  const receiverPayload = {
    type: 'direct_message',
    threadId,
    title: fromName,
    body: rawText,
    fromId,
    fromName,
    toId,
    toName,
    direction: 'incoming',
    isRead: false,
    createdAt: now,
  };
  const senderPayload = {
    type: 'direct_message',
    threadId,
    title: toName,
    body: rawText,
    fromId,
    fromName,
    toId,
    toName,
    direction: 'outgoing',
    isRead: true,
    createdAt: now,
  };

  const batch = db.batch();
  batch.set(receiverRef, receiverPayload);
  batch.set(senderRef, senderPayload);
  await batch.commit();

  return { ok: true, toId, toName };
});

function normalizeTrText(raw) {
  return String(raw ?? '')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function includesAny(text, keywords) {
  return keywords.some((k) => text.includes(k));
}

async function claimGlobalChatSlot(key, minGapMs) {
  const ref = db.collection('meta').doc('global_chat_bot');
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const lastMs = Number(snap.data()?.[key] ?? 0);
    const nowMs = Date.now();
    if ((nowMs - lastMs) < minGapMs) {
      return false;
    }
    tx.set(ref, {
      [key]: nowMs,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
}

async function claimSenderReplyWindow(senderId, minGapMs) {
  const uid = String(senderId ?? '').trim();
  if (!uid) return false;
  const ref = db
    .collection('meta')
    .doc('global_chat_bot')
    .collection('sender_reply_windows')
    .doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const lastMs = Number(snap.data()?.lastReplyAtMs ?? 0);
    const nowMs = Date.now();
    if ((nowMs - lastMs) < minGapMs) {
      return false;
    }
    tx.set(ref, {
      lastReplyAtMs: nowMs,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
}

const BOT_PERSONALITY_KEYS = ['aggressive', 'tactician', 'economist', 'mentor', 'street'];
const BOT_PERSONALITY_ACTIVITY = {
  aggressive: { attackSec: 12 * 60, missionSec: 7 * 60 },
  tactician: { attackSec: 18 * 60, missionSec: 10 * 60 },
  economist: { attackSec: 26 * 60, missionSec: 8 * 60 },
  mentor: { attackSec: 24 * 60, missionSec: 12 * 60 },
  street: { attackSec: 15 * 60, missionSec: 9 * 60 },
};
const BOT_PERSONALITY_PROFILES = {
  aggressive: {
    label: 'Agresif',
    followUps: [
      'Bu tur risk alıp üstüne mi gideceksin?',
      'Rövanşı hemen mi alırsın yoksa güç toplayıp mı dönersin?',
      'Bugün hedefin daha çok baskın mı?',
    ],
    topicAddons: {
      pvp: 'Temponu düşürme, baskıyı kuran genelde kazanır.',
      economy: 'Parayı çok bekletme, güce çevirmek daha iyi.',
      mission: 'Kısa görev döngüsüyle sıcak kal, sonra PvP.',
      generic: 'Şehirde tereddüt edene yer yok.',
    },
    promptStyle: [
      'Bu gece agresif oynayan topluyor, siz de tempoyu artırıyor musunuz?',
      'Kısa aralıklarla baskın mı uzun farm mı? Ben baskını seçiyorum.',
    ],
  },
  tactician: {
    label: 'Taktikçi',
    followUps: [
      'Sence önce savunma mı hücum mu yükseltilmeli?',
      'Saldırı öncesi rakibin ekipmanını kontrol ediyor musun?',
      'Planlı saldırı mı hızlı saldırı mı daha verimli?',
    ],
    topicAddons: {
      pvp: 'Eşleşme penceresi ve ekipman karşılaştırması sonucu belirliyor.',
      energy: 'Enerjiyi ikiye böl: biri görev biri PvP için.',
      equipment: 'Slot uyumu tamamlanmadan zor hedefe girme.',
      generic: 'Doğru zamanlama ham güçten daha çok iş yapıyor.',
    },
    promptStyle: [
      'Maç öncesi ekipman uyumu kontrolü yapıyor musunuz?',
      'Bana göre en kritik şey zamanlama, sizce ne?',
    ],
  },
  economist: {
    label: 'Ekonomist',
    followUps: [
      'Bugün altını biriktiriyor musun harcıyor musun?',
      'Nakit akışını görevle mi PvP ile mi büyütüyorsun?',
      'Sandık açmayı hangi seviyede mantıklı buluyorsun?',
    ],
    topicAddons: {
      economy: 'Geliri artıran yatırımlar önce gelmeli.',
      mission: 'Düşük riskli görevlerle sermaye büyütmek güvenli.',
      pvp: 'Kazancı korumak için saldırı ritmini kontrollü tut.',
      generic: 'Sürdürülebilir ekonomi oyunun omurgası.',
    },
    promptStyle: [
      'Ganimeti ekipmana mı kasaya mı ayırıyorsunuz?',
      'Nakit ve altın dengesini nasıl kuruyorsunuz?',
    ],
  },
  mentor: {
    label: 'Mentor',
    followUps: [
      'İstersen build önerisi de çıkarabiliriz, hangi rolü oynuyorsun?',
      'Yeni başlayanlara göre en zor kısım sence ne?',
      'Rank için günlük rutinin var mı?',
    ],
    topicAddons: {
      progression: 'Küçük ama düzenli ilerleme en hızlı sonucu verir.',
      social: 'Çete koordinasyonu yeni oyuncuyu çok hızlandırır.',
      penalty: 'Hapis/hastane süresini plan için kullan, acele etme.',
      generic: 'Sistemli oynarsan rank zaten kendiliğinden yükselir.',
    },
    promptStyle: [
      'Yeni başlayanlara tek tavsiyen ne olurdu?',
      'Bugün birine yardım edecek olsan hangi ipucunu verirdin?',
    ],
  },
  street: {
    label: 'Sokakçı',
    followUps: [
      'Sokakta bugün kimler aktif, sizde durum nasıl?',
      'Çete mi solo mu gidiyorsun bu saatlerde?',
      'Bu gece risk alacak mısın?',
    ],
    topicAddons: {
      pvp: 'Sokakta adı yürüyen hedefler genelde iyi ganimet bırakır.',
      social: 'Muhabbetten gelen istihbarat bazen savaşı kazandırır.',
      mission: 'Görevle ısın, sonra kalabalığa gir.',
      generic: 'Şehrin nabzı yüksek, dikkatli ama cesur oyna.',
    },
    promptStyle: [
      'Sokakta hava sert, sizce bu saat görev mi baskın mı?',
      'Bugün kimler sokakta isim yapar dersiniz?',
    ],
  },
};

function hashString(input) {
  const s = String(input ?? '');
  let hash = 0;
  for (let i = 0; i < s.length; i += 1) {
    hash = ((hash << 5) - hash) + s.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function resolveBotPersonality(bot) {
  const forcedKey = String(bot?.personality ?? '').trim();
  if (BOT_PERSONALITY_PROFILES[forcedKey]) {
    return { key: forcedKey, ...BOT_PERSONALITY_PROFILES[forcedKey] };
  }
  const source = String(bot?.id ?? bot?.name ?? 'bot_default');
  const key = BOT_PERSONALITY_KEYS[hashString(source) % BOT_PERSONALITY_KEYS.length];
  return { key, ...BOT_PERSONALITY_PROFILES[key] };
}

function resolveBotCadenceSec(bot, profileKey) {
  const key = BOT_PERSONALITY_ACTIVITY[profileKey] ? profileKey : 'street';
  const base = BOT_PERSONALITY_ACTIVITY[key];
  const seed = hashString(`${bot?.id ?? bot?.name ?? 'bot'}:${key}`);
  const attackJitter = (seed % 6) * 45;
  const missionJitter = (seed % 5) * 30;
  return {
    attackSec: Math.max(8 * 60, base.attackSec + attackJitter),
    missionSec: Math.max(6 * 60, base.missionSec + missionJitter),
  };
}

function detectGlobalTopic(rawText, normalizedText) {
  if (includesAny(normalizedText, ['selam', 'merhaba', 'sa', 'hey'])) return 'greet';
  if (includesAny(normalizedText, ['enerji', 'energy'])) return 'energy';
  if (includesAny(normalizedText, ['saldir', 'pvp', 'baski', 'duello', 'intikam'])) return 'pvp';
  if (includesAny(normalizedText, ['gorev', 'soygun', 'operasyon', 'market'])) return 'mission';
  if (includesAny(normalizedText, ['hapis', 'hapishane', 'hastane', 'yakalandin'])) return 'penalty';
  if (includesAny(normalizedText, ['altin', 'nakit', 'para', 'sandik', 'kacakci', 'premium'])) return 'economy';
  if (includesAny(normalizedText, ['ekipman', 'envanter', 'silah', 'zirh', 'araba', 'slot'])) return 'equipment';
  if (includesAny(normalizedText, ['seviye', 'rutbe', 'xp', 'guc', 'stat'])) return 'progression';
  if (includesAny(normalizedText, ['cete', 'arkadas', 'liderlik', 'sosyal'])) return 'social';
  if (String(rawText ?? '').includes('?')) return 'question';
  return 'generic';
}

function isLikelyGameQuestion(normalizedText, rawText) {
  if (String(rawText ?? '').includes('?')) return true;
  if (includesAny(normalizedText, ['nasil', 'neden', 'niye', 'nedir', 'ne ise yarar', 'yardim', 'rehber'])) {
    return true;
  }
  return includesAny(normalizedText, [
    'oyun', 'gorev', 'pvp', 'saldiri', 'enerji', 'rutbe', 'seviye',
    'ekipman', 'envanter', 'cete', 'arkadas', 'liderlik', 'hapis', 'hastane',
    'mesaj kutusu', 'genel sohbet', 'cete sohbet',
  ]);
}

function buildKnowledgeAnswer(rawText, senderName) {
  const text = String(rawText ?? '').trim();
  const n = normalizeTrText(text);
  const from = String(senderName ?? '').trim() || 'patron';

  if (includesAny(n, ['rehber', 'nasil oynanir', 'baslangic', 'ilk ne yapmali', 'yeni baslayan'])) {
    return `${from}, hızlı rehber: önce görevle nakit/XP kas, ekipmanda 4 slotu doldur, enerjiyi bitirmeden PvP'ye de pay ayır, hapis/hastane riskini hesaba kat, sonra çete ve sosyal akışa gir.`;
  }

  if (includesAny(n, ['enerji', 'energy'])) {
    return `${from}, enerji oyunun temposunu belirler. Enerjin düşükse saldırı ve görev verimin düşer; görev ve PvP arasında dengeli tüketim en iyi yaklaşım.`;
  }

  if (includesAny(n, ['pvp', 'saldiri', 'baski', 'duello', 'intikam'])) {
    return `${from}, PvP'de yakın güçte hedef seçmek daha güvenli. Saldırı öncesi ekipman uyumu kritik; ayrıca enerjin yetmiyorsa saldırı planı aksar.`;
  }

  if (includesAny(n, ['saldiri penceresi', 'ustteki', 'alttaki', 'hedef secimi'])) {
    return `${from}, hedef seçimi güç penceresine göre olur; amaç adil eşleşme. Yakın güçte üst/alt rakiplerle oynamak en stabil ilerlemeyi verir.`;
  }

  if (includesAny(n, ['hapis', 'hapishane', 'hastane', 'yakalandim', 'hastanelik'])) {
    return `${from}, hapis veya hastanede geri sayım bitene kadar işlem yapamazsın: saldırı, görev ve benzeri aksiyonlar kilitlenir. Acil çıkış için altın seçeneği bulunur.`;
  }

  if (includesAny(n, ['gorev', 'soygun', 'operasyon'])) {
    return `${from}, görevler erken oyunda para+XP için en güvenli temel akıştır. Zorluk arttıkça ödül/risk de artar; enerjiyi tek noktada sıfırlama.`;
  }

  if (includesAny(n, ['ekipman', 'envanter', 'slot', 'silah', 'zirh', 'araba'])) {
    return `${from}, envanter sahip olduğun eşyaları tutar, ekipman ise aktif bonus aldığın loadout'tur. Aktif ekipmanda 4 slotu dolu tutmak savaş performansını ciddi yükseltir.`;
  }

  if (includesAny(n, ['stat', 'stat puani', 'guc nasil artar', 'rutbe nasil'])) {
    return `${from}, güç/rütbe artışı için üçlü döngü önemli: düzenli görev, doğru PvP eşleşmesi ve ekipman iyileştirmesi. Stat puanlarını rolüne göre dağıtman fark yaratır.`;
  }

  if (includesAny(n, ['seviye', 'rutbe', 'xp'])) {
    return `${from}, XP topladıkça seviye ve rütbe açılır. Düzensiz tek yön oynanış yerine görev+PvP+ekonomi dengesi daha hızlı seviyeletir.`;
  }

  if (includesAny(n, ['altin', 'nakit', 'para', 'ekonomi', 'sandik', 'kacakci'])) {
    return `${from}, altın ve nakiti aynı anda yönet: altın kritik durum/yükseltmeler için, nakit ise düzenli güçlenme için. Tüm kaynakları tek hamlede harcamak kırılgan bırakır.`;
  }

  if (includesAny(n, ['cete', 'cete kur', 'cete katil', 'davet', 'katilim istegi'])) {
    return `${from}, çete akışı: kur, davet et veya katılım isteği gönder; lider onayladığında üye olursun. Aktif çete koordinasyonu rank ve baskın verimini artırır.`;
  }

  if (includesAny(n, ['arkadas', 'arkadas ekle', 'arkadas cikar', 'oyuncu uid'])) {
    return `${from}, oyuncu UID ile arkadaş isteği atabilirsin; kabul sonrası listede görünür. İstediğinde arkadaş listesinden çıkarma işlemi de yapılabilir.`;
  }

  if (includesAny(n, ['mesaj kutusu', 'inbox', 'bildirim'])) {
    return `${from}, mesaj kutusunda arkadaşlık istekleri, çete davetleri ve savaş raporları toplanır. Böylece sosyal ve savaş olaylarını tek yerden takip edersin.`;
  }

  if (includesAny(n, ['genel sohbet', 'cete sohbet', 'sohbet'])) {
    return `${from}, genel sohbet herkese açıktır; çete sohbeti ise koordinasyon için daha odaklıdır. İki kanalı birlikte kullanmak strateji paylaşımını hızlandırır.`;
  }

  if (includesAny(n, ['liderlik', 'siralama', 'rank tablosu'])) {
    return `${from}, liderlik tablosu skor, güç ve performans metriklerine göre güncellenir. Düzenli aksiyon ve istikrarlı ekonomi üst sıralara çıkmanın anahtarıdır.`;
  }

  if (isLikelyGameQuestion(n, text)) {
    return `${from}, oyunla ilgili sorunu net cevaplayabilirim. Konuyu yaz: görev, PvP, ekipman, çete, ekonomi, hapis/hastane ya da rütbe sistemi.`;
  }

  return '';
}

function baseTopicReply(topic, from) {
  switch (topic) {
    case 'greet':
      return `${from} selam, hoş geldin. Bugün şehirde işler nasıl gidiyor?`;
    case 'energy':
      return `${from}, enerji bitince saldırı/görev yavaşlar. Enerjiyi görev ve PvP arasında dengeli harca.`;
    case 'pvp':
      return `${from}, PvP'de yakın güçte hedef seçmek daha güvenli. Önce ekipmanı tamamla, sonra saldır.`;
    case 'mission':
      return `${from}, görevleri peş peşe yaparken enerjiyi sıfırlama; bir kısmını PvP için sakla.`;
    case 'penalty':
      return `${from}, hapis/hastane süresinde işlem yapamazsın. Altınla çıkış acil durum için iyi.`;
    case 'economy':
      return `${from}, altını erken oyunda kritik yükseltmelere ayırmak uzun vadede daha güçlü yapar.`;
    case 'equipment':
      return `${from}, ekipmanda boş slot bırakma. 4 slot dolunca savaş sonucu ciddi değişir.`;
    case 'progression':
      return `${from}, rütbe için temel döngü: görev + PvP + ekipman iyileştirme.`;
    case 'social':
      return `${from}, aktif çete oyunu ciddi hızlandırır; koordinasyon fark yaratır.`;
    case 'question':
      return `${from}, güzel soru. En güvenli yöntem ekonomi, ekipman ve PvP dengesini bozmamak.`;
    default:
      return pickRandom([
        `İyi tempo ${from}. Bu gece şehir çok hareketli.`,
        `${from}, tek alana yüklenmek yerine döngüyü dengede tutmak daha kazançlı.`,
        `Tam gaz devam ${from}. Saldırıdan önce ekipmanı kontrol etmeyi unutma.`,
        `${from}, genel sohbette bilgi akışı iyi, takipte kal.`,
      ]) ?? `Devam ${from}, tempo iyi.`;
  }
}

function styleForTopic(profile, topic) {
  return (
    profile?.topicAddons?.[topic] ??
    profile?.topicAddons?.generic ??
    'Dengeyi koru, tempo kaybetme.'
  );
}

function maybePersonalityFollowUp(profile) {
  if (Math.random() > 0.55) return '';
  return String(pickRandom(profile?.followUps ?? []) ?? '').trim();
}

function buildGlobalChatReply(rawText, senderName, profile) {
  const text = String(rawText ?? '').trim();
  const normalized = normalizeTrText(text);
  const from = String(senderName ?? '').trim() || 'patron';
  const topic = detectGlobalTopic(text, normalized);
  const knowledge = buildKnowledgeAnswer(text, senderName);
  const core = knowledge || baseTopicReply(topic, from);
  const style = styleForTopic(profile, topic);
  const follow = maybePersonalityFollowUp(profile);
  const parts = knowledge
    ? [core, Math.random() < 0.7 ? style : '', Math.random() < 0.5 ? follow : '']
    : [core, style, follow];
  const safeParts = parts.filter((p) => hasText(p));
  return safeParts.join(' ');
}

function buildGlobalBotPrompt(profile, attackLogs) {
  const personaPrompts = Array.isArray(profile?.promptStyle)
    ? profile.promptStyle
    : [];
  if (Array.isArray(attackLogs) && attackLogs.length > 0 && Math.random() < 0.58) {
    const last = pickRandom(attackLogs);
    if (last?.outcome === 'win') {
      return `${pickRandom(personaPrompts) ?? 'Az önce baskından çıktım.'} ${last.targetName} üstünde baskın başarılı geçti, siz olsanız ganimeti nereye basarsınız?`;
    }
    if (last?.outcome === 'lose') {
      return `${pickRandom(personaPrompts) ?? 'Bir çatışmada düştüm.'} Kaybedince hemen rövanş mı alıyorsunuz yoksa güç mü topluyorsunuz?`;
    }
    return `${pickRandom(personaPrompts) ?? 'Berabere bitti.'} Beraberlikten sonra en iyi hamle sizce görev mi PvP mi?`;
  }
  const defaults = [
    'Biraz önce sert bir çatışmadan çıktım, sizce bugün en riskli bölge neresi?',
    'PvP penceresinde yakın güç hedef kovalamak mı daha iyi, yoksa görev farm mı?',
    'Hastane/hapis süresi uzayınca altınla çıkıyor musunuz yoksa bekliyor musunuz?',
    'Ekipman çapraz etkisini en çok hangi kombinasyonda hissediyorsunuz?',
  ];
  return pickRandom([...personaPrompts, ...defaults]) ?? 'Bu gece şehirde nabız yüksek, planınız ne?';
}

async function maybeReplyInGlobalChat(data) {
  const senderId = String(data?.senderId ?? '').trim();
  if (!senderId || isBotUid(senderId)) return;

  const text = String(data?.text ?? '').trim();
  if (!text || text.length < 2) return;

  const normalized = normalizeTrText(text);
  const directHelpAsked = isLikelyGameQuestion(normalized, text) || includesAny(normalized, [
    'yardim', 'nasil', 'niye', 'neden', 'bug', 'hata', 'nedir', 'ne ise yarar',
  ]);
  if (!directHelpAsked && Math.random() > 0.72) return;

  const senderWindow = await claimSenderReplyWindow(senderId, 45 * 1000);
  if (!senderWindow) return;

  const slotOk = await claimGlobalChatSlot('lastReplyAtMs', 9 * 1000);
  if (!slotOk) return;

  const bot = pickRandom(BOT_PLAYERS) ?? { id: 'bot_reis_tuna', name: 'Reis_Tuna' };
  const profile = resolveBotPersonality(bot);
  const senderName = String(data?.senderName ?? '').trim() || 'patron';
  const replyText = buildGlobalChatReply(text, senderName, profile);

  await db
    .collection('gang_chats')
    .doc(GLOBAL_CHAT_ROOM_ID)
    .collection('messages')
    .add({
      senderId: bot.id,
      senderName: bot.name,
      text: replyText,
      type: 'text',
      isRead: false,
      isBot: true,
      botPersonality: profile.key,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
}

async function maybePostGlobalBotPrompt(attackLogs) {
  if (Math.random() > 0.65) return;
  const slotOk = await claimGlobalChatSlot('lastPromptAtMs', 170 * 1000);
  if (!slotOk) return;
  const bot = pickRandom(BOT_PLAYERS) ?? { id: 'bot_reis_tuna', name: 'Reis_Tuna' };
  const profile = resolveBotPersonality(bot);
  const text = buildGlobalBotPrompt(profile, attackLogs);
  await db
    .collection('gang_chats')
    .doc(GLOBAL_CHAT_ROOM_ID)
    .collection('messages')
    .add({
      senderId: bot.id,
      senderName: bot.name,
      text,
      type: 'text',
      isRead: false,
      isBot: true,
      botPersonality: profile.key,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
}

exports.onAttackCreated = onDocumentCreated(
  'attacks/{attackId}',
  async (event) => {
    const attack = event.data?.data();
    if (!attack) return;
    const attackId = event.params.attackId;

    const { attackerId, targetId, outcome, stolenCash, type } = attack;

    const targetDoc = await db.collection('users').doc(targetId).get();
    const targetToken = targetDoc.data()?.fcmToken;
    const targetName = targetDoc.data()?.displayName ?? 'Oyuncu';

    const attackerDoc = await db.collection('users').doc(attackerId).get();
    const attackerName = attackerDoc.data()?.displayName ?? 'Biri';

    const { title, body } = buildMessage(
      outcome,
      attackerName,
      stolenCash,
      type,
    );

    if (targetToken) {
      await sendNotification(targetToken, title, body, {
        attackId,
        type: 'attacked',
        attackerId,
      });
    }

    const incomingBody = buildAttackReportBody(attack, 'incoming');
    const outgoingBody = buildAttackReportBody(attack, 'outgoing');
    const attackType = String(type ?? 'quick');
    const isGangAttack = attackType === 'gang';
    const attackerGangName = hasText(attack?.attackerGangName)
      ? String(attack.attackerGangName).trim()
      : '';
    const targetGangName = hasText(attack?.targetGangName)
      ? String(attack.targetGangName).trim()
      : '';
    const participantIds = Array.from(
      new Set(
        [
          String(attackerId ?? '').trim(),
          ...(Array.isArray(attack?.participantIds) ? attack.participantIds : []),
        ]
          .map((uid) => String(uid ?? '').trim())
          .filter((uid) => uid.length > 0),
      ),
    );
    const outgoingRecipients = isGangAttack
      ? participantIds
      : [String(attackerId ?? '').trim()];
    const incomingTitle = isGangAttack
      ? `${attackerGangName || attackerName} karteli baskın düzenledi`
      : `${attackerName} sana saldırdı`;
    const outgoingTitle = isGangAttack
      ? `${targetName} hedefine kartel baskını tamamlandı`
      : `${targetName} hedefine saldırı tamamlandı`;

    await writeInboxMessage(targetId, {
      type: 'attack_report',
      attackId,
      title: incomingTitle,
      body: incomingBody || body || attack.message || 'Saldırı raporu hazır.',
      attackerId,
      attackerName,
      outcome: String(outcome ?? 'draw'),
      stolenCash: Number(stolenCash ?? 0),
      attackType,
      atkTotal: Number(attack?.atkTotal ?? 0),
      defTotal: Number(attack?.defTotal ?? 0),
      xpGained: Number(attack?.xpGained ?? 0),
      attackerWeaponId: String(attack?.attackerWeaponId ?? ''),
      targetWeaponId: String(attack?.targetWeaponId ?? ''),
      attackerKnifeId: String(attack?.attackerKnifeId ?? ''),
      targetKnifeId: String(attack?.targetKnifeId ?? ''),
      attackerArmorId: String(attack?.attackerArmorId ?? ''),
      targetArmorId: String(attack?.targetArmorId ?? ''),
      attackerVehicleId: String(attack?.attackerVehicleId ?? ''),
      targetVehicleId: String(attack?.targetVehicleId ?? ''),
      weaponTotalPct: Number(attack?.weaponTotalPct ?? 0),
      knifePct: Number(attack?.knifePct ?? 0),
      armorPct: Number(attack?.armorPct ?? 0),
      vehiclePct: Number(attack?.vehiclePct ?? 0),
      loadoutTotalPct: Number(attack?.loadoutTotalPct ?? 0),
      attackerGangName,
      targetGangName,
      memberCount: Number(attack?.memberCount ?? 0),
      raidMemberNames: Array.isArray(attack?.raidMemberNames)
        ? attack.raidMemberNames
        : [],
      isGangRaid: isGangAttack,
      direction: 'incoming',
    });

    await Promise.all(
      outgoingRecipients.map((uid) => writeInboxMessage(uid, {
        type: 'attack_report',
        attackId,
        title: outgoingTitle,
        body: outgoingBody || String(attack.message ?? 'Saldırı raporu hazır.'),
        targetId,
        targetName,
        outcome: String(outcome ?? 'draw'),
        stolenCash: Number(stolenCash ?? 0),
        attackType,
        atkTotal: Number(attack?.atkTotal ?? 0),
        defTotal: Number(attack?.defTotal ?? 0),
        xpGained: Number(attack?.xpGained ?? 0),
        attackerWeaponId: String(attack?.attackerWeaponId ?? ''),
        targetWeaponId: String(attack?.targetWeaponId ?? ''),
        attackerKnifeId: String(attack?.attackerKnifeId ?? ''),
        targetKnifeId: String(attack?.targetKnifeId ?? ''),
        attackerArmorId: String(attack?.attackerArmorId ?? ''),
        targetArmorId: String(attack?.targetArmorId ?? ''),
        attackerVehicleId: String(attack?.attackerVehicleId ?? ''),
        targetVehicleId: String(attack?.targetVehicleId ?? ''),
        weaponTotalPct: Number(attack?.weaponTotalPct ?? 0),
        knifePct: Number(attack?.knifePct ?? 0),
        armorPct: Number(attack?.armorPct ?? 0),
        vehiclePct: Number(attack?.vehiclePct ?? 0),
        loadoutTotalPct: Number(attack?.loadoutTotalPct ?? 0),
        attackerGangName,
        targetGangName,
        memberCount: Number(attack?.memberCount ?? 0),
        raidMemberNames: Array.isArray(attack?.raidMemberNames)
          ? attack.raidMemberNames
          : [],
        isGangRaid: isGangAttack,
        direction: 'outgoing',
      })),
    );

    if (outcome === 'lose') {
      const attackerToken = attackerDoc.data()?.fcmToken;
      if (attackerToken) {
        await sendNotification(
          attackerToken,
          'Baskın başarısız!',
          `${targetName} seni hastaneye yolladı.`,
          { attackId, type: 'defeat' },
        );
      }
    }
  },
);

exports.onFriendRequestCreated = onDocumentCreated(
  'friend_requests/{requestId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const fromName = String(data.fromName ?? 'Bir oyuncu').trim() || 'Bir oyuncu';
    const toId = String(data.toId ?? '').trim();
    if (!toId) return;
    await writeInboxMessage(toId, {
      type: 'friend_request',
      title: 'Yeni arkadaşlık isteği',
      body: `${fromName} sana arkadaşlık isteği gönderdi.`,
      fromId: String(data.fromId ?? '').trim(),
      fromName,
      requestId: event.params.requestId,
      status: String(data.status ?? 'pending'),
    });
  },
);

exports.onGangJoinRequestCreated = onDocumentCreated(
  'gang_join_requests/{requestId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const leaderId = String(data.leaderId ?? '').trim();
    if (!leaderId) return;
    const fromName = String(data.fromName ?? 'Bir oyuncu').trim() || 'Bir oyuncu';
    const gangName = String(data.gangName ?? 'Çete').trim() || 'Çete';
    await writeInboxMessage(leaderId, {
      type: 'gang_join_request',
      title: 'Yeni çete katılım isteği',
      body: `${fromName}, ${gangName} çetesine katılmak istiyor.`,
      gangId: String(data.gangId ?? '').trim(),
      gangName,
      fromId: String(data.fromId ?? '').trim(),
      fromName,
      requestId: event.params.requestId,
      status: String(data.status ?? 'pending'),
    });
  },
);

exports.onGangInviteCreated = onDocumentCreated(
  'gang_invites/{inviteId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const toUid = String(data.toUid ?? '').trim();
    if (!toUid) return;
    const gangName = String(data.gangName ?? 'Çete').trim() || 'Çete';
    const leaderName = String(data.leaderName ?? 'Lider').trim() || 'Lider';
    await writeInboxMessage(toUid, {
      type: 'gang_invite',
      title: 'Çete daveti aldın',
      body: `${leaderName} seni ${gangName} çetesine davet etti.`,
      inviteId: event.params.inviteId,
      gangId: String(data.gangId ?? '').trim(),
      gangName,
      leaderId: String(data.leaderId ?? '').trim(),
      leaderName,
      status: String(data.status ?? 'pending'),
    });
  },
);

exports.onGangMessageCreated = onDocCreated(
  'gang_chats/{gangId}/messages/{msgId}',
  async (event) => {
    const data = event.data.data();
    const { gangId } = event.params;

    if (data.type === 'system') return;
    if (gangId === GLOBAL_CHAT_ROOM_ID) {
      await maybeReplyInGlobalChat(data);
      return;
    }

    // Fetch gang members from sub-collection
    const membersSnap = await db
      .collection('gangs')
      .doc(gangId)
      .collection('members')
      .get();

    const memberUids = membersSnap.docs
      .map((doc) => doc.id)
      .filter((uid) => uid !== data.senderId);

    const tokens = [];
    for (const uid of memberUids) {
      const p = await db.collection('users').doc(uid).get();
      const token = p.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    const gangDoc = await db.collection('gangs').doc(gangId).get();
    const gangName = gangDoc.data()?.name ?? 'Çete';
    const preview =
      data.text.length > 60 ? data.text.slice(0, 60) + '...' : data.text;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${gangName} — ${data.senderName}`,
        body: preview,
      },
      data: {
        type: 'gang_message',
        gangId,
      },
      android: {
        priority: 'normal',
        notification: { channelId: 'cartelhood_attacks' },
      },
    });
  },
);

exports.weeklyLeaderboardReset = onSchedule('0 0 * * 1', async () => {
  const batch = db.batch();
  const users = await db.collection('users').get();

  users.docs.forEach((doc) => {
    batch.update(doc.ref, {
      wins: 0,
      gangWins: 0,
      weeklyReset: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();
  console.log(`Haftalık sıfırlama tamamlandı: ${users.size} oyuncu`);
});

exports.executePvpAttack = onCall({ invoker: 'public' }, async (request) => {
  const attackerId = request.auth?.uid;
  if (!attackerId) {
    throw new HttpsError('unauthenticated', 'Giriş yapman gerekiyor');
  }

  const targetId = String(request.data?.targetId ?? '').trim();
  if (!targetId) {
    throw new HttpsError('invalid-argument', 'Hedef bulunamadı');
  }
  if (targetId === attackerId) {
    throw new HttpsError('invalid-argument', 'Kendine saldıramazsın');
  }

  const rawType = String(request.data?.type ?? 'quick').trim();
  const type = rawType === 'planned' ? 'planned' : 'quick';
  const equipmentBonus = type === 'planned' ? 15 : 0;

  const users = db.collection('users');
  const attackerRef = users.doc(attackerId);
  const targetRef = users.doc(targetId);
  const cooldownRef = db.collection('attack_cooldowns').doc(`${attackerId}_${targetId}`);

  const [attackerSnap, targetSnap] = await Promise.all([
    attackerRef.get(),
    targetRef.get(),
  ]);

  if (!attackerSnap.exists) {
    throw new HttpsError('failed-precondition', 'Saldıran oyuncu bulunamadı');
  }
  if (!targetSnap.exists) {
    throw new HttpsError('failed-precondition', 'Hedef bulunamadı');
  }

  const attackerData = attackerSnap.data() || {};
  const targetData = targetSnap.data() || {};

  const attackerLevelPrecheck = Math.max(1, Number(attackerData.level ?? 1));
  const profileAttackCostRaw = Number(attackerData.attackEnergyCost ?? NaN);
  const profileAttackCost = Number.isFinite(profileAttackCostRaw)
    ? Math.max(12, Math.min(20, Math.trunc(profileAttackCostRaw)))
    : null;
  const rookieAttackCostFloor = attackerLevelPrecheck <= 5 ? 8 : 12;
  const attackCost = Math.max(rookieAttackCostFloor, profileAttackCost ?? 20);

  const nowEpoch = Math.floor(Date.now() / 1000);
  const attackerStatus = resolvePenaltyStatus(attackerData, nowEpoch).status;
  const targetStatus = resolvePenaltyStatus(targetData, nowEpoch).status;
  if (attackerStatus === 'hospital' || attackerStatus === 'prison') {
    throw new HttpsError(
      'failed-precondition',
      `Şu an ${attackerStatus} durumundasın, saldıramazsın`,
    );
  }
  if (targetStatus === 'hospital' || targetStatus === 'prison') {
    throw new HttpsError(
      'failed-precondition',
      `Hedef şu an ${targetStatus}'de, saldırılamaz`,
    );
  }
  const targetShieldUntilEpoch = Math.max(0, Number(targetData.shieldUntilEpoch ?? 0));
  if (targetShieldUntilEpoch > nowEpoch) {
    const waitMin = Math.max(1, Math.ceil((targetShieldUntilEpoch - nowEpoch) / 60));
    throw new HttpsError(
      'failed-precondition',
      `Hedef koruma kalkanında. Yaklaşık ${waitMin} dakika bekle`,
    );
  }
  const attackerEnergy = Math.max(0, Number(attackerData.currentEnergy ?? 0));
  if (attackerEnergy < attackCost) {
    throw new HttpsError(
      'failed-precondition',
      `Saldırı için en az ${attackCost} enerji gerekli`,
    );
  }

  const attackerPower = Number(attackerData.power ?? 0);
  const targetPower = Number(targetData.power ?? 0);
  const attackWindow = await buildAttackWindow(attackerId, attackerPower);
  if (!isTargetInAttackWindow(targetId, targetPower, attackerPower, attackWindow)) {
    throw new HttpsError(
      'failed-precondition',
      'Sadece üstündeki 5 ve altındaki 5 oyuncuya saldırabilirsin',
    );
  }

  const nowDate = new Date();
  const result = await db.runTransaction(async (tx) => {
    const [atkTxSnap, targetTxSnap, coolTxSnap] = await Promise.all([
      tx.get(attackerRef),
      tx.get(targetRef),
      tx.get(cooldownRef),
    ]);

    if (!atkTxSnap.exists || !targetTxSnap.exists) {
      throw new HttpsError('failed-precondition', 'Saldırı için oyuncular bulunamadı');
    }

    const atkTxData = atkTxSnap.data() || {};
    const targetTxData = targetTxSnap.data() || {};

    const txNowEpoch = Math.floor(Date.now() / 1000);
    const atkTxStatus = resolvePenaltyStatus(atkTxData, txNowEpoch).status;
    const targetTxStatus = resolvePenaltyStatus(targetTxData, txNowEpoch).status;
    if (atkTxStatus === 'hospital' || atkTxStatus === 'prison') {
      throw new HttpsError(
        'failed-precondition',
        `Şu an ${atkTxStatus} durumundasın, saldıramazsın`,
      );
    }
    if (targetTxStatus === 'hospital' || targetTxStatus === 'prison') {
      throw new HttpsError(
        'failed-precondition',
        `Hedef şu an ${targetTxStatus}'de, saldırılamaz`,
      );
    }
    const txTargetShieldUntilEpoch = Math.max(0, Number(targetTxData.shieldUntilEpoch ?? 0));
    if (txTargetShieldUntilEpoch > txNowEpoch) {
      const waitMin = Math.max(1, Math.ceil((txTargetShieldUntilEpoch - txNowEpoch) / 60));
      throw new HttpsError(
        'failed-precondition',
        `Hedef koruma kalkanında. Yaklaşık ${waitMin} dakika bekle`,
      );
    }
    const attackerLevel = Math.max(1, Number(atkTxData.level ?? 1));
    const atkAttackCostRaw = Number(atkTxData.attackEnergyCost ?? NaN);
    const atkAttackCostFloor = attackerLevel <= 5 ? 8 : 12;
    const atkAttackCost = Number.isFinite(atkAttackCostRaw)
      ? Math.max(atkAttackCostFloor, Math.min(20, Math.trunc(atkAttackCostRaw)))
      : attackCost;
    const atkEnergy = Math.max(0, Number(atkTxData.currentEnergy ?? 0));
    if (atkEnergy < atkAttackCost) {
      throw new HttpsError(
        'failed-precondition',
        `Saldırı için en az ${atkAttackCost} enerji gerekli`,
      );
    }

    const lastAttackRequestAtEpoch = Math.max(0, Number(atkTxData.lastAttackRequestAtEpoch ?? 0));
    if ((txNowEpoch - lastAttackRequestAtEpoch) < 3) {
      throw new HttpsError(
        'resource-exhausted',
        'Çok hızlı işlem yapıyorsun, 2-3 saniye bekle',
      );
    }

    if (coolTxSnap.exists) {
      const lastAttackTs = coolTxSnap.data()?.lastAttack;
      if (lastAttackTs?.toDate) {
        const diffMs = nowDate.getTime() - lastAttackTs.toDate().getTime();
        if (diffMs < 5 * 60 * 1000) {
          const waitMin = Math.max(1, Math.ceil((5 * 60 * 1000 - diffMs) / 60000));
          throw new HttpsError(
            'failed-precondition',
            `Tekrar saldırmak için ${waitMin} dakika bekle`,
          );
        }
      }
    }

    tx.update(attackerRef, {
      currentEnergy: admin.firestore.FieldValue.increment(-atkAttackCost),
      lastAttackRequestAtEpoch: txNowEpoch,
    });

    const attackerDisplayName = safeText(
      atkTxData.displayName ?? atkTxData.name,
      'Bilinmiyor',
      24,
    );
    const targetDisplayName = safeText(
      targetTxData.displayName ?? targetTxData.name,
      'Bilinmiyor',
      24,
    );

    const atkPower = Math.max(1, Number(atkTxData.power ?? 1));
    const defPower = Math.max(1, Number(targetTxData.power ?? 1));
    const attackerLoadout = resolveLoadout(atkTxData, atkPower);
    const targetLoadout = resolveLoadout(targetTxData, defPower);
    const attackerWeaponName = weaponLabelTr(attackerLoadout.weaponId);
    const targetWeaponName = weaponLabelTr(targetLoadout.weaponId);
    const attackerKnifeName = weaponLabelTr(attackerLoadout.knifeId);
    const targetKnifeName = weaponLabelTr(targetLoadout.knifeId);
    const attackerArmorName = armorLabelTr(attackerLoadout.armorId);
    const targetArmorName = armorLabelTr(targetLoadout.armorId);
    const attackerVehicleName = vehicleLabelTr(attackerLoadout.vehicleId);
    const targetVehicleName = vehicleLabelTr(targetLoadout.vehicleId);
    const attackerMatchup = computeLoadoutMatchup(attackerLoadout, targetLoadout);
    const defenderMatchup = computeLoadoutMatchup(targetLoadout, attackerLoadout);
    const atkRoll = randomInt(atkPower / 5);
    const defRoll = randomInt(defPower / 5);

    const atkBaseWithEquipment = atkPower + Math.trunc((atkPower * equipmentBonus) / 100);
    const rookieCombatBoostPct = attackerLevel <= 5 ? 30 : 0;
    const atkTotal =
      applyPercent(
        atkBaseWithEquipment,
        attackerMatchup.loadoutTotalPct + rookieCombatBoostPct,
      ) + atkRoll;
    const defTotal = applyPercent(defPower, defenderMatchup.loadoutTotalPct) + defRoll;

    const diff = Math.abs(atkTotal - defTotal);
    const rookieDrawBufferPct = attackerLevel <= 5 ? 0.18 : 0.1;
    const drawThreshold = Math.trunc(defTotal * rookieDrawBufferPct);
    let outcome = 'draw';
    if (diff > drawThreshold) {
      outcome = atkTotal > defTotal ? 'win' : 'lose';
    }
    if (attackerLevel <= 5 && outcome === 'lose') {
      // Seviye 1-5 oyuncular için sokak akışını yumuşat:
      // ağır yenilgi yerine beraberlik.
      outcome = 'draw';
    }

    let stolenCash = 0;
    let xpGained = 0;
    let message = '';
    const penaltyEndDate = new Date(
      nowDate.getTime() + HOSPITAL_PENALTY_SEC * 1000,
    );
    const penaltyShieldUntilEpoch = Math.floor((penaltyEndDate.getTime() + 5 * 60 * 1000) / 1000);

    if (outcome === 'win') {
      const targetCash = Math.max(0, Number(targetTxData.cash ?? 0));
      const baseStolenCash = Math.min(50000, Math.max(50, Math.trunc(targetCash * 0.1)));
      const lootMultiplier = atkPower <= defPower
        ? 1
        : Math.max(0.25, Math.min(1, (defPower / atkPower) * 1.15));
      stolenCash = Math.max(25, Math.trunc(baseStolenCash * lootMultiplier));
      xpGained = 30 + (type === 'planned' ? 20 : 0);

      tx.update(attackerRef, {
        cash: admin.firestore.FieldValue.increment(stolenCash),
        xp: admin.firestore.FieldValue.increment(xpGained),
      });
      tx.update(targetRef, {
        cash: admin.firestore.FieldValue.increment(-stolenCash),
        status: 'hospital',
        statusUntil: admin.firestore.Timestamp.fromDate(
          penaltyEndDate,
        ),
        statusUntilEpoch: Math.floor(penaltyEndDate.getTime() / 1000),
        shieldUntilEpoch: penaltyShieldUntilEpoch,
      });
      message =
        `Rakibi devirdin! ${stolenCash} nakit çaldın. ` +
        `[${attackerWeaponName} vs ${targetWeaponName} | ` +
        `Silah %${signedPct(attackerMatchup.weaponTotalPct)} | ` +
        `Yakın %${signedPct(attackerMatchup.knifePct)} | ` +
        `Zırh %${signedPct(attackerMatchup.armorPct)} | ` +
        `Araç %${signedPct(attackerMatchup.vehiclePct)}]`;
    } else if (outcome === 'lose') {
      tx.update(attackerRef, {
        status: 'hospital',
        statusUntil: admin.firestore.Timestamp.fromDate(
          penaltyEndDate,
        ),
        statusUntilEpoch: Math.floor(penaltyEndDate.getTime() / 1000),
        shieldUntilEpoch: penaltyShieldUntilEpoch,
      });
      message =
        `Mağlup oldun! Hastaneye kaldırıldın. ` +
        `[${attackerWeaponName} vs ${targetWeaponName} | ` +
        `Toplam ekipman etkisi %${signedPct(attackerMatchup.loadoutTotalPct)}]`;
    } else {
      message = attackerLevel <= 5
        ? (
          `Geri çekildin ama toparlandın. ` +
          `[${attackerWeaponName} vs ${targetWeaponName}]`
        )
        : (
          `Berabere! Her iki taraf da hafif yaralı. ` +
          `[${attackerWeaponName} vs ${targetWeaponName}]`
        );
    }

    const attackRef = db.collection('attacks').doc();
    tx.set(cooldownRef, { lastAttack: admin.firestore.Timestamp.now() });
    tx.set(attackRef, {
      attackerId,
      targetId,
      attackerName: attackerDisplayName,
      targetName: targetDisplayName,
      type,
      outcome,
      attackCost: atkAttackCost,
      stolenCash,
      xpGained,
      atkTotal,
      defTotal,
      attackerPower: atkPower,
      targetPower: defPower,
      attackerWeaponId: attackerLoadout.weaponId,
      targetWeaponId: targetLoadout.weaponId,
      attackerKnifeId: attackerLoadout.knifeId,
      targetKnifeId: targetLoadout.knifeId,
      attackerArmorId: attackerLoadout.armorId,
      targetArmorId: targetLoadout.armorId,
      attackerVehicleId: attackerLoadout.vehicleId,
      targetVehicleId: targetLoadout.vehicleId,
      weaponPowerPct: attackerMatchup.weaponPowerPct,
      weaponSpeedPct: attackerMatchup.weaponSpeedPct,
      weaponTotalPct: attackerMatchup.weaponTotalPct,
      knifePct: attackerMatchup.knifePct,
      armorPct: attackerMatchup.armorPct,
      vehiclePct: attackerMatchup.vehiclePct,
      loadoutTotalPct: attackerMatchup.loadoutTotalPct,
      timestamp: admin.firestore.Timestamp.now(),
    });

    return {
      outcome,
      attackerName: attackerDisplayName,
      targetName: targetDisplayName,
      stolenCash,
      xpGained,
      message,
      attackCost: atkAttackCost,
      remainingEnergy: Math.max(0, atkEnergy - atkAttackCost),
      atkTotal,
      defTotal,
      attackerWeaponName,
      targetWeaponName,
      attackerKnifeName,
      targetKnifeName,
      attackerArmorName,
      targetArmorName,
      attackerVehicleName,
      targetVehicleName,
      weaponPowerPct: attackerMatchup.weaponPowerPct,
      weaponSpeedPct: attackerMatchup.weaponSpeedPct,
      weaponTotalPct: attackerMatchup.weaponTotalPct,
      knifePct: attackerMatchup.knifePct,
      armorPct: attackerMatchup.armorPct,
      vehiclePct: attackerMatchup.vehiclePct,
      loadoutTotalPct: attackerMatchup.loadoutTotalPct,
    };
  });

  return result;
});

// ══════════════════════════════════════════════════════════════════
// Gang Raid — Server-authoritative gang vs gang combat
// ══════════════════════════════════════════════════════════════════
exports.executeGangRaid = onCall({ invoker: 'public' }, async (request) => {
  const leaderId = request.auth?.uid;
  if (!leaderId) {
    throw new HttpsError('unauthenticated', 'Giriş yapman gerekiyor');
  }

  const raidId = String(request.data?.raidId ?? '').trim();
  if (!raidId) {
    throw new HttpsError('invalid-argument', 'Raid ID gerekli');
  }

  const raidRef = db.collection('gang_raids').doc(raidId);
  const raidSnap = await raidRef.get();

  if (!raidSnap.exists) {
    throw new HttpsError('not-found', 'Raid bulunamadı');
  }

  const raidData = raidSnap.data();

  if (raidData.leaderId !== leaderId) {
    throw new HttpsError('permission-denied', 'Sadece lider baskını başlatabilir');
  }

  if (raidData.status === 'completed' || raidData.status === 'started') {
    throw new HttpsError('failed-precondition', 'Bu baskın zaten başlamış veya bitmiş');
  }

  const members = raidData.members || [];
  if (members.length < 2) {
    throw new HttpsError('failed-precondition', 'En az 2 kişi gerekli');
  }

  const targetId = raidData.targetId;
  if (!targetId) {
    throw new HttpsError('invalid-argument', 'Hedef belirtilmemiş');
  }

  // Fetch all member data + target data
  const memberRefs = members.map((uid) => db.collection('users').doc(uid));
  const targetRef = db.collection('users').doc(targetId);

  const memberSnaps = await Promise.all(memberRefs.map((ref) => ref.get()));
  const targetSnap = await targetRef.get();

  if (!targetSnap.exists) {
    throw new HttpsError('failed-precondition', 'Hedef oyuncu bulunamadı');
  }

  const targetData = targetSnap.data() || {};

  // Check target is not in hospital/prison
  const targetStatus = resolvePenaltyStatus(targetData).status;
  if (targetStatus === 'hospital' || targetStatus === 'prison') {
    throw new HttpsError(
      'failed-precondition',
      `Hedef şu an ${targetStatus}'de, saldırılamaz`,
    );
  }

  // Check members are not hospitalized/jailed
  let totalAttackerPower = 0;
  const validMembers = [];
  for (const snap of memberSnaps) {
    if (!snap.exists) continue;
    const d = snap.data() || {};
    const st = resolvePenaltyStatus(d).status;
    if (st === 'hospital' || st === 'prison') continue;
    totalAttackerPower += Math.max(1, Number(d.power ?? 1));
    validMembers.push({ uid: snap.id, ref: snap.ref, data: d });
  }

  if (validMembers.length < 2) {
    throw new HttpsError(
      'failed-precondition',
      'Yeterli aktif üye yok (en az 2 gerekli)',
    );
  }

  const leaderMember = validMembers.find((m) => m.uid === leaderId) || validMembers[0];
  const attackerGangId = safeText(leaderMember?.data?.gangId, '', 64);
  const attackerGangName = safeText(leaderMember?.data?.gangName, '', 48);
  const targetGangId = safeText(targetData.gangId, '', 64);
  const targetGangName = safeText(targetData.gangName, '', 48);
  const raidMemberIds = validMembers
    .map((m) => String(m.uid ?? '').trim())
    .filter((uid) => uid.length > 0);
  const raidMemberNames = validMembers
    .map((m) => safeText(m?.data?.displayName ?? m?.data?.name ?? m.uid, m.uid, 24))
    .filter((name) => hasText(name));

  const targetPower = Math.max(1, Number(targetData.power ?? 1));

  // Gang raid combat calculation
  const memberBonus = (validMembers.length - 1) * 10; // %10 per extra member
  const boostedPower = totalAttackerPower + Math.trunc(totalAttackerPower * memberBonus / 100);

  const atkRoll = randomInt(boostedPower / 5);
  const defRoll = randomInt(targetPower / 5);
  const atkTotal = boostedPower + atkRoll;
  const defTotal = targetPower + defRoll;

  let outcome;
  if (atkTotal > defTotal * 1.05) {
    outcome = 'win';
  } else if (atkTotal < defTotal * 0.95) {
    outcome = 'lose';
  } else {
    outcome = 'draw';
  }

  const nowDate = new Date();
  const hospitalUntil = admin.firestore.Timestamp.fromDate(
    new Date(nowDate.getTime() + HOSPITAL_PENALTY_SEC * 1000),
  );
  const hospitalUntilEpoch = Math.floor(
    (nowDate.getTime() + HOSPITAL_PENALTY_SEC * 1000) / 1000,
  );
  const prisonUntil = admin.firestore.Timestamp.fromDate(
    new Date(nowDate.getTime() + PRISON_PENALTY_SEC * 1000),
  );
  const prisonUntilEpoch = Math.floor(
    (nowDate.getTime() + PRISON_PENALTY_SEC * 1000) / 1000,
  );
  const hospitalShieldUntilEpoch = Math.floor(
    (nowDate.getTime() + (HOSPITAL_PENALTY_SEC + 5 * 60) * 1000) / 1000,
  );
  const prisonShieldUntilEpoch = Math.floor(
    (nowDate.getTime() + (PRISON_PENALTY_SEC + 5 * 60) * 1000) / 1000,
  );

  const batch = db.batch();
  let stolenCash = 0;
  let xpGained = 0;
  let message = '';

  if (outcome === 'win') {
    const targetCash = Math.max(0, Number(targetData.cash ?? 0));
    const totalStolen = Math.min(100000, Math.max(100, Math.trunc(targetCash * 0.15)));
    stolenCash = Math.trunc(totalStolen / validMembers.length);
    xpGained = 50;

    for (const m of validMembers) {
      batch.update(m.ref, {
        cash: admin.firestore.FieldValue.increment(stolenCash),
        xp: admin.firestore.FieldValue.increment(xpGained),
      });
    }
    batch.update(targetRef, {
      cash: admin.firestore.FieldValue.increment(-totalStolen),
      status: 'prison',
      statusUntil: prisonUntil,
      statusUntilEpoch: prisonUntilEpoch,
      shieldUntilEpoch: prisonShieldUntilEpoch,
    });
    message = `Çete baskını başarılı! Kişi başı $${stolenCash} kazandınız.`;
  } else if (outcome === 'lose') {
    // Only leader goes to hospital
    batch.update(db.collection('users').doc(leaderId), {
      status: 'hospital',
      statusUntil: hospitalUntil,
      statusUntilEpoch: hospitalUntilEpoch,
      shieldUntilEpoch: hospitalShieldUntilEpoch,
    });
    message = 'Baskın başarısız! Lider hastaneye kaldırıldı.';
  } else {
    message = 'Berabere! Hedef kaçmayı başardı.';
  }

  // Update raid status
  batch.update(raidRef, {
    status: 'completed',
    outcome,
    stolenCash,
    xpGained,
    completedAt: admin.firestore.Timestamp.now(),
  });

  // Create attack record for history
  const attackRef = db.collection('attacks').doc();
  batch.set(attackRef, {
    attackerId: leaderId,
    targetId,
    attackerName: validMembers[0]?.data?.displayName || 'Çete',
    targetName: targetData.displayName || 'Bilinmiyor',
    type: 'gang',
    outcome,
    stolenCash: stolenCash * validMembers.length,
    xpGained,
    atkTotal,
    defTotal,
    raidId,
    memberCount: validMembers.length,
    participantIds: raidMemberIds,
    raidMemberNames,
    attackerGangId,
    attackerGangName,
    targetGangId,
    targetGangName,
    timestamp: admin.firestore.Timestamp.now(),
  });

  await batch.commit();

  // Send notifications
  const targetToken = targetData.fcmToken;
  if (targetToken && outcome === 'win') {
    await sendNotification(
      targetToken,
      'Çete Baskını!',
      `Bir çete sana baskın düzenledi ve $${stolenCash * validMembers.length} çaldı!`,
      { type: 'gang_raid', raidId },
    );
  }

  return {
    outcome,
    stolenCash,
    xpGained,
    message,
    atkTotal,
    defTotal,
    memberCount: validMembers.length,
  };
});

// ══════════════════════════════════════════════════════════════════
// Trade — Server-authoritative item/cash trading
// ══════════════════════════════════════════════════════════════════
exports.executeTrade = onCall({ invoker: 'public' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Giriş yapman gerekiyor');
  }

  const offerId = String(request.data?.offerId ?? '').trim();
  const action = String(request.data?.action ?? '').trim(); // 'accept' or 'reject'

  if (!offerId) {
    throw new HttpsError('invalid-argument', 'Teklif ID gerekli');
  }
  if (!['accept', 'reject'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Geçersiz işlem');
  }

  const offerRef = db.collection('trade_offers').doc(offerId);

  const result = await db.runTransaction(async (tx) => {
    const offerSnap = await tx.get(offerRef);
    if (!offerSnap.exists) {
      throw new HttpsError('not-found', 'Teklif bulunamadı');
    }

    const offer = offerSnap.data();
    if (offer.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Bu teklif artık geçerli değil');
    }
    if (offer.toId !== uid) {
      throw new HttpsError('permission-denied', 'Bu teklif sana yöneltilmemiş');
    }

    if (action === 'reject') {
      tx.update(offerRef, { status: 'rejected' });
      return { success: true, action: 'rejected' };
    }

    // Accept trade — validate both parties have the items/cash
    const fromRef = db.collection('users').doc(offer.fromId);
    const toRef = db.collection('users').doc(offer.toId);
    const fromSaveRef = db.collection('user_saves').doc(offer.fromId);
    const toSaveRef = db.collection('user_saves').doc(offer.toId);

    const [fromSnap, toSnap] = await Promise.all([
      tx.get(fromRef),
      tx.get(toRef),
    ]);

    if (!fromSnap.exists || !toSnap.exists) {
      throw new HttpsError('failed-precondition', 'Oyunculardan biri bulunamadı');
    }

    const fromData = fromSnap.data() || {};
    const toData = toSnap.data() || {};

    const offerCash = Number(offer.offerCash ?? 0);
    const requestCash = Number(offer.requestCash ?? 0);

    // Check sender has enough cash
    if (offerCash > 0 && (Number(fromData.cash ?? 0) < offerCash)) {
      tx.update(offerRef, { status: 'failed' });
      throw new HttpsError('failed-precondition', 'Gönderenin yeterli nakiti yok');
    }

    // Check receiver has enough cash
    if (requestCash > 0 && (Number(toData.cash ?? 0) < requestCash)) {
      tx.update(offerRef, { status: 'failed' });
      throw new HttpsError('failed-precondition', 'Senin yeterli nakitin yok');
    }

    // Transfer cash
    if (offerCash > 0) {
      tx.update(fromRef, { cash: admin.firestore.FieldValue.increment(-offerCash) });
      tx.update(toRef, { cash: admin.firestore.FieldValue.increment(offerCash) });
    }
    if (requestCash > 0) {
      tx.update(toRef, { cash: admin.firestore.FieldValue.increment(-requestCash) });
      tx.update(fromRef, { cash: admin.firestore.FieldValue.increment(requestCash) });
    }

    tx.update(offerRef, {
      status: 'accepted',
      completedAt: admin.firestore.Timestamp.now(),
    });

    return {
      success: true,
      action: 'accepted',
      offerCash,
      requestCash,
    };
  });

  return result;
});

// ══════════════════════════════════════════════════════════════════
// Gang Leaderboard — Weekly gang power ranking update
// ══════════════════════════════════════════════════════════════════
exports.updateGangLeaderboard = onSchedule('0 */6 * * *', async () => {
  const gangsSnap = await db.collection('gangs').get();
  const batch = db.batch();

  for (const gangDoc of gangsSnap.docs) {
    const gangData = gangDoc.data() || {};
    const membersSnap = await gangDoc.ref.collection('members').get();

    let totalPower = 0;
    let memberCount = 0;

    for (const m of membersSnap.docs) {
      const userSnap = await db.collection('users').doc(m.id).get();
      if (userSnap.exists) {
        totalPower += Math.max(0, Number(userSnap.data()?.power ?? 0));
        memberCount++;
      }
    }

    const respectPoints = Number(gangData.respectPoints ?? 0);
    const vault = Number(gangData.vault ?? 0);

    batch.set(db.collection('gang_leaderboard').doc(gangDoc.id), {
      name: gangData.name || 'Çete',
      ownerId: gangData.ownerId || '',
      totalPower,
      memberCount,
      respectPoints,
      vault,
      updatedAt: admin.firestore.Timestamp.now(),
    });
  }

  await batch.commit();
  console.log(`Gang leaderboard güncellendi: ${gangsSnap.size} çete`);
});

const WEAPON_ARCHETYPE_BY_ID = {
  musta: 'melee',
  caki: 'melee',
  sopa: 'melee',
  pala: 'melee',
  tabanca_9mm: 'pistol',
  altin_deagle: 'pistol',
  altipatlar: 'pistol',
  uzi: 'smg',
  pompali: 'shotgun',
  ak47: 'rifle',
  keskin_nisanci: 'sniper',
  el_bombasi: 'explosive',
  c4_patlayici: 'explosive',
  roketatar: 'explosive',
};

const WEAPON_LABEL_TR = {
  musta: 'Demir Muşta',
  caki: 'Kelebek Çakı',
  sopa: 'Çivili Sopa',
  pala: 'Paslı Pala',
  tabanca_9mm: '9mm Tabanca',
  altin_deagle: 'Altın Çöl Kartalı',
  altipatlar: 'Magnum Altıpatlar',
  uzi: 'Uzi',
  pompali: 'Pompalı Tüfek',
  ak47: 'AK-47 Kalaşnikof',
  keskin_nisanci: 'Sniper Tüfeği',
  el_bombasi: 'El Bombası Seti',
  c4_patlayici: 'C4 Patlayıcı',
  roketatar: 'RPG-7 Roketatar',
};

const ARMOR_ARCHETYPE_BY_ID = {
  deri_ceket: 'leather',
  celik_yelek: 'steel',
  juggernaut: 'heavy',
};

const ARMOR_LABEL_TR = {
  deri_ceket: 'Kalın Deri Ceket',
  celik_yelek: 'Polis Çelik Yeleği',
  juggernaut: 'Ağır Juggernaut Zırhı',
};

const VEHICLE_ARCHETYPE_BY_ID = {
  klasik_araba_sv1: 'sedan',
};

const VEHICLE_LABEL_TR = {
  klasik_araba_sv1: 'Klasik Araba',
};

const ARCHETYPE_SPEED = {
  unarmed: 5,
  melee: 8,
  pistol: 7,
  smg: 9,
  shotgun: 4,
  rifle: 6,
  sniper: 3,
  explosive: 2,
};

const MATCHUP_ADVANTAGE = {
  unarmed: { sniper: 6, explosive: 8, shotgun: -10, smg: -8 },
  melee: {
    pistol: 8,
    rifle: 6,
    sniper: 10,
    shotgun: -8,
    smg: -10,
    explosive: 12,
  },
  pistol: {
    melee: -6,
    smg: -5,
    rifle: 5,
    shotgun: 3,
    sniper: 8,
    explosive: 9,
  },
  smg: {
    melee: 7,
    pistol: 5,
    shotgun: -7,
    rifle: -4,
    sniper: 9,
    explosive: 11,
  },
  shotgun: {
    melee: 9,
    smg: 6,
    pistol: -4,
    rifle: -6,
    sniper: 8,
    explosive: 10,
  },
  rifle: {
    pistol: -5,
    shotgun: 6,
    smg: 4,
    melee: -7,
    sniper: -3,
    explosive: 8,
  },
  sniper: {
    rifle: 4,
    shotgun: -8,
    smg: -9,
    pistol: -6,
    melee: -10,
    explosive: 6,
  },
  explosive: {
    shotgun: 2,
    rifle: -8,
    sniper: -7,
    smg: -10,
    pistol: -9,
    melee: -12,
  },
};

const KNIFE_TIER = { musta: 1, caki: 2, sopa: 3, pala: 4 };
const ARMOR_RESIST = { none: 0, leather: 3, steel: 7, heavy: 12 };
const VEHICLE_MOBILITY = { none: 0, sedan: 3, armored: 1, sport: 5 };
const VEHICLE_COVER = { none: 0, sedan: 2, armored: 5, sport: 1 };
const WEAPON_PENETRATION = {
  unarmed: 0,
  melee: 2,
  pistol: 4,
  smg: 5,
  shotgun: 6,
  rifle: 7,
  sniper: 9,
  explosive: 10,
};

function defaultWeaponIdForPower(power) {
  if (power >= 10000) return 'roketatar';
  if (power >= 5000) return 'c4_patlayici';
  if (power >= 900) return 'keskin_nisanci';
  if (power >= 650) return 'ak47';
  if (power >= 420) return 'pompali';
  if (power >= 260) return 'uzi';
  if (power >= 140) return 'tabanca_9mm';
  if (power >= 70) return 'pala';
  if (power >= 30) return 'sopa';
  if (power >= 14) return 'caki';
  return 'musta';
}

function defaultKnifeIdForPower(power) {
  if (power >= 140) return 'pala';
  if (power >= 80) return 'sopa';
  if (power >= 40) return 'caki';
  return 'musta';
}

function defaultArmorIdForPower(power) {
  if (power >= 3000) return 'juggernaut';
  if (power >= 240) return 'celik_yelek';
  if (power >= 20) return 'deri_ceket';
  return '';
}

function defaultVehicleIdForPower(power) {
  if (power >= 180) return 'klasik_araba_sv1';
  return '';
}

function resolveLoadout(userData, power) {
  const weaponId =
    String(userData.combatWeaponId ?? '').trim() ||
    String(userData.equippedWeaponId ?? '').trim() ||
    defaultWeaponIdForPower(power);
  const knifeId =
    String(userData.equippedKnifeId ?? '').trim() || defaultKnifeIdForPower(power);
  const armorId =
    String(userData.equippedArmorId ?? '').trim() || defaultArmorIdForPower(power);
  const vehicleId =
    String(userData.equippedVehicleId ?? '').trim() || defaultVehicleIdForPower(power);
  return { weaponId, knifeId, armorId, vehicleId };
}

function resolveArchetype(weaponId) {
  return WEAPON_ARCHETYPE_BY_ID[String(weaponId ?? '').trim()] || 'unarmed';
}

function computeWeaponMatchup(attackerWeaponId, targetWeaponId) {
  const attackerArchetype = resolveArchetype(attackerWeaponId);
  const targetArchetype = resolveArchetype(targetWeaponId);
  const powerPct = MATCHUP_ADVANTAGE[attackerArchetype]?.[targetArchetype] ?? 0;
  const speedDiff =
    (ARCHETYPE_SPEED[attackerArchetype] ?? 5) -
    (ARCHETYPE_SPEED[targetArchetype] ?? 5);
  const speedPct = clamp(Math.trunc(speedDiff * 2), -8, 8);
  const totalPct = clamp(powerPct + speedPct, -20, 20);
  return { powerPct, speedPct, totalPct, attackerArchetype };
}

function computeLoadoutMatchup(attacker, target) {
  const attackerPrimary = attacker.weaponId || attacker.knifeId;
  const targetPrimary = target.weaponId || target.knifeId;
  const weaponEffect = computeWeaponMatchup(attackerPrimary, targetPrimary);

  const knifePct = clamp(
    ((KNIFE_TIER[attacker.knifeId] ?? 0) - (KNIFE_TIER[target.knifeId] ?? 0)) * 2,
    -8,
    8,
  );

  const attackerPen =
    (WEAPON_PENETRATION[weaponEffect.attackerArchetype] ?? 0) +
    (KNIFE_TIER[attacker.knifeId] ?? 0);
  const targetArmorType = ARMOR_ARCHETYPE_BY_ID[target.armorId] || 'none';
  const targetVehicleType = VEHICLE_ARCHETYPE_BY_ID[target.vehicleId] || 'none';
  const defenderMitigation =
    (ARMOR_RESIST[targetArmorType] ?? 0) + (VEHICLE_COVER[targetVehicleType] ?? 0);
  const armorPct = clamp(attackerPen - defenderMitigation, -12, 12);

  const attackerVehicleType = VEHICLE_ARCHETYPE_BY_ID[attacker.vehicleId] || 'none';
  const vehiclePct = clamp(
    ((VEHICLE_MOBILITY[attackerVehicleType] ?? 0) -
      (VEHICLE_MOBILITY[targetVehicleType] ?? 0)) * 2,
    -8,
    8,
  );

  const totalPct = clamp(
    weaponEffect.totalPct + knifePct + armorPct + vehiclePct,
    -35,
    35,
  );

  return {
    weaponPowerPct: weaponEffect.powerPct,
    weaponSpeedPct: weaponEffect.speedPct,
    weaponTotalPct: weaponEffect.totalPct,
    knifePct,
    armorPct,
    vehiclePct,
    loadoutTotalPct: totalPct,
  };
}

function weaponLabelTr(weaponId) {
  return WEAPON_LABEL_TR[String(weaponId ?? '').trim()] || 'Çıplak El';
}

function armorLabelTr(armorId) {
  if (!String(armorId ?? '').trim()) return 'Yok';
  return ARMOR_LABEL_TR[String(armorId ?? '').trim()] || 'Yok';
}

function vehicleLabelTr(vehicleId) {
  if (!String(vehicleId ?? '').trim()) return 'Yok';
  return VEHICLE_LABEL_TR[String(vehicleId ?? '').trim()] || 'Yok';
}

function applyPercent(value, pct) {
  return Math.max(1, Math.trunc((value * (100 + pct)) / 100));
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function signedPct(value) {
  return value > 0 ? `+${value}` : `${value}`;
}

function hasText(value) {
  return String(value ?? '').trim().length > 0;
}

async function buildAttackWindow(attackerId, attackerPower) {
  const users = db.collection('users');
  const [strongerSnap, weakerSnap] = await Promise.all([
    users
      .where('power', '>', attackerPower)
      .orderBy('power')
      .limit(5)
      .get(),
    users
      .where('power', '<', attackerPower)
      .orderBy('power', 'desc')
      .limit(5)
      .get(),
  ]);

  return {
    strongerIds: strongerSnap.docs
      .map((d) => d.id)
      .filter((id) => id !== attackerId),
    weakerIds: weakerSnap.docs
      .map((d) => d.id)
      .filter((id) => id !== attackerId),
  };
}

function isTargetInAttackWindow(targetId, targetPower, attackerPower, window) {
  const atk = Number(attackerPower ?? 0);
  const tgt = Number(targetPower ?? 0);
  if (!Number.isFinite(atk) || !Number.isFinite(tgt)) return false;
  const allowed = new Set([
    ...(Array.isArray(window?.strongerIds) ? window.strongerIds : []),
    ...(Array.isArray(window?.weakerIds) ? window.weakerIds : []),
  ]);
  return allowed.has(String(targetId ?? '').trim());
}

function randomInt(maxFloat) {
  const max = Math.max(0, Math.trunc(maxFloat));
  return Math.floor(Math.random() * (max + 1));
}

function withinPowerWindow(attackerPower, targetPower, minRatio = 0.72, maxRatio = 1.32) {
  const atk = Math.max(1, Number(attackerPower ?? 1));
  const tgt = Math.max(1, Number(targetPower ?? 1));
  const ratio = tgt / atk;
  return ratio >= minRatio && ratio <= maxRatio;
}

function buildMessage(outcome, attackerName, stolenCash, type) {
  const typeLabel = type === 'gang' ? 'Çete baskını' : 'Saldırı';

  if (outcome === 'win') {
    const cash = stolenCash?.toLocaleString('tr') ?? '0';
    return {
      title: `${typeLabel} — ${attackerName} seni devirdi!`,
      body: `${cash} $ nakitin çalındı. Hastanedesin.`,
    };
  }
  if (outcome === 'draw') {
    return {
      title: `${typeLabel} — Berabere!`,
      body: `${attackerName} sana saldırdı ama sonuç berabere.`,
    };
  }
  return {
    title: 'Saldırıyı püskürttün!',
    body: `${attackerName}'in baskınını savuşturdun.`,
  };
}

function formatOutcomeTr(outcome, direction) {
  const o = String(outcome ?? 'draw');
  if (o === 'win') {
    return direction === 'incoming' ? 'Sonuç: Kaybettin' : 'Sonuç: Kazandın';
  }
  if (o === 'lose') {
    return direction === 'incoming' ? 'Sonuç: Kazandın' : 'Sonuç: Kaybettin';
  }
  return 'Sonuç: Berabere';
}

function attackTypeLabelTr(type) {
  const t = String(type ?? 'quick');
  if (t === 'planned') return 'Planlı Saldırı';
  if (t === 'gang') return 'Çete Baskını';
  return 'Hızlı Saldırı';
}

function buildAttackReportBody(attack, direction = 'incoming') {
  const dir = direction === 'outgoing' ? 'outgoing' : 'incoming';
  const isOutgoing = dir === 'outgoing';
  const isGangAttack = String(attack?.type ?? '').trim() === 'gang';
  const lines = [];
  lines.push(formatOutcomeTr(attack?.outcome, dir));
  lines.push(`Tür: ${attackTypeLabelTr(attack?.type)}`);

  const attackerName = hasText(attack?.attackerName)
    ? String(attack.attackerName).trim()
    : 'Rakip';
  const targetName = hasText(attack?.targetName)
    ? String(attack.targetName).trim()
    : 'Rakip';
  const myName = isOutgoing ? attackerName : targetName;
  const enemyName = isOutgoing ? targetName : attackerName;
  lines.push(`Taraflar: Sen (${myName}) | Rakip (${enemyName})`);

  if (isGangAttack) {
    const attackerGangName = hasText(attack?.attackerGangName)
      ? String(attack.attackerGangName).trim()
      : 'Saldıran Kartel';
    const targetGangName = hasText(attack?.targetGangName)
      ? String(attack.targetGangName).trim()
      : 'Savunan Taraf';
    lines.push(`Karteller: ${attackerGangName} vs ${targetGangName}`);
    const memberCount = Math.max(0, Number(attack?.memberCount ?? 0));
    if (memberCount > 0) {
      lines.push(`Saldıran Üye Sayısı: ${memberCount}`);
    }
    const memberNames = Array.isArray(attack?.raidMemberNames)
      ? attack.raidMemberNames
        .map((name) => String(name ?? '').trim())
        .filter((name) => hasText(name))
      : [];
    if (memberNames.length > 0) {
      lines.push(`Saldırı Ekibi: ${memberNames.join(', ')}`);
    }
  }

  const atkTotal = Number(attack?.atkTotal ?? NaN);
  const defTotal = Number(attack?.defTotal ?? NaN);
  if (Number.isFinite(atkTotal) && Number.isFinite(defTotal)) {
    const myTotal = isOutgoing ? atkTotal : defTotal;
    const enemyTotal = isOutgoing ? defTotal : atkTotal;
    lines.push(`Savaş Gücü: Sen ${myTotal} | Rakip ${enemyTotal}`);
  }

  const stolenCash = Math.max(0, Number(attack?.stolenCash ?? 0));
  if (stolenCash > 0) {
    if (isOutgoing) {
      lines.push(`Nakit Kazancı: +$${stolenCash.toLocaleString('tr')}`);
    } else {
      lines.push(`Nakit Kaybı: -$${stolenCash.toLocaleString('tr')}`);
    }
  }

  const xp = Math.max(0, Number(attack?.xpGained ?? 0));
  if (xp > 0 && isOutgoing) {
    lines.push(`XP: +${xp}`);
  }

  const attackerLoadout = {
    weaponId: String(attack?.attackerWeaponId ?? '').trim(),
    knifeId: String(attack?.attackerKnifeId ?? '').trim(),
    armorId: String(attack?.attackerArmorId ?? '').trim(),
    vehicleId: String(attack?.attackerVehicleId ?? '').trim(),
  };
  const targetLoadout = {
    weaponId: String(attack?.targetWeaponId ?? '').trim(),
    knifeId: String(attack?.targetKnifeId ?? '').trim(),
    armorId: String(attack?.targetArmorId ?? '').trim(),
    vehicleId: String(attack?.targetVehicleId ?? '').trim(),
  };
  const myLoadout = isOutgoing ? attackerLoadout : targetLoadout;
  const enemyLoadout = isOutgoing ? targetLoadout : attackerLoadout;
  const hasLoadout =
    hasText(attackerLoadout.weaponId) ||
    hasText(targetLoadout.weaponId) ||
    hasText(attackerLoadout.knifeId) ||
    hasText(targetLoadout.knifeId) ||
    hasText(attackerLoadout.armorId) ||
    hasText(targetLoadout.armorId) ||
    hasText(attackerLoadout.vehicleId) ||
    hasText(targetLoadout.vehicleId);
  if (hasLoadout) {
    lines.push(
      `Senin Üstünde: ` +
      `Silah ${weaponLabelTr(myLoadout.weaponId)} | ` +
      `Yakın ${weaponLabelTr(myLoadout.knifeId)} | ` +
      `Zırh ${armorLabelTr(myLoadout.armorId)} | ` +
      `Araç ${vehicleLabelTr(myLoadout.vehicleId)}`,
    );
    lines.push(
      `Rakibin Üstünde: ` +
      `Silah ${weaponLabelTr(enemyLoadout.weaponId)} | ` +
      `Yakın ${weaponLabelTr(enemyLoadout.knifeId)} | ` +
      `Zırh ${armorLabelTr(enemyLoadout.armorId)} | ` +
      `Araç ${vehicleLabelTr(enemyLoadout.vehicleId)}`,
    );

    const myEdge = computeLoadoutMatchup(myLoadout, enemyLoadout);
    const enemyEdge = computeLoadoutMatchup(enemyLoadout, myLoadout);
    lines.push(
      `Senin Etki: ` +
      `Silah Güç %${signedPct(myEdge.weaponPowerPct)} | ` +
      `Silah Hız %${signedPct(myEdge.weaponSpeedPct)} | ` +
      `Silah Toplam %${signedPct(myEdge.weaponTotalPct)}`,
    );
    lines.push(
      `Senin Etki 2: ` +
      `Yakın %${signedPct(myEdge.knifePct)} | ` +
      `Zırh %${signedPct(myEdge.armorPct)} | ` +
      `Araç %${signedPct(myEdge.vehiclePct)} | ` +
      `Toplam %${signedPct(myEdge.loadoutTotalPct)}`,
    );
    lines.push(
      `Rakip Etki: ` +
      `Silah Toplam %${signedPct(enemyEdge.weaponTotalPct)} | ` +
      `Yakın %${signedPct(enemyEdge.knifePct)} | ` +
      `Zırh %${signedPct(enemyEdge.armorPct)} | ` +
      `Araç %${signedPct(enemyEdge.vehiclePct)} | ` +
      `Toplam %${signedPct(enemyEdge.loadoutTotalPct)}`,
    );
  } else {
    const loadoutTotalPct = Number(attack?.loadoutTotalPct ?? NaN);
    if (Number.isFinite(loadoutTotalPct)) {
      lines.push(`Ekipman Etkisi: %${signedPct(Math.trunc(loadoutTotalPct))}`);
    }
  }

  const msg = String(attack?.message ?? '').trim();
  if (hasText(msg)) {
    lines.push(`Rapor: ${msg}`);
  }
  return lines.join('\n');
}

// ── Bot Data ──────────────────────────────────────────────────────────────────

const BOT_GANGS = [
  { id: 'bot_gang_kuzey', name: 'Kuzey Kurtları', tag: 'KK', inviteOnly: false, acceptJoinRequests: true },
  { id: 'bot_gang_gece',  name: 'Gece Baronları', tag: 'GB', inviteOnly: false, acceptJoinRequests: true },
  { id: 'bot_gang_demir', name: 'Demir Yumruk',   tag: 'DY', inviteOnly: true,  acceptJoinRequests: false },
  { id: 'bot_gang_kizil', name: 'Kızıl Kartal',   tag: 'KR', inviteOnly: false, acceptJoinRequests: true },
];

const BOT_PLAYERS = [
  // Kuzey Kurtları (5 üye)
  { id: 'bot_reis_tuna',    name: 'Reis_Tuna',    gangId: 'bot_gang_kuzey', power: 1170, cash: 85000, level: 18 },
  { id: 'bot_serseri_cenk', name: 'Serseri_Cenk', gangId: 'bot_gang_kuzey', power: 1115, cash: 72000, level: 16 },
  { id: 'bot_tilki_tekin',  name: 'Tilki_Tekin',  gangId: 'bot_gang_kuzey', power: 780,  cash: 37000, level: 10 },
  { id: 'bot_kuzey_mert',   name: 'Kuzey_Mert',   gangId: 'bot_gang_kuzey', power: 720,  cash: 31000, level: 9  },
  { id: 'bot_kuzey_emre',   name: 'Kuzey_Emre',   gangId: 'bot_gang_kuzey', power: 660,  cash: 27000, level: 8  },
  // Gece Baronları (5 üye)
  { id: 'bot_baba_rasim',   name: 'Baba_Rasim',   gangId: 'bot_gang_gece',  power: 1060, cash: 68000, level: 15 },
  { id: 'bot_bela_burak',   name: 'Bela_Burak',   gangId: 'bot_gang_gece',  power: 1005, cash: 61000, level: 14 },
  { id: 'bot_kaplan_kaan',  name: 'Kaplan_Kaan',  gangId: 'bot_gang_gece',  power: 820,  cash: 38000, level: 11 },
  { id: 'bot_gece_selim',   name: 'Gece_Selim',   gangId: 'bot_gang_gece',  power: 750,  cash: 33000, level: 10 },
  { id: 'bot_gece_hakan',   name: 'Gece_Hakan',   gangId: 'bot_gang_gece',  power: 680,  cash: 28000, level: 9  },
  // Demir Yumruk (5 üye)
  { id: 'bot_kara_kemal',   name: 'Kara_Kemal',   gangId: 'bot_gang_demir', power: 950,  cash: 55000, level: 13 },
  { id: 'bot_yilan_yusuf',  name: 'Yilan_Yusuf',  gangId: 'bot_gang_demir', power: 880,  cash: 47000, level: 12 },
  { id: 'bot_demir_orhan',  name: 'Demir_Orhan',  gangId: 'bot_gang_demir', power: 810,  cash: 40000, level: 11 },
  { id: 'bot_demir_tayfun', name: 'Demir_Tayfun', gangId: 'bot_gang_demir', power: 740,  cash: 34000, level: 10 },
  { id: 'bot_demir_volkan', name: 'Demir_Volkan', gangId: 'bot_gang_demir', power: 670,  cash: 28000, level: 9  },
  // Kızıl Kartal (5 üye)
  { id: 'bot_cete_ali',     name: 'Cete_Ali',     gangId: 'bot_gang_kizil', power: 890,  cash: 48000, level: 12 },
  { id: 'bot_sokak_serkan', name: 'Sokak_Serkan', gangId: 'bot_gang_kizil', power: 830,  cash: 42000, level: 11 },
  { id: 'bot_kizil_cem',    name: 'Kizil_Cem',    gangId: 'bot_gang_kizil', power: 770,  cash: 36000, level: 10 },
  { id: 'bot_kizil_firat',  name: 'Kizil_Firat',  gangId: 'bot_gang_kizil', power: 700,  cash: 30000, level: 9  },
  { id: 'bot_kizil_umut',   name: 'Kizil_Umut',   gangId: 'bot_gang_kizil', power: 630,  cash: 25000, level: 8  },
];

exports.seedBotData = onCall({ invoker: 'public' }, async (request) => {
  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();
  const nowEpoch = Math.floor(Date.now() / 1000);

  for (const gang of BOT_GANGS) {
    const botMembers = BOT_PLAYERS.filter(p => p.gangId === gang.id);
    const totalPower = botMembers.reduce((s, p) => s + p.power, 0);
    const gangRef = db.collection('gangs').doc(gang.id);
    batch.set(gangRef, {
      id: gang.id,
      name: gang.name,
      tag: gang.tag,
      ownerId: botMembers[0]?.id ?? 'bot',
      ownerName: botMembers[0]?.name ?? 'Bot',
      inviteOnly: gang.inviteOnly,
      acceptJoinRequests: gang.acceptJoinRequests,
      memberCount: botMembers.length,
      totalPower,
      respectPoints: Math.floor(totalPower * 1.1),
      vault: Math.floor(totalPower * 40),
      gangRank: 1,
      isBot: true,
      createdAt: now,
      updatedAt: now,
    }, { merge: true });

    for (const bot of botMembers) {
      const memberRef = gangRef.collection('members').doc(bot.id);
      batch.set(memberRef, {
        uid: bot.id,
        displayName: bot.name,
        role: bot.id === botMembers[0]?.id ? 'Lider' : 'Üye',
        power: bot.power,
        isBot: true,
        joinedAt: now,
        updatedAt: now,
      }, { merge: true });
    }
  }

  for (const bot of BOT_PLAYERS) {
    const profile = resolveBotPersonality(bot);
    const userRef = db.collection('users').doc(bot.id);
    batch.set(userRef, {
      uid: bot.id,
      displayName: bot.name,
      power: bot.power,
      cash: bot.cash,
      level: bot.level,
      xp: bot.level * 1000,
      gangId: bot.gangId,
      gangName: BOT_GANGS.find(g => g.id === bot.gangId)?.name ?? '',
      gangRole: 'Üye',
      currentEnergy: 100,
      maxEnergy: 100,
      attackEnergyCost: 20,
      currentTp: 100,
      maxTp: 100,
      shieldUntilEpoch: 0,
      status: 'active',
      statusUntilEpoch: 0,
      statusUntil: null,
      equippedWeaponId: defaultWeaponIdForPower(bot.power),
      equippedKnifeId: defaultKnifeIdForPower(bot.power),
      equippedArmorId: defaultArmorIdForPower(bot.power),
      equippedVehicleId: defaultVehicleIdForPower(bot.power),
      combatWeaponId: defaultWeaponIdForPower(bot.power),
      online: true,
      lastLoginEpoch: nowEpoch,
      lastBotActionAtEpoch: 0,
      lastBotMissionAtEpoch: 0,
      lastBotCombatAtEpoch: 0,
      lastBotAttackAtEpoch: 0,
      isBot: true,
      botPersonality: profile.key,
      score: bot.power * 30 + bot.cash / 100,
      updatedAt: now,
    }, { merge: true });
  }

  await batch.commit();
  return { ok: true, gangs: BOT_GANGS.length, players: BOT_PLAYERS.length };
});

function toSimUser(id, data, nowEpoch) {
  const statusInfo = resolvePenaltyStatus(data, nowEpoch);
  const level = Math.max(1, Number(data.level ?? 1));
  const xp = Math.max(Number(data.xp ?? (level * 1000)), 0);
  const power = Math.max(1, Number(data.power ?? 1));
  const maxEnergy = Math.max(100, Number(data.maxEnergy ?? 100));
  const currentEnergy = Math.max(0, Math.min(maxEnergy, Number(data.currentEnergy ?? 100)));
  const maxTp = Math.max(100, Number(data.maxTp ?? 100));
  const currentTp = Math.max(0, Math.min(maxTp, Number(data.currentTp ?? 100)));
  return {
    id,
    name: String(data.displayName ?? data.name ?? 'Oyuncu'),
    isBot: data.isBot === true,
    gangId: String(data.gangId ?? ''),
    gangName: String(data.gangName ?? ''),
    level,
    xp,
    power,
    cash: Math.max(0, Number(data.cash ?? 0)),
    wins: Math.max(0, Number(data.wins ?? 0)),
    gangWins: Math.max(0, Number(data.gangWins ?? 0)),
    currentEnergy,
    maxEnergy,
    attackEnergyCost: Math.max(12, Math.min(24, Number(data.attackEnergyCost ?? 20))),
    currentTp,
    maxTp,
    shieldUntilEpoch: Math.max(0, Number(data.shieldUntilEpoch ?? 0)),
    status: statusInfo.status,
    statusUntilEpoch: statusInfo.statusUntilEpoch,
    equippedWeaponId: String(data.equippedWeaponId ?? ''),
    equippedKnifeId: String(data.equippedKnifeId ?? ''),
    equippedArmorId: String(data.equippedArmorId ?? ''),
    equippedVehicleId: String(data.equippedVehicleId ?? ''),
    combatWeaponId: String(data.combatWeaponId ?? ''),
    lastBotAttackAtEpoch: Math.max(0, Number(data.lastBotAttackAtEpoch ?? 0)),
    lastBotActionAtEpoch: Math.max(0, Number(data.lastBotActionAtEpoch ?? 0)),
    lastBotMissionAtEpoch: Math.max(0, Number(data.lastBotMissionAtEpoch ?? 0)),
    lastBotCombatAtEpoch: Math.max(0, Number(data.lastBotCombatAtEpoch ?? 0)),
  };
}

function isLocked(user, nowEpoch) {
  if (!user) return false;
  if (user.status !== 'hospital' && user.status !== 'prison') return false;
  return Number(user.statusUntilEpoch ?? 0) > nowEpoch;
}

function applyPenalty(user, status, nowEpoch, sec) {
  user.status = status;
  user.statusUntilEpoch = nowEpoch + sec;
  if (status === 'hospital') {
    user.currentTp = 0;
  } else {
    user.currentTp = Math.max(12, Math.trunc(user.maxTp * 0.28));
  }
}

function levelForXp(xp) {
  const lv = Math.floor(Math.max(0, Number(xp ?? 0)) / 1000) + 1;
  return Math.max(1, Math.min(90, lv));
}

function pickRandom(items) {
  if (!Array.isArray(items) || items.length === 0) return null;
  return items[Math.floor(Math.random() * items.length)] || null;
}

exports.botActivityLoop = onSchedule('every 2 minutes', async () => {
  const now = admin.firestore.Timestamp.now();
  const nowEpoch = Math.floor(Date.now() / 1000);
  const BOT_ATTACK_TARGET_COOLDOWN_SEC = 4 * 60 * 60;
  const MAX_ATTACKS_PER_TICK = 8;
  const MAX_MISSIONS_PER_TICK = 14;

  const [botSnap, usersSnap] = await Promise.all([
    db.collection('users').where('isBot', '==', true).get(),
    db.collection('users').limit(1000).get(),
  ]);

  if (botSnap.empty) {
    console.log('No bots found, skipping activity tick.');
    return;
  }

  const botMap = new Map();
  for (const doc of botSnap.docs) {
    botMap.set(doc.id, toSimUser(doc.id, doc.data() || {}, nowEpoch));
  }

  const realMap = new Map();
  for (const doc of usersSnap.docs) {
    if (botMap.has(doc.id)) continue;
    const data = doc.data() || {};
    if (data.isBot === true) continue;
    realMap.set(doc.id, toSimUser(doc.id, data, nowEpoch));
  }

  const changedRealIds = new Set();
  const attackLogs = [];
  let realTargetedThisTick = 0;
  const realHitsByTarget = new Map();
  const maxRealHitsPerTargetPerTick = 1;
  const maxRealTargetsPerTick = 4;
  let attackActionsThisTick = 0;
  let missionActionsThisTick = 0;

  const botIds = Array.from(botMap.keys()).sort(() => Math.random() - 0.5);
  for (const botId of botIds) {
    const bot = botMap.get(botId);
    if (!bot) continue;
    const profile = resolveBotPersonality(bot);
    const cadence = resolveBotCadenceSec(bot, profile.key);

    if (isLocked(bot, nowEpoch)) {
      // Bots obey the same lock rules as real players.
      continue;
    }

    bot.currentEnergy = Math.min(bot.maxEnergy, bot.currentEnergy + (8 + randomInt(12)));
    bot.currentTp = Math.min(bot.maxTp, Math.max(15, bot.currentTp + randomInt(8)));

    const actionRoll = Math.random();
    const canAttack =
      attackActionsThisTick < MAX_ATTACKS_PER_TICK &&
      bot.currentEnergy >= bot.attackEnergyCost &&
      bot.currentTp > 0 &&
      (nowEpoch - bot.lastBotCombatAtEpoch) >= cadence.attackSec;
    const canMission =
      missionActionsThisTick < MAX_MISSIONS_PER_TICK &&
      bot.currentEnergy >= 10 &&
      (nowEpoch - bot.lastBotMissionAtEpoch) >= cadence.missionSec;

    if (actionRoll < 0.52 && canAttack) {
      const botTargets = Array.from(botMap.values()).filter((u) =>
        u.id !== bot.id &&
        !isLocked(u, nowEpoch) &&
        u.shieldUntilEpoch <= nowEpoch &&
        u.currentTp > 0 &&
        withinPowerWindow(bot.power, u.power, 0.70, 1.35),
      );
      const botTargetsSoft = Array.from(botMap.values()).filter((u) =>
        u.id !== bot.id &&
        !isLocked(u, nowEpoch) &&
        u.shieldUntilEpoch <= nowEpoch &&
        u.currentTp > 0 &&
        withinPowerWindow(bot.power, u.power, 0.55, 1.60),
      );
      const realTargets = Array.from(realMap.values()).filter((u) =>
        !isLocked(u, nowEpoch) &&
        u.shieldUntilEpoch <= nowEpoch &&
        u.currentTp > 0 &&
        withinPowerWindow(bot.power, u.power, 0.72, 1.32) &&
        (nowEpoch - Math.max(0, Number(u.lastBotAttackAtEpoch ?? 0))) >= BOT_ATTACK_TARGET_COOLDOWN_SEC &&
        (realHitsByTarget.get(u.id) || 0) < maxRealHitsPerTargetPerTick,
      );
      const realTargetsSoft = Array.from(realMap.values()).filter((u) =>
        !isLocked(u, nowEpoch) &&
        u.shieldUntilEpoch <= nowEpoch &&
        u.currentTp > 0 &&
        withinPowerWindow(bot.power, u.power, 0.62, 1.45) &&
        (nowEpoch - Math.max(0, Number(u.lastBotAttackAtEpoch ?? 0))) >= BOT_ATTACK_TARGET_COOLDOWN_SEC &&
        (realHitsByTarget.get(u.id) || 0) < maxRealHitsPerTargetPerTick,
      );

      let pool = [];
      // Real users should feel the world is alive: bots prefer attacking real players.
      if (
        realTargets.length > 0 &&
        realTargetedThisTick < maxRealTargetsPerTick &&
        (realTargetedThisTick === 0 || Math.random() < 0.72)
      ) {
        pool = realTargets;
      } else if (
        realTargetsSoft.length > 0 &&
        realTargetedThisTick < maxRealTargetsPerTick &&
        (realTargetedThisTick === 0 || Math.random() < 0.55)
      ) {
        pool = realTargetsSoft;
      } else if (botTargets.length > 0) {
        pool = botTargets;
      } else if (botTargetsSoft.length > 0) {
        pool = botTargetsSoft;
      } else {
        pool = realTargetsSoft;
      }
      const target = pickRandom(pool);
      if (!target) continue;
      if (!target.isBot) {
        target.lastBotAttackAtEpoch = nowEpoch;
        realTargetedThisTick += 1;
        realHitsByTarget.set(target.id, (realHitsByTarget.get(target.id) || 0) + 1);
        changedRealIds.add(target.id);
      }

      const attackerLoadout = resolveLoadout({
        combatWeaponId: bot.combatWeaponId,
        equippedWeaponId: bot.equippedWeaponId,
        equippedKnifeId: bot.equippedKnifeId,
        equippedArmorId: bot.equippedArmorId,
        equippedVehicleId: bot.equippedVehicleId,
      }, bot.power);
      const targetLoadout = resolveLoadout({
        combatWeaponId: target.combatWeaponId,
        equippedWeaponId: target.equippedWeaponId,
        equippedKnifeId: target.equippedKnifeId,
        equippedArmorId: target.equippedArmorId,
        equippedVehicleId: target.equippedVehicleId,
      }, target.power);
      const atkEdge = computeLoadoutMatchup(attackerLoadout, targetLoadout);
      const defEdge = computeLoadoutMatchup(targetLoadout, attackerLoadout);

      const atkTotal = applyPercent(bot.power, atkEdge.loadoutTotalPct) + randomInt(bot.power / 5);
      const defTotal =
        applyPercent(target.power, defEdge.loadoutTotalPct) + randomInt(target.power / 5);

      const diff = Math.abs(atkTotal - defTotal);
      const drawThreshold = Math.trunc(defTotal * 0.1);
      let outcome = 'draw';
      if (diff > drawThreshold) {
        outcome = atkTotal > defTotal ? 'win' : 'lose';
      }

      bot.currentEnergy = Math.max(0, bot.currentEnergy - bot.attackEnergyCost);
      bot.lastBotCombatAtEpoch = nowEpoch;
      bot.lastBotActionAtEpoch = nowEpoch;
      attackActionsThisTick += 1;
      let stolenCash = 0;
      let xpGained = 0;
      let message = '';

      if (outcome === 'win') {
        const stealPct = 0.05 + (Math.random() * 0.10);
        stolenCash = Math.max(25, Math.min(90000, Math.trunc(target.cash * stealPct)));
        stolenCash = Math.min(stolenCash, Math.max(0, target.cash));
        xpGained = 20 + randomInt(22);

        bot.cash += stolenCash;
        bot.xp += xpGained;
        bot.wins += 1;
        if (Math.random() < 0.22) {
          bot.power += 1 + randomInt(2);
        }

        target.cash = Math.max(0, target.cash - stolenCash);
        const targetPenalty = Math.random() < 0.33 ? 'prison' : 'hospital';
        const targetPenaltySec = penaltySecondsForStatus(targetPenalty);
        applyPenalty(target, targetPenalty, nowEpoch, targetPenaltySec);
        target.shieldUntilEpoch = nowEpoch + targetPenaltySec + (5 * 60);
        if (!target.isBot) {
          changedRealIds.add(target.id);
        }
        if (bot.gangId && target.gangId && bot.gangId !== target.gangId) {
          bot.gangWins += 1;
        }
        message = `${target.name} etkisiz hale getirildi. ${stolenCash}$ ganimet.`;
      } else if (outcome === 'lose') {
        xpGained = 6 + randomInt(8);
        bot.xp += xpGained;
        applyPenalty(bot, 'hospital', nowEpoch, HOSPITAL_PENALTY_SEC);
        bot.shieldUntilEpoch = nowEpoch + HOSPITAL_PENALTY_SEC + (5 * 60);
        message = `${target.name} saldırıyı püskürttü, bot hastaneye düştü.`;
      } else {
        xpGained = 10 + randomInt(6);
        bot.xp += xpGained;
        bot.currentTp = Math.max(10, bot.currentTp - (4 + randomInt(9)));
        target.currentTp = Math.max(10, target.currentTp - (3 + randomInt(8)));
        if (!target.isBot) {
          changedRealIds.add(target.id);
        }
        message = `${target.name} ile çatışma berabere bitti.`;
      }

      bot.level = levelForXp(bot.xp);
      if (bot.level > 1 && bot.power < (120 + (bot.level * 70))) {
        bot.power += randomInt(2);
      }

      attackLogs.push({
        attackerId: bot.id,
        attackerName: bot.name,
        targetId: target.id,
        targetName: target.name,
        type: 'quick',
        outcome,
        stolenCash,
        xpGained,
        message,
        atkTotal,
        defTotal,
        attackerWeaponId: attackerLoadout.weaponId,
        targetWeaponId: targetLoadout.weaponId,
        attackerKnifeId: attackerLoadout.knifeId,
        targetKnifeId: targetLoadout.knifeId,
        attackerArmorId: attackerLoadout.armorId,
        targetArmorId: targetLoadout.armorId,
        attackerVehicleId: attackerLoadout.vehicleId,
        targetVehicleId: targetLoadout.vehicleId,
        weaponPowerPct: atkEdge.weaponPowerPct,
        weaponSpeedPct: atkEdge.weaponSpeedPct,
        weaponTotalPct: atkEdge.weaponTotalPct,
        knifePct: atkEdge.knifePct,
        armorPct: atkEdge.armorPct,
        vehiclePct: atkEdge.vehiclePct,
        loadoutTotalPct: atkEdge.loadoutTotalPct,
        timestamp: now,
      });
      continue;
    }

    if (canMission) {
      const missionCost = 10 + randomInt(8);
      bot.currentEnergy = Math.max(0, bot.currentEnergy - missionCost);
      bot.lastBotMissionAtEpoch = nowEpoch;
      bot.lastBotActionAtEpoch = nowEpoch;
      missionActionsThisTick += 1;
      const missionSuccess = Math.random() < Math.min(0.92, 0.50 + (bot.power / 6000));
      if (missionSuccess) {
        const missionCash = 450 + randomInt(1800);
        const missionXp = 20 + randomInt(35);
        bot.cash += missionCash;
        bot.xp += missionXp;
        if (Math.random() < 0.26) {
          bot.power += 1 + randomInt(3);
        }
      } else {
        const failPenalty = 120 + randomInt(380);
        bot.cash = Math.max(0, bot.cash - failPenalty);
        if (Math.random() < 0.58) {
          const failStatus = Math.random() < 0.52 ? 'prison' : 'hospital';
          const failPenaltySec = penaltySecondsForStatus(failStatus);
          applyPenalty(bot, failStatus, nowEpoch, failPenaltySec);
          bot.shieldUntilEpoch = nowEpoch + failPenaltySec + (5 * 60);
        }
      }
      bot.level = levelForXp(bot.xp);
      continue;
    }

    // Passive economy tick
    if (Math.random() < 0.35) {
      // Rest/maintenance behavior: bots don't always grind aggressively.
      bot.currentEnergy = Math.min(bot.maxEnergy, bot.currentEnergy + 12 + randomInt(14));
      bot.currentTp = Math.min(bot.maxTp, bot.currentTp + 8 + randomInt(10));
      bot.cash += 40 + randomInt(120);
      bot.xp += 1 + randomInt(3);
    } else {
      bot.cash += 120 + randomInt(420);
      bot.xp += 2 + randomInt(6);
    }
    bot.level = levelForXp(bot.xp);
  }

  const batch = db.batch();

  for (const [botId, bot] of botMap.entries()) {
    const userRef = db.collection('users').doc(botId);
    const profile = resolveBotPersonality(bot);
    const botLoadout = resolveLoadout({
      combatWeaponId: bot.combatWeaponId,
      equippedWeaponId: bot.equippedWeaponId,
      equippedKnifeId: bot.equippedKnifeId,
      equippedArmorId: bot.equippedArmorId,
      equippedVehicleId: bot.equippedVehicleId,
    }, bot.power);
    batch.set(userRef, {
      uid: bot.id,
      displayName: bot.name,
      name: bot.name,
      isBot: true,
      botPersonality: profile.key,
      gangId: bot.gangId,
      gangName: bot.gangName,
      gangRole: 'Üye',
      level: bot.level,
      xp: Math.max(0, Math.trunc(bot.xp)),
      power: Math.max(1, Math.trunc(bot.power)),
      cash: Math.max(0, Math.trunc(bot.cash)),
      wins: Math.max(0, Math.trunc(bot.wins)),
      gangWins: Math.max(0, Math.trunc(bot.gangWins)),
      currentEnergy: Math.max(0, Math.trunc(bot.currentEnergy)),
      maxEnergy: Math.max(100, Math.trunc(bot.maxEnergy)),
      attackEnergyCost: Math.max(12, Math.min(24, Math.trunc(bot.attackEnergyCost))),
      currentTp: Math.max(0, Math.min(bot.maxTp, Math.trunc(bot.currentTp))),
      maxTp: Math.max(100, Math.trunc(bot.maxTp)),
      status: bot.status,
      statusUntilEpoch: Math.max(0, Math.trunc(bot.statusUntilEpoch)),
      statusUntil: bot.statusUntilEpoch > nowEpoch
        ? admin.firestore.Timestamp.fromDate(new Date(bot.statusUntilEpoch * 1000))
        : null,
      shieldUntilEpoch: Math.max(0, Math.trunc(bot.shieldUntilEpoch)),
      equippedWeaponId: botLoadout.weaponId,
      equippedKnifeId: botLoadout.knifeId,
      equippedArmorId: botLoadout.armorId,
      equippedVehicleId: botLoadout.vehicleId,
      combatWeaponId: botLoadout.weaponId,
      online: (nowEpoch - Math.max(0, Number(bot.lastBotActionAtEpoch ?? 0))) < (40 * 60),
      lastBotActionAtEpoch: Math.max(0, Math.trunc(bot.lastBotActionAtEpoch ?? 0)),
      lastBotMissionAtEpoch: Math.max(0, Math.trunc(bot.lastBotMissionAtEpoch ?? 0)),
      lastBotCombatAtEpoch: Math.max(0, Math.trunc(bot.lastBotCombatAtEpoch ?? 0)),
      score: Math.trunc((bot.power * 12) + (bot.wins * 900) + (bot.gangWins * 1200) + (bot.cash / 2000)),
      updatedAt: now,
    }, { merge: true });
  }

  for (const realId of changedRealIds) {
    const target = realMap.get(realId);
    if (!target) continue;
    const userRef = db.collection('users').doc(realId);
    batch.set(userRef, {
      cash: Math.max(0, Math.trunc(target.cash)),
      currentTp: Math.max(0, Math.min(target.maxTp, Math.trunc(target.currentTp))),
      lastBotAttackAtEpoch: Math.max(0, Math.trunc(target.lastBotAttackAtEpoch ?? 0)),
      status: target.status,
      statusUntilEpoch: Math.max(0, Math.trunc(target.statusUntilEpoch)),
      statusUntil: target.statusUntilEpoch > nowEpoch
        ? admin.firestore.Timestamp.fromDate(new Date(target.statusUntilEpoch * 1000))
        : null,
      shieldUntilEpoch: Math.max(0, Math.trunc(target.shieldUntilEpoch)),
      updatedAt: now,
    }, { merge: true });
  }

  const inboxWrittenForRealTarget = new Set();
  for (const log of attackLogs) {
    const attackRef = db.collection('attacks').doc();
    batch.set(attackRef, log);
    if (realMap.has(log.targetId)) {
      const targetId = String(log.targetId ?? '').trim();
      const attackerIsBot = String(log.attackerId ?? '').startsWith('bot_');
      const allowBotInbox =
        !inboxWrittenForRealTarget.has(targetId) && Math.random() < 0.35;
      if (attackerIsBot && !allowBotInbox) {
        continue;
      }
      const inboxRef = db
        .collection('users')
        .doc(targetId)
        .collection('inbox')
        .doc();
      batch.set(inboxRef, {
        type: 'attack_report',
        attackId: attackRef.id,
        title: `${log.attackerName} sana saldırdı`,
        body: buildAttackReportBody(log, 'incoming'),
        outcome: log.outcome,
        stolenCash: log.stolenCash,
        xpGained: log.xpGained,
        direction: 'incoming',
        attackerId: log.attackerId,
        attackerName: log.attackerName,
        attackType: log.type,
        atkTotal: Number(log.atkTotal ?? 0),
        defTotal: Number(log.defTotal ?? 0),
        attackerWeaponId: String(log.attackerWeaponId ?? ''),
        targetWeaponId: String(log.targetWeaponId ?? ''),
        attackerKnifeId: String(log.attackerKnifeId ?? ''),
        targetKnifeId: String(log.targetKnifeId ?? ''),
        attackerArmorId: String(log.attackerArmorId ?? ''),
        targetArmorId: String(log.targetArmorId ?? ''),
        attackerVehicleId: String(log.attackerVehicleId ?? ''),
        targetVehicleId: String(log.targetVehicleId ?? ''),
        weaponTotalPct: Number(log.weaponTotalPct ?? 0),
        knifePct: Number(log.knifePct ?? 0),
        armorPct: Number(log.armorPct ?? 0),
        vehiclePct: Number(log.vehiclePct ?? 0),
        loadoutTotalPct: Number(log.loadoutTotalPct ?? 0),
        isRead: false,
        createdAt: now,
      });
      if (attackerIsBot) {
        inboxWrittenForRealTarget.add(targetId);
      }
    }
  }

  for (const gang of BOT_GANGS) {
    const members = Array.from(botMap.values()).filter((u) => u.gangId === gang.id);
    const totalPower = members.reduce((sum, u) => sum + Math.max(0, Number(u.power ?? 0)), 0);
    const totalWins = members.reduce((sum, u) => sum + Math.max(0, Number(u.wins ?? 0)), 0);
    const gangRef = db.collection('gangs').doc(gang.id);
    batch.set(gangRef, {
      id: gang.id,
      name: gang.name,
      ownerId: members[0]?.id ?? 'bot',
      ownerName: members[0]?.name ?? 'Bot',
      inviteOnly: gang.inviteOnly,
      acceptJoinRequests: gang.acceptJoinRequests,
      memberCount: members.length,
      totalPower,
      respectPoints: Math.floor(totalPower * 1.1) + (totalWins * 25),
      vault: Math.floor(totalPower * 40),
      isBot: true,
      updatedAt: now,
    }, { merge: true });

    for (const member of members) {
      const memberRef = gangRef.collection('members').doc(member.id);
      batch.set(memberRef, {
        uid: member.id,
        displayName: member.name,
        role: member.id === members[0]?.id ? 'Lider' : 'Üye',
        power: Math.max(1, Math.trunc(member.power)),
        isBot: true,
        updatedAt: now,
      }, { merge: true });
    }
  }

  await batch.commit();
  try {
    await maybePostGlobalBotPrompt(attackLogs);
  } catch (error) {
    console.error('Global bot prompt failed:', error);
  }
  console.log(
    `Bot loop ok: bots=${botMap.size}, realTargeted=${realTargetedThisTick}, realTouched=${changedRealIds.size}, attacks=${attackLogs.length}`,
  );
});

async function sendNotification(token, title, body, data = {}) {
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: 'cartelhood_attacks',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });
  } catch (err) {
    if (err.code === 'messaging/registration-token-not-registered') {
      console.log('Geçersiz token, siliniyor:', token);
    }
    console.error('FCM hatası:', err.message);
  }
}
