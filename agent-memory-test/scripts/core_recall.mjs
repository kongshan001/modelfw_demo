#!/usr/bin/env node
/**
 * Direct TdaiCore recall test — bypasses the gateway HTTP shape so we can see
 * BOTH recall channels:
 *   - prependContext : dynamic L1 memories for this query
 *   - appendSystemContext : stable L3 persona + L2 scene navigation
 *
 * Runs in a fresh process against the on-disk data dir, so it also proves
 * persistence across process restarts. No credentials are printed.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const official = path.join(root, ".work", "official", "src");

const { loadGatewayConfig } = await import(path.join(official, "gateway/config.ts"));
const { StandaloneHostAdapter } = await import(path.join(official, "adapters/standalone/host-adapter.ts"));
const { TdaiCore } = await import(path.join(official, "core/tdai-core.ts"));

const querySet = process.argv[2] || "base";
const all = JSON.parse(fs.readFileSync(path.join(root, "samples", "recall_queries.json"), "utf8"));
const queries = all[querySet];

const cfg = loadGatewayConfig();
const logger = {
  debug: () => {},
  info: (m) => console.error(m),
  warn: (m) => console.error(m),
  error: (m) => console.error(m),
};
const adapter = new StandaloneHostAdapter({
  dataDir: cfg.data.baseDir,
  llmConfig: cfg.llm,
  logger,
  defaultUserId: "default_user",
});
const core = new TdaiCore({ hostAdapter: adapter, config: cfg.memory });
await core.initialize();

const out = [];
for (const q of queries) {
  const t0 = performance.now();
  const result = await core.handleBeforeRecall(q.query, "session-core-new");
  const ms = Math.round((performance.now() - t0) * 10) / 10;
  out.push({
    id: q.id,
    query: q.query,
    latency_ms: ms,
    strategy: result.recallStrategy,
    l1_count: result.recalledL1Memories?.length ?? 0,
    l1: result.recalledL1Memories ?? [],
    prepend_context: result.prependContext ?? "",
    append_system_context: result.appendSystemContext ?? "",
  });
  console.error(`${q.id}: ${ms}ms l1=${out.at(-1).l1_count} prepend=${out.at(-1).prepend_context.length} chars`);
}
await core.destroy();
process.stdout.write(JSON.stringify({ query_set: querySet, data_dir: cfg.data.baseDir, results: out }, null, 2));
