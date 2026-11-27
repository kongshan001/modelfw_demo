#!/usr/bin/env node
// Count cl100k_base tokens for a JSON array of strings read from stdin.
// Uses the js-tiktoken copy installed for the official gateway test.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const modPath = new URL("../.work/official/node_modules/js-tiktoken/dist/index.js", import.meta.url);
const { getEncoding } = await import(pathToFileURL(modPath.pathname).href);
const enc = getEncoding("cl100k_base");
const texts = JSON.parse(readFileSync(0, "utf8"));
process.stdout.write(JSON.stringify(texts.map((t) => enc.encode(String(t)).length)));
