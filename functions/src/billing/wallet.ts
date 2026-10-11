import type {Firestore, Transaction} from "firebase-admin/firestore";
import {
  AiLevel,
  WALLET_DOC_ID,
  WalletBalance,
  WalletTransaction,
  WalletTransactionType,
} from "./types";
import {
  LEGACY_CREDITS_PER_MYR,
  assertTokenAmount,
  tokensForLegacyCredits,
} from "./tokens";
import type {UsageRecord} from "./usage_cost";

/**
 * The ProDefact Token ledger — the authoritative, auditable source of
 * truth for every user's balance (see docs/token_billing.md).
 * `users/{uid}/wallet/main` is a transactionally-maintained *cache* of
 * the balance, always derived from and kept consistent with
 * `users/{uid}/walletTransactions/{id}` via Firestore transactions —
 * never mutated independently of a ledger entry. Every amount is a
 * whole number of Tokens (see `tokens.ts`).
 *
 * Settlement model (why "usage" never independently touches balance):
 * a `reservation` debits the full worst-case amount up front. Once the
 * real cost is known, `settleReservation` credits back any unused
 * portion as a `reservationRelease` and writes a purely informational
 * `usage` record of the real amount actually consumed — `usage` never
 * itself moves the balance a second time. A full failure instead
 * releases the *entire* reservation via `releaseReservation`.
 *
 * Idempotency: every mutating function takes an `idempotencyKey`,
 * which becomes that ledger entry's own Firestore document id. A
 * retried call with the same key can never create a second entry or
 * move the balance twice — see `runIdempotentMutation`. The cost audit
 * record (`users/{uid}/usageRecords/{usageId}`) is written in the same
 * transaction as the settlement, keyed by the operation's own key, so
 * one operation is recorded and charged exactly once.
 *
 * Legacy Credits: a wallet written before Tokens has only
 * `balanceCredits`. The first transaction that touches it converts the
 * balance to Tokens of the same RM value (100 Credits = RM1 = 1,000,000
 * Tokens, i.e. 10,000 Tokens per Credit) and records one
 * `legacyMigration` ledger entry. Historical Credits entries are kept
 * exactly as written — never rewritten, never re-priced.
 */

/** The fixed id of the one-off legacy conversion ledger entry. */
export const LEGACY_MIGRATION_ENTRY_ID = "legacy_credits_to_tokens_v1";

/**
 * Thrown when a settlement and a failure-release are both attempted for
 * the same reservation. Exactly one of them may ever apply.
 */
export class ConflictingLedgerEntryError extends Error {
  /**
   * @param {string} attempted the ledger entry that was refused.
   * @param {string} existing the entry that already applied.
   */
  constructor(attempted: string, existing: string) {
    super(
      `Ledger entry ${attempted} refused: ${existing} already applied ` +
        "to the same reservation."
    );
    this.name = "ConflictingLedgerEntryError";
  }
}

/** Thrown when a reservation would exceed the wallet's Token balance. */
export class InsufficientTokensError extends Error {
  /**
   * @param {number} availableTokens the wallet's current balance.
   * @param {number} requiredTokens the amount the operation needed.
   */
  constructor(
    public readonly availableTokens: number,
    public readonly requiredTokens: number
  ) {
    super(
      `Insufficient Tokens: required ${requiredTokens}, available ` +
        `${availableTokens}.`
    );
    this.name = "InsufficientTokensError";
  }
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the wallet owner.
 * @return {FirebaseFirestore.DocumentReference} the cached-balance doc.
 */
function walletRef(db: Firestore, uid: string) {
  return db.collection("users").doc(uid).collection("wallet").doc(
    WALLET_DOC_ID
  );
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the wallet owner.
 * @param {string} id the ledger entry's document id.
 * @return {FirebaseFirestore.DocumentReference} the ledger entry doc.
 */
function transactionRef(db: Firestore, uid: string, id: string) {
  return db.collection("users").doc(uid).collection("walletTransactions").doc(
    id
  );
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the record owner.
 * @param {string} usageId the operation's idempotency key.
 * @return {FirebaseFirestore.DocumentReference} the usage record doc.
 */
export function usageRecordRef(db: Firestore, uid: string, usageId: string) {
  return db.collection("users").doc(uid).collection("usageRecords").doc(
    usageId
  );
}

interface WalletState {
  /** The spendable balance, in whole Tokens. */
  balanceTokens: number;
  /** Set when the stored wallet is still in legacy Credits. */
  legacyCredits?: number;
}

/**
 * Reads a stored wallet document as Tokens, converting a legacy
 * Credits balance at its RM value without writing anything.
 * @param {Record<string, unknown> | undefined} data the wallet doc data.
 * @param {number} legacyCreditsPerMyr the legacy Credits rate.
 * @return {WalletState} the Token balance (and legacy Credits, if any).
 */
export function walletStateOf(
  data: Record<string, unknown> | undefined,
  legacyCreditsPerMyr: number = LEGACY_CREDITS_PER_MYR
): WalletState {
  if (!data) return {balanceTokens: 0};
  if (typeof data.balanceTokens === "number") {
    return {balanceTokens: data.balanceTokens};
  }
  const credits = typeof data.balanceCredits === "number" ?
    data.balanceCredits :
    0;
  return {
    balanceTokens: tokensForLegacyCredits(credits, legacyCreditsPerMyr),
    legacyCredits: credits,
  };
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the wallet owner.
 * @return {Promise<number>} the current balance in Tokens (0 if the
 *   wallet has never been touched; a legacy Credits balance is read at
 *   its Token value).
 */
export async function getWalletBalance(
  db: Firestore,
  uid: string
): Promise<number> {
  const snap = await walletRef(db, uid).get();
  return walletStateOf(
    snap.exists ? snap.data() as Record<string, unknown> : undefined
  ).balanceTokens;
}

interface MutationOutcome {
  balanceDelta: number;
  transaction: Omit<
    WalletTransaction,
    "id" | "userId" | "createdAt" | "updatedAt" | "idempotencyKey" | "unit"
  >;
}

/**
 * Inside [tx]: if the wallet is still in legacy Credits, records the
 * one-off `legacyMigration` ledger entry. The caller then writes the
 * wallet with `balanceTokens` (keeping `balanceCredits` frozen for
 * audit).
 * @param {Transaction} tx the open transaction.
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the wallet owner.
 * @param {WalletState} state the wallet as read in [tx].
 * @param {number} now the timestamp.
 */
function writeLegacyMigrationIfNeeded(
  tx: Transaction,
  db: Firestore,
  uid: string,
  state: WalletState,
  now: number
): void {
  if (state.legacyCredits === undefined) return;
  tx.set(transactionRef(db, uid, LEGACY_MIGRATION_ENTRY_ID), {
    id: LEGACY_MIGRATION_ENTRY_ID,
    userId: uid,
    idempotencyKey: LEGACY_MIGRATION_ENTRY_ID,
    type: "legacyMigration",
    direction: "credit",
    amountTokens: state.balanceTokens,
    unit: "tokens",
    legacyAmountCredits: state.legacyCredits,
    status: "completed",
    description:
      `${state.legacyCredits} Credits converted to ` +
      `${state.balanceTokens} Tokens (same RM value)`,
    createdAt: now,
    updatedAt: now,
  } satisfies WalletTransaction);
}

/**
 * Converts a legacy Credits wallet to Tokens now (idempotent; a no-op
 * for a Token wallet or a never-touched one). Called on app start via
 * `getCommercialConfig` so the app sees Tokens promptly.
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the wallet owner.
 * @param {number} legacyCreditsPerMyr the legacy Credits rate.
 * @return {Promise<boolean>} whether a conversion happened now.
 */
export async function migrateLegacyWallet(
  db: Firestore,
  uid: string,
  legacyCreditsPerMyr: number = LEGACY_CREDITS_PER_MYR
): Promise<boolean> {
  const balRef = walletRef(db, uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(balRef);
    if (!snap.exists) return false;
    const data = snap.data() as Record<string, unknown>;
    const state = walletStateOf(data, legacyCreditsPerMyr);
    if (state.legacyCredits === undefined) return false;
    const now = Date.now();
    writeLegacyMigrationIfNeeded(tx, db, uid, state, now);
    tx.set(balRef, {
      ...data,
      userId: uid,
      balanceTokens: state.balanceTokens,
      balanceCredits: state.legacyCredits,
      legacyCreditsMigratedAt: now,
      updatedAt: now,
    });
    return true;
  });
}

/**
 * Runs one idempotent balance mutation inside a Firestore transaction.
 * If a ledger entry already exists at `idempotencyKey`, that prior
 * result is returned unchanged (no re-execution, no double mutation).
 * Otherwise `compute` decides the balance delta and the ledger entry,
 * both applied atomically with the read that informed them.
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the wallet owner.
 * @param {string} idempotencyKey becomes the ledger entry's id.
 * @param {Function} compute decides the mutation from the current
 *   Token balance, read inside the same transaction.
 * @return {Promise<WalletTransaction>} the resulting (or pre-existing,
 *   on a replay) ledger entry.
 */
async function runIdempotentMutation(
  db: Firestore,
  uid: string,
  idempotencyKey: string,
  compute: (
    tx: Transaction,
    currentBalance: number
  ) => Promise<MutationOutcome>
): Promise<WalletTransaction> {
  const txnRef = transactionRef(db, uid, idempotencyKey);
  const balRef = walletRef(db, uid);

  return db.runTransaction(async (tx) => {
    const existing = await tx.get(txnRef);
    if (existing.exists) {
      return existing.data() as WalletTransaction;
    }

    const balSnap = await tx.get(balRef);
    const balData = balSnap.exists ?
      balSnap.data() as Record<string, unknown> :
      undefined;
    const state = walletStateOf(balData);

    const outcome = await compute(tx, state.balanceTokens);
    assertTokenAmount(Math.abs(outcome.balanceDelta), "balanceDelta");
    assertTokenAmount(outcome.transaction.amountTokens, "amountTokens");
    const newBalance = assertTokenAmount(
      state.balanceTokens + outcome.balanceDelta,
      "balanceTokens"
    );
    const now = Date.now();

    const record: WalletTransaction = {
      id: idempotencyKey,
      userId: uid,
      idempotencyKey,
      createdAt: now,
      updatedAt: now,
      unit: "tokens",
      ...outcome.transaction,
    };

    writeLegacyMigrationIfNeeded(tx, db, uid, state, now);
    const wallet: WalletBalance = {
      userId: uid,
      balanceTokens: newBalance,
      updatedAt: now,
    };
    if (state.legacyCredits !== undefined) {
      wallet.balanceCredits = state.legacyCredits;
      wallet.legacyCreditsMigratedAt = now;
    } else if (balData) {
      if (typeof balData.balanceCredits === "number") {
        wallet.balanceCredits = balData.balanceCredits;
      }
      if (typeof balData.legacyCreditsMigratedAt === "number") {
        wallet.legacyCreditsMigratedAt = balData.legacyCreditsMigratedAt;
      }
    }
    tx.set(balRef, wallet);
    tx.set(txnRef, record);

    return record;
  });
}

/**
 * Records a completed top-up — only ever called after a payment
 * provider (or, in sandbox mode, `SandboxPaymentService`) has confirmed
 * payment; Flutter is never trusted to assert success itself.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the top-up details.
 * @return {Promise<WalletTransaction>} the top-up ledger entry.
 */
export async function recordTopUp(
  db: Firestore,
  params: {
    uid: string;
    amountTokens: number;
    idempotencyKey: string;
    externalPaymentRef: string;
    description: string;
  }
): Promise<WalletTransaction> {
  return runIdempotentMutation(
    db,
    params.uid,
    params.idempotencyKey,
    async () => ({
      balanceDelta: params.amountTokens,
      transaction: {
        type: "topup" as WalletTransactionType,
        direction: "credit",
        amountTokens: params.amountTokens,
        status: "completed",
        externalPaymentRef: params.externalPaymentRef,
        description: params.description,
      },
    })
  );
}

/**
 * Holds `amountTokens` (the worst-case maximum for one AI analysis)
 * against the wallet. Throws [InsufficientTokensError] — never
 * silently reserves a partial amount — if the balance can't cover it.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the reservation details.
 * @return {Promise<WalletTransaction>} the reservation ledger entry.
 */
export async function reserveTokens(
  db: Firestore,
  params: {
    uid: string;
    amountTokens: number;
    idempotencyKey: string;
    inspectionId: string;
    findingId: string;
    aiLevel: AiLevel;
    description: string;
  }
): Promise<WalletTransaction> {
  return runIdempotentMutation(
    db,
    params.uid,
    params.idempotencyKey,
    async (_tx, currentBalance) => {
      if (currentBalance < params.amountTokens) {
        throw new InsufficientTokensError(
          currentBalance,
          params.amountTokens
        );
      }
      return {
        balanceDelta: -params.amountTokens,
        transaction: {
          type: "reservation",
          direction: "debit",
          amountTokens: params.amountTokens,
          status: "completed",
          inspectionId: params.inspectionId,
          findingId: params.findingId,
          aiLevel: params.aiLevel,
          description: params.description,
        },
      };
    }
  );
}

/**
 * @param {Record<string, unknown>} entry a stored ledger entry.
 * @return {number} its amount in Tokens (a legacy Credits entry is read
 *   at its Token value).
 */
function amountTokensOf(entry: Record<string, unknown>): number {
  if (typeof entry.amountTokens === "number") return entry.amountTokens;
  return tokensForLegacyCredits(
    typeof entry.amountCredits === "number" ? entry.amountCredits : 0,
    LEGACY_CREDITS_PER_MYR
  );
}

/**
 * Settles a reservation once the real cost is known: refunds any
 * unused portion, records the real amount as an informational `usage`
 * entry, and (when given) writes the operation's cost audit record —
 * all in one transaction.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the settlement details.
 * @return {Promise<WalletTransaction>} the `usage` ledger entry.
 */
export async function settleReservation(
  db: Firestore,
  params: {
    uid: string;
    reservationTransactionId: string;
    actualTokens: number;
    idempotencyKey: string;
    description: string;
    /** A ledger entry id (the failure-release for this reservation)
     * whose existence means this settlement must never apply. */
    exclusiveOf?: string;
    /** The operation's cost record; written once, with this entry. */
    usageRecord?: UsageRecord;
  }
): Promise<WalletTransaction> {
  const reservationSnap = await transactionRef(
    db,
    params.uid,
    params.reservationTransactionId
  ).get();
  if (!reservationSnap.exists) {
    throw new Error(
      `Reservation ${params.reservationTransactionId} not found.`
    );
  }
  const reservation = reservationSnap.data() as WalletTransaction;
  const reservedTokens = amountTokensOf(
    reservation as unknown as Record<string, unknown>
  );
  // Never charge more than what was reserved (what the inspector
  // approved) — clamp defensively.
  const actualTokens = Math.min(params.actualTokens, reservedTokens);
  const unusedTokens = reservedTokens - actualTokens;

  return runIdempotentMutation(
    db,
    params.uid,
    params.idempotencyKey,
    async (tx) => {
      if (params.exclusiveOf) {
        const conflicting = await tx.get(
          transactionRef(db, params.uid, params.exclusiveOf)
        );
        if (conflicting.exists) {
          throw new ConflictingLedgerEntryError(
            params.idempotencyKey,
            params.exclusiveOf
          );
        }
      }
      if (params.usageRecord) {
        const ref = usageRecordRef(db, params.uid, params.usageRecord.usageId);
        const existing = await tx.get(ref);
        if (!existing.exists) {
          tx.set(ref, {...params.usageRecord, tokensCharged: actualTokens});
        }
      }
      if (unusedTokens > 0) {
        const releaseId = `${params.idempotencyKey}_release`;
        const now = Date.now();
        const release: WalletTransaction = {
          id: releaseId,
          userId: params.uid,
          idempotencyKey: releaseId,
          type: "reservationRelease",
          direction: "credit",
          amountTokens: unusedTokens,
          unit: "tokens",
          status: "completed",
          relatedTransactionId: params.reservationTransactionId,
          description: "Unused Tokens returned",
          createdAt: now,
          updatedAt: now,
        };
        if (reservation.inspectionId) {
          release.inspectionId = reservation.inspectionId;
        }
        if (reservation.findingId) release.findingId = reservation.findingId;
        if (reservation.aiLevel) release.aiLevel = reservation.aiLevel;
        tx.set(transactionRef(db, params.uid, releaseId), release);
      }
      return {
        balanceDelta: unusedTokens,
        transaction: {
          type: "usage",
          direction: "debit",
          amountTokens: actualTokens,
          status: "completed",
          relatedTransactionId: params.reservationTransactionId,
          inspectionId: reservation.inspectionId,
          findingId: reservation.findingId,
          aiLevel: reservation.aiLevel,
          description: params.description,
        },
      };
    }
  );
}

/**
 * Writes an operation's cost audit record when no Tokens move (e.g. an
 * analysis fully included in a House Pass). Idempotent by `usageId`.
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the record owner.
 * @param {UsageRecord} record the record.
 * @return {Promise<boolean>} whether it was written now (false on a
 *   replay).
 */
export async function recordUsageOnce(
  db: Firestore,
  uid: string,
  record: UsageRecord
): Promise<boolean> {
  const ref = usageRecordRef(db, uid, record.usageId);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return false;
    tx.set(ref, record);
    return true;
  });
}

/**
 * Releases a reservation in full — the AI job never produced a
 * chargeable result. The inspector is never charged for a failed
 * analysis.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the release details.
 * @return {Promise<WalletTransaction>} the release ledger entry.
 */
export async function releaseReservation(
  db: Firestore,
  params: {
    uid: string;
    reservationTransactionId: string;
    idempotencyKey: string;
    description: string;
    /** A ledger entry id (the settlement for this reservation) whose
     * existence means this full refund must never apply. */
    exclusiveOf?: string;
  }
): Promise<WalletTransaction> {
  const reservationSnap = await transactionRef(
    db,
    params.uid,
    params.reservationTransactionId
  ).get();
  if (!reservationSnap.exists) {
    throw new Error(
      `Reservation ${params.reservationTransactionId} not found.`
    );
  }
  const reservation = reservationSnap.data() as WalletTransaction;
  const reservedTokens = amountTokensOf(
    reservation as unknown as Record<string, unknown>
  );

  return runIdempotentMutation(
    db,
    params.uid,
    params.idempotencyKey,
    async (tx) => {
      if (params.exclusiveOf) {
        const conflicting = await tx.get(
          transactionRef(db, params.uid, params.exclusiveOf)
        );
        if (conflicting.exists) {
          throw new ConflictingLedgerEntryError(
            params.idempotencyKey,
            params.exclusiveOf
          );
        }
      }
      return {
        balanceDelta: reservedTokens,
        transaction: {
          type: "reservationRelease",
          direction: "credit",
          amountTokens: reservedTokens,
          status: "completed",
          relatedTransactionId: params.reservationTransactionId,
          inspectionId: reservation.inspectionId,
          findingId: reservation.findingId,
          aiLevel: reservation.aiLevel,
          description: params.description,
        },
      };
    }
  );
}

/**
 * Records a completed House Pass purchase in the unified activity feed.
 * House Pass is bought with real money, not Tokens — this entry
 * deliberately moves 0 Tokens.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the purchase details.
 * @return {Promise<WalletTransaction>} the purchase ledger entry.
 */
export async function recordHousePassPurchase(
  db: Firestore,
  params: {
    uid: string;
    amountTokens: number;
    idempotencyKey: string;
    inspectionId: string;
    externalPaymentRef: string;
    description: string;
  }
): Promise<WalletTransaction> {
  return runIdempotentMutation(
    db,
    params.uid,
    params.idempotencyKey,
    async () => ({
      balanceDelta: 0,
      transaction: {
        type: "housePassPurchase",
        direction: "credit",
        amountTokens: params.amountTokens,
        status: "completed",
        inspectionId: params.inspectionId,
        externalPaymentRef: params.externalPaymentRef,
        description: params.description,
      },
    })
  );
}

/**
 * Records a manual balance adjustment (e.g. support-issued goodwill
 * Tokens, or a correction) — never triggered from Flutter.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the adjustment details. A negative
 *   `amountTokens` debits the wallet.
 * @return {Promise<WalletTransaction>} the adjustment ledger entry.
 */
export async function recordAdjustment(
  db: Firestore,
  params: {
    uid: string;
    amountTokens: number;
    idempotencyKey: string;
    description: string;
  }
): Promise<WalletTransaction> {
  return runIdempotentMutation(
    db,
    params.uid,
    params.idempotencyKey,
    async () => ({
      balanceDelta: params.amountTokens,
      transaction: {
        type: "adjustment",
        direction: params.amountTokens >= 0 ? "credit" : "debit",
        amountTokens: Math.abs(params.amountTokens),
        status: "completed",
        description: params.description,
      },
    })
  );
}
