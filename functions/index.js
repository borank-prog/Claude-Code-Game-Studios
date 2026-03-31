const admin = require('firebase-admin');
const { onDocumentCreated, onDocumentCreated: onDocCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

exports.onAttackCreated = onDocumentCreated(
  'attacks/{attackId}',
  async (event) => {
    const attack = event.data.data();
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

exports.onGangMessageCreated = onDocCreated(
  'gang_chats/{gangId}/messages/{msgId}',
  async (event) => {
    const data = event.data.data();
    const { gangId } = event.params;

    if (data.type === 'system') return;

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

exports.executePvpAttack = onCall(async (request) => {
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
  const type = ['quick', 'planned', 'gang'].includes(rawType) ? rawType : 'quick';
  const rawBonus = Number(request.data?.equipmentBonus ?? 0);
  const equipmentBonus = Number.isFinite(rawBonus)
    ? Math.max(0, Math.min(50, Math.trunc(rawBonus)))
    : 0;

  const attackerName = String(request.data?.attackerName ?? '').trim() || 'Bilinmiyor';
  const targetNameFromClient = String(request.data?.targetName ?? '').trim();

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

  const profileAttackCostRaw = Number(attackerData.attackEnergyCost ?? NaN);
  const profileAttackCost = Number.isFinite(profileAttackCostRaw)
    ? Math.max(12, Math.min(20, Math.trunc(profileAttackCostRaw)))
    : null;
  const attackCost = profileAttackCost ?? 20;

  const attackerStatus = attackerData.status || 'active';
  const targetStatus = targetData.status || 'active';
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
  const nowEpoch = Math.floor(Date.now() / 1000);
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
  const allowedTargetIds = await buildAllowedTargetIds(attackerId, attackerPower);
  if (!allowedTargetIds.has(targetId)) {
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

    const atkTxStatus = atkTxData.status || 'active';
    const targetTxStatus = targetTxData.status || 'active';
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
    const txNowEpoch = Math.floor(Date.now() / 1000);
    const txTargetShieldUntilEpoch = Math.max(0, Number(targetTxData.shieldUntilEpoch ?? 0));
    if (txTargetShieldUntilEpoch > txNowEpoch) {
      const waitMin = Math.max(1, Math.ceil((txTargetShieldUntilEpoch - txNowEpoch) / 60));
      throw new HttpsError(
        'failed-precondition',
        `Hedef koruma kalkanında. Yaklaşık ${waitMin} dakika bekle`,
      );
    }
    const atkAttackCostRaw = Number(atkTxData.attackEnergyCost ?? NaN);
    const atkAttackCost = Number.isFinite(atkAttackCostRaw)
      ? Math.max(12, Math.min(20, Math.trunc(atkAttackCostRaw)))
      : attackCost;
    const atkEnergy = Math.max(0, Number(atkTxData.currentEnergy ?? 0));
    if (atkEnergy < atkAttackCost) {
      throw new HttpsError(
        'failed-precondition',
        `Saldırı için en az ${atkAttackCost} enerji gerekli`,
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
    });

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
    const atkTotal =
      applyPercent(atkBaseWithEquipment, attackerMatchup.loadoutTotalPct) + atkRoll;
    const defTotal = applyPercent(defPower, defenderMatchup.loadoutTotalPct) + defRoll;

    const diff = Math.abs(atkTotal - defTotal);
    const drawThreshold = Math.trunc(defTotal * 0.1);
    let outcome = 'draw';
    if (diff > drawThreshold) {
      outcome = atkTotal > defTotal ? 'win' : 'lose';
    }

    let stolenCash = 0;
    let xpGained = 0;
    let message = '';
    const penaltyEndDate = new Date(nowDate.getTime() + 45 * 60 * 1000);
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
        shieldUntilEpoch: penaltyShieldUntilEpoch,
      });
      message =
        `Mağlup oldun! Hastaneye kaldırıldın. ` +
        `[${attackerWeaponName} vs ${targetWeaponName} | ` +
        `Toplam ekipman etkisi %${signedPct(attackerMatchup.loadoutTotalPct)}]`;
    } else {
      message =
        `Berabere! Her iki taraf da hafif yaralı. ` +
        `[${attackerWeaponName} vs ${targetWeaponName}]`;
    }

    const attackRef = db.collection('attacks').doc();
    tx.set(cooldownRef, { lastAttack: admin.firestore.Timestamp.now() });
    tx.set(attackRef, {
      attackerId,
      targetId,
      attackerName,
      targetName: targetNameFromClient || String(targetTxData.displayName || 'Bilinmiyor'),
      type,
      outcome,
      attackCost: atkAttackCost,
      stolenCash,
      xpGained,
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
exports.executeGangRaid = onCall(async (request) => {
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
  const targetStatus = targetData.status || 'active';
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
    const st = d.status || 'active';
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
    new Date(nowDate.getTime() + 45 * 60 * 1000),
  );
  const penaltyShieldUntilEpoch = Math.floor((nowDate.getTime() + 50 * 60 * 1000) / 1000);

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
      statusUntil: hospitalUntil,
      shieldUntilEpoch: penaltyShieldUntilEpoch,
    });
    message = `Çete baskını başarılı! Kişi başı $${stolenCash} kazandınız.`;
  } else if (outcome === 'lose') {
    // Only leader goes to hospital
    batch.update(db.collection('users').doc(leaderId), {
      status: 'hospital',
      statusUntil: hospitalUntil,
      shieldUntilEpoch: penaltyShieldUntilEpoch,
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
exports.executeTrade = onCall(async (request) => {
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

async function buildAllowedTargetIds(attackerId, attackerPower) {
  const users = db.collection('users');
  const [strongerSnap, weakerSnap, equalSnap] = await Promise.all([
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
    users.where('power', '==', attackerPower).limit(25).get(),
  ]);

  const allowed = new Set([
    ...strongerSnap.docs.map((d) => d.id),
    ...weakerSnap.docs.map((d) => d.id),
    ...equalSnap.docs.map((d) => d.id),
  ]);
  allowed.delete(attackerId);
  return allowed;
}

function randomInt(maxFloat) {
  const max = Math.max(0, Math.trunc(maxFloat));
  return Math.floor(Math.random() * (max + 1));
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

// ── Bot Data ──────────────────────────────────────────────────────────────────

const BOT_GANGS = [
  { id: 'bot_gang_kuzey', name: 'Kuzey Kurtları', tag: 'KK', inviteOnly: false, acceptJoinRequests: true },
  { id: 'bot_gang_gece',  name: 'Gece Baronları', tag: 'GB', inviteOnly: false, acceptJoinRequests: true },
  { id: 'bot_gang_demir', name: 'Demir Yumruk',   tag: 'DY', inviteOnly: true,  acceptJoinRequests: false },
  { id: 'bot_gang_kizil', name: 'Kızıl Kartal',   tag: 'KR', inviteOnly: false, acceptJoinRequests: true },
];

const BOT_PLAYERS = [
  { id: 'bot_reis_tuna',    name: 'Reis_Tuna',    gangId: 'bot_gang_kuzey', power: 1170, cash: 85000, level: 18 },
  { id: 'bot_serseri_cenk', name: 'Serseri_Cenk', gangId: 'bot_gang_kuzey', power: 1115, cash: 72000, level: 16 },
  { id: 'bot_baba_rasim',   name: 'Baba_Rasim',   gangId: 'bot_gang_gece',  power: 1060, cash: 68000, level: 15 },
  { id: 'bot_bela_burak',   name: 'Bela_Burak',   gangId: 'bot_gang_gece',  power: 1005, cash: 61000, level: 14 },
  { id: 'bot_kara_kemal',   name: 'Kara_Kemal',   gangId: 'bot_gang_demir', power: 950,  cash: 55000, level: 13 },
  { id: 'bot_cete_ali',     name: 'Çete_Ali',     gangId: 'bot_gang_kizil', power: 890,  cash: 48000, level: 12 },
  { id: 'bot_sokak_serkan', name: 'Sokak_Serkan', gangId: 'bot_gang_kizil', power: 830,  cash: 42000, level: 11 },
  { id: 'bot_tilki_tekin',  name: 'Tilki_Tekin',  gangId: 'bot_gang_kuzey', power: 780,  cash: 37000, level: 10 },
  { id: 'bot_kaplan_kaan',  name: 'Kaplan_Kaan',  gangId: 'bot_gang_gece',  power: 720,  cash: 32000, level: 9 },
  { id: 'bot_yilan_yusuf',  name: 'Yılan_Yusuf',  gangId: 'bot_gang_demir', power: 660,  cash: 27000, level: 8 },
];

exports.seedBotData = onCall(async (request) => {
  const batch = db.batch();

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
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    }, { merge: true });

    for (const bot of botMembers) {
      const memberRef = gangRef.collection('members').doc(bot.id);
      batch.set(memberRef, {
        uid: bot.id,
        displayName: bot.name,
        role: bot.id === botMembers[0]?.id ? 'Lider' : 'Üye',
        power: bot.power,
        isBot: true,
        joinedAt: admin.firestore.Timestamp.now(),
      }, { merge: true });
    }
  }

  for (const bot of BOT_PLAYERS) {
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
      energy: 100,
      hp: 100,
      status: 'active',
      isBot: true,
      score: bot.power * 30 + bot.cash / 100,
      updatedAt: admin.firestore.Timestamp.now(),
    }, { merge: true });
  }

  await batch.commit();
  return { ok: true, gangs: BOT_GANGS.length, players: BOT_PLAYERS.length };
});

exports.botActivityLoop = onSchedule('every 10 minutes', async () => {
  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();

  for (const bot of BOT_PLAYERS) {
    const rnd = Math.random();
    const cashGain = Math.floor(Math.random() * 800 + 200);
    const xpGain   = Math.floor(Math.random() * 30 + 5);
    const powerDelta = Math.random() < 0.1 ? Math.floor(Math.random() * 10 + 1) : 0;

    const userRef = db.collection('users').doc(bot.id);

    if (rnd < 0.6) {
      // Görev yaptı
      batch.set(userRef, {
        cash: admin.firestore.FieldValue.increment(cashGain),
        xp:   admin.firestore.FieldValue.increment(xpGain),
        power: admin.firestore.FieldValue.increment(powerDelta),
        score: admin.firestore.FieldValue.increment(cashGain / 10 + xpGain),
        updatedAt: now,
      }, { merge: true });
    } else if (rnd < 0.85) {
      // Saldırı kaybetti, biraz hasar aldı
      batch.set(userRef, {
        updatedAt: now,
      }, { merge: true });
    } else {
      // Saldırı kazandı, nakit çaldı
      const loot = Math.floor(Math.random() * 300 + 100);
      batch.set(userRef, {
        cash:  admin.firestore.FieldValue.increment(loot),
        score: admin.firestore.FieldValue.increment(loot / 10),
        updatedAt: now,
      }, { merge: true });

      // Saldırı kaydı oluştur (gerçek oyunculara görünsün)
      const realUsers = await db.collection('users')
        .where('isBot', '==', false)
        .limit(5)
        .get();
      if (!realUsers.empty) {
        const target = realUsers.docs[Math.floor(Math.random() * realUsers.docs.length)];
        const atkRef = db.collection('attacks').doc();
        batch.set(atkRef, {
          attackerId: bot.id,
          attackerName: bot.name,
          targetId: target.id,
          targetName: target.data().displayName ?? 'Oyuncu',
          outcome: 'win',
          type: 'quick',
          stolenCash: loot,
          xpGained: xpGain,
          timestamp: now,
        });
      }
    }
  }

  // Çete güç toplamlarını güncelle
  for (const gang of BOT_GANGS) {
    const gangRef = db.collection('gangs').doc(gang.id);
    const botMembers = BOT_PLAYERS.filter(p => p.gangId === gang.id);
    // Firestore'daki güncel güçleri topla
    const memberSnaps = await Promise.all(
      botMembers.map(b => db.collection('users').doc(b.id).get())
    );
    const totalPower = memberSnaps.reduce((s, snap) => {
      return s + ((snap.data()?.power) ?? 0);
    }, 0);
    batch.update(gangRef, {
      totalPower,
      respectPoints: Math.floor(totalPower * 1.1),
      updatedAt: now,
    });
  }

  await batch.commit();
  console.log('Bot activity loop completed.');
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
