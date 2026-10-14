#!/usr/bin/env node
import {parseArgs} from "./args";
import {analyseNote, formatNoteReport} from "./note_report";

/**
 * `npm run qa:note -- "Wal por skim" [--area "Living Room"]` — the
 * deterministic half of the pipeline for one or more notes. Makes NO
 * provider call and needs no key.
 * @return {void}
 */
function main(): void {
  const {flags, positional} = parseArgs(process.argv.slice(2));
  if (positional.length === 0) {
    console.error("usage: npm run qa:note -- \"<note>\" [\"<note>\" ...] " +
      "[--area \"Living Room\"] [--plumbing]");
    process.exit(2);
  }
  for (const note of positional) {
    console.log(formatNoteReport(analyseNote(note, {
      area: typeof flags.area === "string" ? flags.area : undefined,
      isPlumbingArea: flags.plumbing === true,
    })));
  }
}

main();
