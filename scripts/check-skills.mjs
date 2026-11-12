#!/usr/bin/env node
// スキルの構造を検査する。判断の中身ではなく、壊れた参照と索引のずれを見る。
//   1. skills/<name>/SKILL.md の frontmatter に name と description があり、name がディレクトリ名と一致する
//   2. 本文が指す同梱パス（references/ assets/ と相対リンク）が実在する
//      scripts/ と evals/ は対象プロジェクトのパスとして書かれることが多いので見ない
//   3. omakase のプレイブック索引と playbooks/*.md が一致する
// 壊れていれば exit 1。

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS = join(ROOT, "skills");
const BUNDLED = /(?:^|[^\w/-])((?:references|assets)\/[A-Za-z0-9._/-]+)/g;
const LINK = /\]\(([^)\s>]+)\)/g;

const errors = [];
const fail = (message) => errors.push(message);

const entries = (dir) => readdirSync(dir).sort();
const isDir = (path) => statSync(path).isDirectory();
const skillNames = entries(SKILLS).filter((name) => isDir(join(SKILLS, name)) && existsSync(join(SKILLS, name, "SKILL.md")));

function frontmatter(text) {
  const match = text.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return null;
  const fields = {};
  for (const line of match[1].split("\n")) {
    const kv = line.match(/^([a-z-]+):\s*(.*)$/);
    if (kv) fields[kv[1]] = kv[2].replace(/^"|"$/g, "");
  }
  return fields;
}

function markdownFiles(dir) {
  const found = [];
  for (const name of entries(dir)) {
    const path = join(dir, name);
    if (isDir(path)) found.push(...markdownFiles(path));
    else if (name.endsWith(".md")) found.push(path);
  }
  return found;
}

// 参照は、ファイル自身の位置 → スキルのルート → リポジトリのルートの順に解決する。
function resolves(token, file, skillRoot) {
  const trimmed = token.replace(/[.,;:]+$/, "");
  for (const candidate of [trimmed, token]) {
    for (const base of [dirname(file), skillRoot, ROOT]) {
      if (existsSync(join(base, candidate))) return true;
    }
  }
  return false;
}

for (const name of skillNames) {
  const skillRoot = join(SKILLS, name);
  const skillFile = join(skillRoot, "SKILL.md");
  const text = readFileSync(skillFile, "utf8");
  const fields = frontmatter(text);

  if (!fields) fail(`${name}: frontmatter が無い`);
  if (fields && !fields.name) fail(`${name}: frontmatter に name が無い`);
  if (fields && !fields.description) fail(`${name}: frontmatter に description が無い`);
  if (fields?.name && fields.name !== name) fail(`${name}: name "${fields.name}" がディレクトリ名と違う`);

  for (const file of markdownFiles(skillRoot)) {
    const text = readFileSync(file, "utf8");
    const tokens = [...text.matchAll(BUNDLED)].map((match) => match[1]);
    const links = [...text.matchAll(LINK)].map((match) => match[1]).filter((link) => !/^(?:https?:|#|\/)/.test(link));
    for (const token of [...tokens, ...links]) {
      if (!resolves(token, file, skillRoot)) fail(`${relative(ROOT, file)}: 参照先が無い ${token}`);
    }
  }
}

const playbookDir = join(SKILLS, "omakase", "playbooks");
const playbooks = entries(playbookDir).filter((name) => name.endsWith(".md")).map((name) => name.slice(0, -3));
const index = readFileSync(join(SKILLS, "omakase", "SKILL.md"), "utf8").split("\n## Playbooks")[1] ?? "";
const listed = new Set(
  index
    .split("\n")
    .map((line) => line.match(/^\|\s*([a-z0-9][a-z0-9-]*)\s*\|/)?.[1])
    .filter(Boolean),
);
for (const name of playbooks) if (!listed.has(name)) fail(`omakase の索引に無いプレイブック: ${name}`);
for (const name of listed) if (!playbooks.includes(name)) fail(`索引にあるが実ファイルが無いプレイブック: ${name}`);

if (errors.length) {
  for (const message of errors) console.error(`ERROR: ${message}`);
  process.exit(1);
}
console.log(`check-skills: ok (${skillNames.length} skills, ${playbooks.length} playbooks)`);
