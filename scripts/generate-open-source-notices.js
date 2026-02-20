"use strict";

const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const appDir = path.resolve(repoRoot, "codex-linux");
const nodeModulesDir = path.join(appDir, "node_modules");
const outputPath = path.join(repoRoot, "OPEN_SOURCE_NOTICES.md");

if (!fs.existsSync(nodeModulesDir)) {
  console.error(`node_modules not found: ${nodeModulesDir}`);
  process.exit(1);
}

const packages = new Map();

function normalizeLicense(license) {
  if (!license) return "UNKNOWN";
  if (typeof license === "string") return license;
  if (typeof license.type === "string") return license.type;
  return "UNKNOWN";
}

function normalizeRepo(repo) {
  if (!repo) return "";
  if (typeof repo === "string") return repo;
  if (typeof repo.url === "string") return repo.url;
  return "";
}

function collectFromNodeModules(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory() || entry.isSymbolicLink()) continue;
    const fullPath = path.join(dir, entry.name);

    if (entry.name.startsWith("@")) {
      collectFromNodeModules(fullPath);
      continue;
    }

    const packageJsonPath = path.join(fullPath, "package.json");
    if (fs.existsSync(packageJsonPath)) {
      try {
        const pkg = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
        if (pkg.name && pkg.version) {
          const key = `${pkg.name}@${pkg.version}`;
          if (!packages.has(key)) {
            packages.set(key, {
              name: pkg.name,
              version: pkg.version,
              license: normalizeLicense(pkg.license),
              homepage: pkg.homepage || normalizeRepo(pkg.repository) || "",
            });
          }
        }
      } catch {
        // Ignore malformed package metadata in nested dependencies.
      }
    }

    const nestedNodeModules = path.join(fullPath, "node_modules");
    if (fs.existsSync(nestedNodeModules)) {
      collectFromNodeModules(nestedNodeModules);
    }
  }
}

collectFromNodeModules(nodeModulesDir);

const rows = Array.from(packages.values()).sort((a, b) => {
  if (a.name === b.name) return a.version.localeCompare(b.version);
  return a.name.localeCompare(b.name);
});

const lines = [];
lines.push("# Open Source Notices");
lines.push("");
lines.push(
  `Generated on ${new Date().toISOString()} from installed npm dependencies in \`codex-linux/node_modules\`.`
);
lines.push("");
lines.push("| Package | Version | License | Homepage/Repository |");
lines.push("| --- | --- | --- | --- |");

for (const row of rows) {
  const homepage = row.homepage ? row.homepage.replace(/\|/g, "\\|") : "";
  lines.push(
    `| ${row.name} | ${row.version} | ${row.license} | ${homepage} |`
  );
}

lines.push("");
lines.push(
  "_This file is informational and should be reviewed for legal compliance before redistribution._"
);
lines.push("");

fs.writeFileSync(outputPath, `${lines.join("\n")}`, "utf8");
console.log(`Wrote ${outputPath} (${rows.length} packages).`);
