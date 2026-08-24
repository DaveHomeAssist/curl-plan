#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const files = [
  "api/src/auth.js",
  "api/src/handler.js",
  "api/src/index.js"
];

let failed = false;
for (const relativePath of files) {
  const absolutePath = path.join(root, relativePath);
  const syntax = spawnSync(process.execPath, ["--check", absolutePath], { encoding: "utf8" });
  if (syntax.status !== 0) {
    failed = true;
    process.stderr.write(syntax.stderr || syntax.stdout);
  }

  const source = fs.readFileSync(absolutePath, "utf8");
  const checks = [
    [/[ \t]+$/m, "trailing whitespace"],
    [/\beval\s*\(/, "eval usage"],
    [/\bnew\s+Function\s*\(/, "dynamic Function construction"]
  ];
  for (const [pattern, label] of checks) {
    if (!pattern.test(source)) continue;
    failed = true;
    console.error(`${relativePath}: disallowed ${label}`);
  }
}

if (failed) process.exit(1);
console.log(`lint-api: ${files.length} Worker modules passed syntax and source-policy checks`);
