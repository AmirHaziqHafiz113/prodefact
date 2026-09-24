/**
 * A minimal, in-memory Firestore double for the billing module's tests
 * — not itself a test file (see `package.json`'s `test` script, which
 * only picks up `*.test.js`). Supports exactly the surface the billing
 * module uses: nested collection()/doc() chains, get/set, a single
 * `where(field, "==", value).limit(n)` query shape (used by
 * `findHousePassForInspection`), and `runTransaction` with
 * transactional get/set applied directly against the same in-memory
 * store.
 *
 * Transactions run strictly one at a time. Real Firestore guarantees
 * that concurrent transactions touching the same documents behave as if
 * serialized (via optimistic retries); serializing them here models
 * that guarantee, so concurrent callers (e.g. two invocations racing to
 * claim the same AI job) are tested against the same isolation the
 * production code relies on. Non-transactional reads/writes are not
 * serialized, just as they are not in Firestore.
 */

type DocData = Record<string, unknown>;

/**
 * Real Firestore rejects `undefined` field values outright (`Value
 * for argument "data" is not a valid Firestore document. Cannot use
 * "undefined" as a Firestore value`) unless a client opts into
 * `ignoreUndefinedProperties` — this codebase deliberately does not
 * (see `payment_intent.ts`'s `omitUndefined`). The fake mirrors that
 * rejection so a caller that regresses to writing an omitted-instead
 * -of-undefined optional field is caught here, in-memory, rather than
 * only in a real deployment.
 * @param {DocData} data the candidate document.
 */
function assertNoUndefinedValues(data: DocData): void {
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined) {
      throw new Error(
        "Value for argument \"data\" is not a valid Firestore document. " +
          "Cannot use \"undefined\" as a Firestore value (found in field " +
          `"${key}").`
      );
    }
  }
}

interface FakeDocRef {
  id: string;
  path: string;
  get: () => Promise<{exists: boolean; data: () => DocData | undefined}>;
  set: (data: DocData) => Promise<void>;
  collection: (name: string) => FakeCollectionRef;
}

interface FakeCollectionRef {
  doc: (id: string) => FakeDocRef;
  where: (
    field: string,
    op: "==",
    value: unknown
  ) => {limit: (n: number) => {get: () => Promise<FakeQuerySnapshot>}};
}

interface FakeQuerySnapshot {
  empty: boolean;
  docs: Array<{id: string; data: () => DocData}>;
}

export interface FakeTransaction {
  get: (ref: FakeDocRef) => Promise<{
    exists: boolean;
    data: () => DocData | undefined;
  }>;
  set: (ref: FakeDocRef, data: DocData) => void;
}

export interface FakeFirestore {
  collection: (name: string) => FakeCollectionRef;
  runTransaction: <T>(fn: (tx: FakeTransaction) => Promise<T>) => Promise<T>;
}

/**
 * @param {Record<string, DocData>} [seed] initial documents, keyed by
 *   full slash-joined path (e.g. `"users/uid_1/wallet/main"`).
 * @return {FakeFirestore} the fake Firestore client, castable to the
 *   real `Firestore` type at each call site (as the rest of this
 *   codebase's hand-rolled fakes already do).
 */
export function fakeFirestore(seed: Record<string, DocData> = {}) {
  const store = new Map<string, DocData>(Object.entries(seed));

  /**
   * @param {string} path the document's full path.
   * @return {FakeDocRef} a reference to it.
   */
  function docRef(path: string): FakeDocRef {
    const id = path.split("/").pop() as string;
    return {
      id,
      path,
      get: async () => ({
        exists: store.has(path),
        data: () => store.get(path),
      }),
      set: async (data: DocData) => {
        assertNoUndefinedValues(data);
        store.set(path, data);
      },
      collection: (name: string) => collectionRef(`${path}/${name}`),
    };
  }

  /**
   * @param {string} path the collection's full path.
   * @return {FakeCollectionRef} a reference to it.
   */
  function collectionRef(path: string): FakeCollectionRef {
    return {
      doc: (id: string) => docRef(`${path}/${id}`),
      where: (field: string, op: "==", value: unknown) => ({
        limit: (n: number) => ({
          get: async () => {
            const prefix = `${path}/`;
            const docs = Array.from(store.entries())
              .filter(([p, d]) => {
                if (!p.startsWith(prefix)) return false;
                // Only direct children — not deeper nested paths.
                if (p.slice(prefix.length).includes("/")) return false;
                return op === "==" && d[field] === value;
              })
              .slice(0, n)
              .map(([p, d]) => ({
                id: p.split("/").pop() as string,
                data: () => d,
              }));
            return {empty: docs.length === 0, docs};
          },
        }),
      }),
    };
  }

  let transactionQueue: Promise<unknown> = Promise.resolve();

  const db: FakeFirestore = {
    collection: (name: string) => collectionRef(name),
    runTransaction: <T>(fn: (tx: FakeTransaction) => Promise<T>) => {
      const tx: FakeTransaction = {
        get: (ref) => ref.get(),
        set: (ref, data) => {
          assertNoUndefinedValues(data);
          store.set(ref.path, data);
        },
      };
      const run = transactionQueue.then(() => fn(tx));
      transactionQueue = run.catch(() => undefined);
      return run;
    },
  };
  return {db, store};
}
