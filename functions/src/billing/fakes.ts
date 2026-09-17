/**
 * A minimal, in-memory Firestore double for the billing module's tests
 * — not itself a test file (see `package.json`'s `test` script, which
 * only picks up `*.test.js`). Supports exactly the surface the billing
 * module uses: nested collection()/doc() chains, get/set, a single
 * `where(field, "==", value).limit(n)` query shape (used by
 * `findHousePassForInspection`), and `runTransaction` with
 * transactional get/set applied directly against the same in-memory
 * store (our fakes are single-threaded, so this is sufficient to test
 * the billing module's read-then-write logic without simulating real
 * optimistic-concurrency retries).
 */

type DocData = Record<string, unknown>;

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

  const db: FakeFirestore = {
    collection: (name: string) => collectionRef(name),
    runTransaction: async (fn) => {
      const tx: FakeTransaction = {
        get: (ref) => ref.get(),
        set: (ref, data) => {
          store.set(ref.path, data);
        },
      };
      return fn(tx);
    },
  };
  return {db, store};
}
