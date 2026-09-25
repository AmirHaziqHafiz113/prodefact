import assert from "node:assert/strict";
import {test} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "../billing/fakes";
import {
  handleGetAreaSuggestions,
  handleSubmitAreaCandidate,
  normalizeAreaName,
} from "./area_candidates";

/**
 * QA #12: newly discovered areas become normalised candidates, merged
 * across spellings, and only approved ones are ever suggested.
 */

/** @return {object} an empty fake Firestore and its raw store. */
function empty() {
  const {db, store} = fakeFirestore();
  return {firestore: db as unknown as Firestore, store};
}

test("the QA's bad-data examples all normalise to one master bedroom", () => {
  for (const raw of [
    "Master bedroom",
    "Masterbed",
    "M bedroom",
    "MBR",
    "Master Room",
    "Bilik Master",
    "  master   BEDROOM! ",
  ]) {
    assert.equal(normalizeAreaName(raw), "master bedroom", raw);
  }
});

test("numbering and common rooms normalise consistently", () => {
  assert.equal(normalizeAreaName("Bedroom2"), "bedroom 2");
  assert.equal(normalizeAreaName("bedroom two"), "bedroom 2");
  assert.equal(normalizeAreaName("Bilik Air"), "bathroom");
  assert.equal(normalizeAreaName("Balkoni"), "balcony");
  assert.equal(normalizeAreaName("Laundry Loft"), "laundry loft");
});

test("variants merge into one pending candidate with a usage count and " +
  "the raw spellings, without storing personal data", async () => {
  const {firestore, store} = empty();
  const names = ["Master bedroom", "Masterbed", "MBR", "Bilik Master"];
  for (const [i, rawName] of names.entries()) {
    await handleSubmitAreaCandidate({
      auth: {uid: `uid_${i}`},
      data: {rawName, propertyType: "highRise"},
      firestore,
      now: () => 1000 + i,
    });
  }

  const docs = [...store.entries()].filter(([p]) =>
    p.startsWith("areaCandidates/"));
  assert.equal(docs.length, 1);
  const [path, candidate] = docs[0];
  assert.equal(path, "areaCandidates/highRise__master_bedroom");
  assert.equal(candidate.usageCount, 4);
  assert.equal(candidate.status, "pending");
  assert.equal(candidate.displayName, "Master Bedroom");
  assert.deepEqual(candidate.rawNames, names);
  assert.equal(candidate.createdBy, "uid_0");
  assert.equal(candidate.createdAt, 1000);
  assert.deepEqual(Object.keys(candidate).sort(), [
    "createdAt", "createdBy", "displayName", "key", "normalizedName",
    "propertyType", "rawNames", "status", "updatedAt", "usageCount",
  ]);
});

test("the same name for a different property type is a separate " +
  "candidate", async () => {
  const {firestore, store} = empty();
  for (const propertyType of ["highRise", "landed"]) {
    await handleSubmitAreaCandidate({
      auth: {uid: "uid_1"},
      data: {rawName: "Laundry Loft", propertyType},
      firestore,
    });
  }
  assert.ok(store.has("areaCandidates/highRise__laundry_loft"));
  assert.ok(store.has("areaCandidates/landed__laundry_loft"));
});

test("only approved candidates are suggested; submitting never changes " +
  "the review state", async () => {
  const {firestore, store} = empty();
  await handleSubmitAreaCandidate({
    auth: {uid: "uid_1"},
    data: {rawName: "Laundry Loft", propertyType: "highRise"},
    firestore,
  });
  await handleSubmitAreaCandidate({
    auth: {uid: "uid_1"},
    data: {rawName: "Utility Yard", propertyType: "highRise"},
    firestore,
  });

  let suggestions = await handleGetAreaSuggestions({
    auth: {uid: "uid_2"},
    data: {propertyType: "highRise"},
    firestore,
  });
  assert.deepEqual(suggestions.names, [], "pending is never suggested");

  // A reviewer approves one (an admin action outside the app).
  const path = "areaCandidates/highRise__laundry_loft";
  store.set(path, {...store.get(path), status: "approved"});
  await handleSubmitAreaCandidate({
    auth: {uid: "uid_3"},
    data: {rawName: "laundry loft", propertyType: "highRise"},
    firestore,
  });
  assert.equal(store.get(path)?.status, "approved");

  suggestions = await handleGetAreaSuggestions({
    auth: {uid: "uid_2"},
    data: {propertyType: "highRise"},
    firestore,
  });
  assert.deepEqual(suggestions.names, ["Laundry Loft"]);
});

test("invalid or unauthenticated submissions are rejected", async () => {
  const {firestore} = empty();
  await assert.rejects(
    handleSubmitAreaCandidate({
      auth: null,
      data: {rawName: "Loft", propertyType: "highRise"},
      firestore,
    }),
    (e) => e instanceof HttpsError && e.code === "unauthenticated"
  );
  for (const data of [
    {rawName: "", propertyType: "highRise"},
    {rawName: "x".repeat(61), propertyType: "highRise"},
    {rawName: "Loft", propertyType: "../../users"},
    {rawName: "!!!", propertyType: "highRise"},
  ]) {
    await assert.rejects(
      handleSubmitAreaCandidate({auth: {uid: "u"}, data, firestore}),
      (e) => e instanceof HttpsError && e.code === "invalid-argument",
      JSON.stringify(data)
    );
  }
});
