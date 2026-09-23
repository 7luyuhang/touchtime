import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { buildTokensCss } from "../src/tokens/css";

const outFile = resolve(import.meta.dirname, "../src/styles/tokens.css");
const css = buildTokensCss();

if (process.argv.includes("--check")) {
  const current = readFileSync(outFile, "utf8");
  if (current !== css) {
    console.error("src/styles/tokens.css is out of date. Run `npm run tokens`.");
    process.exit(1);
  }
  console.log("tokens.css is up to date.");
} else {
  writeFileSync(outFile, css);
  console.log(`Wrote ${outFile}`);
}
