import assert from "node:assert/strict";
import { globSync, readFileSync, statSync } from "node:fs";
import { join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { setImmediate } from "node:timers/promises";
import { runInNewContext } from "node:vm";
import { parse, walk } from "css-tree";
import { parseHTML } from "linkedom";

const site = new URL("../../docs/", import.meta.url);
const root = resolve(fileURLToPath(site));
const localFile = (path) => readFileSync(new URL(path, site), "utf8");
const origin = new URL("https://" + localFile("CNAME").trim()).origin;

function checkLocal(ref, page) {
  const url = new URL(ref, new URL(page, origin));
  if (url.origin !== origin) return;
  const path = resolve(root, "." + decodeURIComponent(url.pathname));
  assert(path === root || path.startsWith(root + sep), `${page}: invalid path ${ref}`);
  const target = url.pathname.endsWith("/") ? join(path, "index.html") : path;
  assert(statSync(target, { throwIfNoEntry: false })?.isFile(), `${page}: missing ${ref}`);
}

function checkLinks(document, page) {
  for (const element of document.querySelectorAll("[src], [href]")) {
    checkLocal(element.getAttribute("src") ?? element.getAttribute("href"), page);
  }
}

for (const page of globSync("**/*.html", { cwd: site })) {
  checkLinks(parseHTML(localFile(page)).document, page);
}
for (const file of globSync("**/*.css", { cwd: site })) {
  walk(parse(localFile(file)), {
    visit: "Url",
    enter(node) { checkLocal(node.value, file); },
  });
}

// Exercise the real release script on the static page without contacting GitHub.
const assets = [
  "Drill-windows-x86_64.zip", "Drill-macos-arm64.dmg", "Drill-macos-x86_64.dmg",
  "Drill-linux-amd64.deb", "Drill-linux-x86_64.AppImage", "Drill-linux-x86_64.pkg.tar.zst",
];
const aur = "https://aur.archlinux.org/packages/drill-search";
const releases = "https://github.com/yatima1460/Drill/releases";
const script = localFile("releases.js");
for (const ok of [true, false]) {
  const { document } = parseHTML(localFile("index.html"));
  const release = { tag_name: "test", assets: assets.map(name => ({ name })) };
  runInNewContext(script, {
    document,
    navigator: { platform: "Linux", userAgent: "Linux" },
    fetch: async () => ({ ok, json: async () => release }),
  });
  await setImmediate();
  const links = document.querySelectorAll("#release-actions a");
  const actual = Array.from(links, link => link.getAttribute("href")).sort();
  const expected = ok ? assets.map(name => `${releases}/download/test/${name}`) : [`${releases}/latest`];
  assert.deepEqual(actual, [...expected, aur].sort());
  checkLinks(document, "index.html");
}
