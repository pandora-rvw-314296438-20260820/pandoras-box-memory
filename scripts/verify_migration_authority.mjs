import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const root = path.resolve("supabase/migrations");
const manifest = JSON.parse(
  await readFile("docs/migrations/migration-authority-manifest.json", "utf8"),
);
const files = (await readdir(root)).filter((name) => name.endsWith(".sql")).sort();
if (!files.length) throw new Error("No migrations found.");

let receipts = 0;
let historical = 0;
let executable = 0;

for (const name of files) {
  const source = await readFile(path.join(root, name), "utf8");
  const isReceipt =
    source.includes("Canonical executable authority:") ||
    source.includes("history-only") ||
    source.includes("Replay mode: history_receipt_noop");
  const isHistorical =
    !isReceipt &&
    /(?:temporary|remove_temporary|retire_|recovery|probe)/i.test(name);

  if (isReceipt) {
    receipts += 1;
    const match = source.match(
      /Canonical executable authority:\s*(supabase\/migrations\/[^\s]+)/,
    );
    if (match) {
      try {
        await readFile(path.resolve(match[1]), "utf8");
      } catch {
        throw new Error(
          `Migration receipt ${name} points to missing authority ${match[1]}`,
        );
      }
    }
  } else if (isHistorical) {
    historical += 1;
  } else {
    executable += 1;
  }
}

if (receipts + historical + executable !== files.length) {
  throw new Error("Migration classification is incomplete.");
}
if (
  manifest.schemaVersion !== 1 ||
  manifest.sourceDirectory !== "supabase/migrations"
) {
  throw new Error("Migration authority manifest metadata is invalid.");
}

console.log(JSON.stringify({
  migrations: files.length,
  provider_receipt: receipts,
  historical_control: historical,
  executable_authority: executable,
}));
