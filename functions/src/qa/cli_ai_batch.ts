#!/usr/bin/env node
import * as fs from "node:fs";
import * as path from "node:path";
import {parseArgs} from "./args";
import {levelConfigFor, parseLevel, runLiveCase} from "./live";
import {
  BatchExpectation,
  meetsExpectation,
  outcomeLabel,
} from "./live_report";

/** Safety: paid calls above this need --allow-large-batch. */
export const DEFAULT_MAX_CALLS = 30;
/** Hard ceiling even with --allow-large-batch. */
export const ABSOLUTE_MAX_CALLS = 200;

interface FixtureCase extends BatchExpectation {
  name: string;
  note: string;
  image: string;
  area?: string;
}

/**
 * `npm run qa:ai-batch -- fixtures.json [--runs 5] [--level smart]
 * [--max-calls 30] [--allow-large-batch] [--dry-run]`.
 * @return {Promise<void>} resolves when done.
 */
async function main(): Promise<void> {
  const {flags, positional} = parseArgs(process.argv.slice(2));
  const file = positional[0];
  if (!file) {
    console.error("usage: npm run qa:ai-batch -- <fixtures.json> " +
      "[--runs N] [--level fast|smart|expert] [--max-calls N] " +
      "[--allow-large-batch] [--dry-run]");
    process.exit(2);
  }
  const cases = JSON.parse(fs.readFileSync(file, "utf8")) as FixtureCase[];
  const runs = Math.max(1, Number(flags.runs ?? 1) || 1);
  const level = parseLevel(flags.level);
  const total = cases.length * runs;
  const limit = Number(flags["max-calls"] ?? DEFAULT_MAX_CALLS);
  const config = levelConfigFor(level);

  console.log(`LIVE AI QA BATCH — ${cases.length} case(s) x ${runs} run(s) ` +
    `= ${total} PAID provider call(s) (${config.provider}/${config.model}, ` +
    `level ${level}).`);
  if (total > ABSOLUTE_MAX_CALLS ||
    (total > limit && flags["allow-large-batch"] !== true)) {
    console.error(`Refusing: ${total} calls exceeds the safety limit of ` +
      `${limit}${total > ABSOLUTE_MAX_CALLS ?
        ` (absolute maximum ${ABSOLUTE_MAX_CALLS})` :
        " — pass --allow-large-batch to override"}.`);
    process.exit(2);
  }
  for (const c of cases) {
    if (!fs.existsSync(path.resolve(c.image))) {
      console.error(`image not found for "${c.name}": ${c.image}`);
      process.exit(2);
    }
  }
  if (flags["dry-run"] === true) {
    console.log("Dry run: no provider call made.");
    return;
  }

  let passed = 0;
  let failed = 0;
  const results: Array<{name: string; outcomes: string[]; pass: number}> = [];
  for (const c of cases) {
    const outcomes: string[] = [];
    let pass = 0;
    for (let i = 0; i < runs; i++) {
      const run = await runLiveCase({
        note: c.note, imagePath: path.resolve(c.image), level, area: c.area,
      });
      const ok = meetsExpectation(run, c);
      outcomes.push(outcomeLabel(run));
      if (ok) {
        pass++;
        passed++;
      } else {
        failed++;
      }
      if (runs === 1) {
        console.log(`${ok ? "PASS" : "FAIL"} ${c.name.padEnd(24)} → ` +
          outcomeLabel(run) +
          (run.diagnostics ? `   [${run.diagnostics.postProcessingDecision}]` :
            ""));
      }
    }
    results.push({name: c.name, outcomes, pass});
  }

  if (runs > 1) {
    console.log("");
    for (const r of results) {
      const tally = new Map<string, number>();
      r.outcomes.forEach((o) => tally.set(o, (tally.get(o) ?? 0) + 1));
      console.log(`${r.name}:   (${r.pass}/${runs} met the expectation)`);
      for (const [label, n] of tally) console.log(`  ${n}/${runs} ${label}`);
    }
  }
  const totalRuns = passed + failed;
  console.log(`\nPassed: ${passed}\nFailed: ${failed}\nPass rate: ` +
    `${totalRuns === 0 ? 0 : Math.round((passed / totalRuns) * 100)}%`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
