import type {Firestore, Transaction} from "firebase-admin/firestore";
import {
  AiLevel,
  WALLET_DOC_ID,
  WalletBalance,
  WalletTransaction,
  WalletTransactionType,
} from "./types";

/**
 * The Credits ledger — the authoritative, auditable source of truth
 * for every user's balance (see docs/commercial_model.md, "Wallet
 * ledger"). `users/{uid}/wallet/main` is a transactionally-maintained
 * *cache* of the balance, always derived from and kept consistent with
 * `users/{uid}/walletTransactions/{id}` via Firestore transactions —
 * never mutated independently of a ledger entry.
 *
 * Settlement model (why "usage" never independently touches balance):
 * a `reservation` debits the full worst-case (`maximumCredits`) amount
 * up front. Once the real cost is known, `settleReservation` credits
 * back any unused portion as a `reservationRelease` and writes a
 * purely informational `usage` record of the real amount actually
 * consumed — `usage` never itself moves the balance a second time,
 * since the reservation already did. A full failure instead releases
 * the *entire* reservation via `releaseReservation`.
 *
 * Idempotency: every mutating function takes an `idempotencyKey`,
 * which becomes that ledger entry's own Firestore document id. A
 * retried call (double-tap, Functions retry, a replayed webhook) with
 * the same key can never create a second entry or move the balance
 * twice — see `runIdempotentMutation`.
 */

/**
 * Thrown when a settlement and a failure-release are both attempted for
 * the same reservation. Exactly one of them may ever apply: a settled
 * reservation must never also be refunded in full, and a released one
 * must never also be charged.
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

/** Thrown when a reservation/purchase would exceed the wallet's
 * current Credits balance. */
export class InsufficientCreditsError extends Error {
  /**
   * @param {number} availableCredits the wallet's current balance.
   * @param {number} requiredCredits the amount the operation needed.
   */
  constructor(
    public readonly availableCredits: number,
    public readonly requiredCredits: number
  ) {
    super(
      `Insufficient Credits: required ${requiredCredits}, available ` +
        `${availableCredits}.`
    );
    this.name = "InsufficientCreditsError";
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
 * @param {string} uid the wallet owner.
 * @return {Promise<number>} the current cached balance (0 if the
 *   wallet has never been touched).
 */
export async function getWalletBalance(
  db: Firestore,
  uid: string
): Promise<number> {
  const snap = await walletRef(db, uid).get();
  if (!snap.exists) return 0;
  return (snap.data() as WalletBalance).balanceCredits;
}

interface MutationOutcome {
  balanceDelta: number;
  transaction: Omit<
    WalletTransaction,
    "id" | "userId" | "createdAt" | "updatedAt" | "idempotencyKey"
  >;
}

/**
 * Runs one idempotent balance mutation inside a Firestore transaction.
 * If a ledger entry already exists at `idempotencyKey`, that prior
 * result is returned unchanged (no re-execution, no double mutation) —
 * this is what makes a retried call safe. Otherwise, `compute` decides
 * the balance delta and the ledger entry to record, both applied
 * atomically with the read that informed them (so a concurrent
 * mutation for the same user can never race past a stale balance
 * read).
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the wallet owner.
 * @param {string} idempotencyKey this attempt's idempotency key —
 *   becomes the ledger entry's document id.
 * @param {Function} compute decides the mutation from the current
 *   balance, read inside the same transaction — `(tx: Transaction,
 *   currentBalance: number) => Promise<MutationOutcome>`.
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
    const currentBalance = balSnap.exists ?
      (balSnap.data() as WalletBalance).balanceCredits :
      0;

    const outcome = await compute(tx, currentBalance);
    const now = Date.now();

    const record: WalletTransaction = {
      id: idempotencyKey,
      userId: uid,
      idempotencyKey,
      createdAt: now,
      updatedAt: now,
      ...outcome.transaction,
    };

    tx.set(balRef, {
      userId: uid,
      balanceCredits: currentBalance + outcome.balanceDelta,
      updatedAt: now,
    } satisfies WalletBalance);
    tx.set(txnRef, record);

    return record;
  });
}

/**
 * Records a completed top-up — only ever called after a payment
 * provider (or, in sandbox/test mode, `SandboxPaymentService`) has
 * confirmed payment; Flutter is never trusted to assert success itself.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the top-up details.
 * @return {Promise<WalletTransaction>} the top-up ledger entry.
 */
export async function recordTopUp(
  db: Firestore,
  params: {
    uid: string;
    amountCredits: number;
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
      balanceDelta: params.amountCredits,
      transaction: {
        type: "topup" as WalletTransactionType,
        direction: "credit",
        amountCredits: params.amountCredits,
        status: "completed",
        externalPaymentRef: params.externalPaymentRef,
        description: params.description,
      },
    })
  );
}

/**
 * Holds `amountCredits` (the worst-case maximum for one AI analysis)
 * against the wallet. Throws [InsufficientCreditsError] — never
 * silently reserves a partial amount — if the balance can't cover it.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the reservation details.
 * @return {Promise<WalletTransaction>} the reservation ledger entry.
 */
export async function reserveCredits(
  db: Firestore,
  params: {
    uid: string;
    amountCredits: number;
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
      if (currentBalance < params.amountCredits) {
        throw new InsufficientCreditsError(
          currentBalance,
          params.amountCredits
        );
      }
      return {
        balanceDelta: -params.amountCredits,
        transaction: {
          type: "reservation",
          direction: "debit",
          amountCredits: params.amountCredits,
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
 * Settles a reservation once the real AI cost is known: refunds any
 * unused portion and records the real amount as an informational
 * `usage` entry (see the module doc comment for why `usage` never
 * independently mutates the balance).
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the settlement details.
 * @return {Promise<WalletTransaction>} the `usage` ledger entry.
 */
export async function settleReservation(
  db: Firestore,
  params: {
    uid: string;
    reservationTransactionId: string;
    actualCredits: number;
    idempotencyKey: string;
    description: string;
    /** A ledger entry id (the failure-release for this reservation)
     * whose existence means this settlement must never apply. */
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
  // Never charge more than what was reserved (what the inspector
  // actually approved) — clamp defensively even though
  // `actualCreditsForUsage` should already stay within the estimate.
  const actualCredits = Math.min(
    params.actualCredits,
    reservation.amountCredits
  );
  const unusedCredits = reservation.amountCredits - actualCredits;

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
      if (unusedCredits > 0) {
        const releaseRef = transactionRef(
          db,
          params.uid,
          `${params.idempotencyKey}_release`
        );
        const now = Date.now();
        tx.set(releaseRef, {
          id: `${params.idempotencyKey}_release`,
          userId: params.uid,
          idempotencyKey: `${params.idempotencyKey}_release`,
          type: "reservationRelease",
          direction: "credit",
          amountCredits: unusedCredits,
          status: "completed",
          relatedTransactionId: params.reservationTransactionId,
          inspectionId: reservation.inspectionId,
          findingId: reservation.findingId,
          aiLevel: reservation.aiLevel,
          description: "Unused AI Credits returned",
          createdAt: now,
          updatedAt: now,
        } satisfies WalletTransaction);
      }
      return {
        balanceDelta: unusedCredits,
        transaction: {
          type: "usage",
          direction: "debit",
          amountCredits: actualCredits,
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
 * Releases a reservation in full — the AI job never produced a
 * chargeable result (a failed classification). The inspector is never
 * charged Credits for a failed analysis.
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
        balanceDelta: reservation.amountCredits,
        transaction: {
          type: "reservationRelease",
          direction: "credit",
          amountCredits: reservation.amountCredits,
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
 * House Pass is bought with real money, not Credits — this entry
 * deliberately moves 0 Credits (see the module doc comment).
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the purchase details.
 * @return {Promise<WalletTransaction>} the purchase ledger entry.
 */
export async function recordHousePassPurchase(
  db: Firestore,
  params: {
    uid: string;
    amountCredits: number;
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
      // House Pass is a separate fixed-price product, not paid for
      // with Credits — this ledger entry records the purchase event
      // for a unified activity feed, but deliberately moves 0 Credits.
      balanceDelta: 0,
      transaction: {
        type: "housePassPurchase",
        direction: "credit",
        amountCredits: params.amountCredits,
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
 * Credits, or a correction) — never triggered from Flutter.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the adjustment details. A negative
 *   `amountCredits` debits the wallet.
 * @return {Promise<WalletTransaction>} the adjustment ledger entry.
 */
export async function recordAdjustment(
  db: Firestore,
  params: {
    uid: string;
    amountCredits: number;
    idempotencyKey: string;
    description: string;
  }
): Promise<WalletTransaction> {
  return runIdempotentMutation(
    db,
    params.uid,
    params.idempotencyKey,
    async () => ({
      balanceDelta: params.amountCredits,
      transaction: {
        type: "adjustment",
        direction: params.amountCredits >= 0 ? "credit" : "debit",
        amountCredits: Math.abs(params.amountCredits),
        status: "completed",
        description: params.description,
      },
    })
  );
}
