import assert from "node:assert/strict";
import {test} from "node:test";
import {DEFAULT_PRICING_CONFIG, isHousePassSafeToSell} from "./pricing_config";

const testConfig = DEFAULT_PRICING_CONFIG.housePass; // environment: "test"
const productionConfig = {...testConfig, environment: "production" as const};

test("isHousePassSafeToSell refuses a `test` allowance when " +
  "PAYMENTS_MODE is unset — the real deploy default — so it can " +
  "never become the de facto production allowance by accident", () => {
  assert.equal(isHousePassSafeToSell(testConfig, {}), false);
});

test("isHousePassSafeToSell refuses a `test` allowance even when " +
  "PAYMENTS_MODE is explicitly \"production\"", () => {
  assert.equal(
    isHousePassSafeToSell(testConfig, {PAYMENTS_MODE: "production"}),
    false
  );
});

test("isHousePassSafeToSell allows a `test` allowance only when " +
  "PAYMENTS_MODE is explicitly \"sandbox\"", () => {
  assert.equal(
    isHousePassSafeToSell(testConfig, {PAYMENTS_MODE: "sandbox"}),
    true
  );
});

test("isHousePassSafeToSell always allows a `production` allowance, " +
  "regardless of PAYMENTS_MODE", () => {
  assert.equal(isHousePassSafeToSell(productionConfig, {}), true);
  assert.equal(
    isHousePassSafeToSell(productionConfig, {PAYMENTS_MODE: "production"}),
    true
  );
});
