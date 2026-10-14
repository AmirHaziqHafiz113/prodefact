#!/usr/bin/env node
import * as fs from "node:fs";
import * as path from "node:path";
import {parseArgs} from "./args";
import {levelConfigFor, parseLevel, runLiveCase} from "./live";
import {formatLiveReport} from "./live_report";

/**
 * `npm run qa:ai -- --note "wall poor skim" --image /abs/wall.jpg
 * --level smart` — ONE paid provider call through the production
 * chain.
 * @return {Promise<void>} resolves when done.
 */
async function main(): Promise<void> {
  const {flags} = parseArgs(process.argv.slice(2));
  const note = flags.note;
  const image = flags.image;
  if (typeof note !== "string" || typeof image !== "string") {
    console.error("usage: npm run qa:ai -- --note \"<note>\" --image " +
      "/absolute/path.jpg [--level fast|smart|expert] [--area \"...\"]");
    process.exit(2);
  }
  const imagePath = path.resolve(image);
  if (!fs.existsSync(imagePath)) {
    console.error(`image not found: ${imagePath}`);
    process.exit(2);
  }
  const level = parseLevel(flags.level);
  const config = levelConfigFor(level);
  console.log(`LIVE AI QA — 1 provider call (${config.provider}/` +
    `${config.model}, level ${level}). This costs real money.\n`);
  const run = await runLiveCase({
    note, imagePath, level,
    area: typeof flags.area === "string" ? flags.area : undefined,
  });
  console.log(formatLiveReport(run, note));
  if (run.providerError) process.exit(1);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
