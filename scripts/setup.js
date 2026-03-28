#!/usr/bin/env node
/**
 * Apex Neural — Workspace Setup Script
 *
 * Interactive, OS-independent setup that installs the Apex Neural agent
 * ecosystem into a multi-repo VS Code workspace.
 *
 * What it does:
 *   1. Copies the .github/ folder to the workspace root
 *   2. Copies the Apex Neural README.md into .github/ for reference
 *   3. Installs the apex-neural-memory VS Code extension (.vsix)
 *
 * Expected workspace layout after setup:
 *   workspace/
 *   ├── .github/                  ← installed by this script
 *   │   ├── agents/
 *   │   ├── hooks/
 *   │   ├── scripts/
 *   │   ├── skills/
 *   │   ├── apex-neural-README.md ← reference copy
 *   │   └── ...
 *   ├── apex-neural/              ← this repo
 *   ├── repo1/
 *   └── repo2/
 *
 * Usage:
 *   node scripts/setup.js
 *   node scripts/setup.js --workspace /path/to/workspace
 */

const fs = require("fs");
const path = require("path");
const readline = require("readline");
const { execFileSync } = require("child_process");

// ─── Helpers ────────────────────────────────────────────────────────────────

const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const RESET = "\x1b[0m";

function log(msg) {
  console.log(msg);
}

function info(msg) {
  log(`${CYAN}ℹ${RESET}  ${msg}`);
}

function success(msg) {
  log(`${GREEN}✔${RESET}  ${msg}`);
}

function warn(msg) {
  log(`${YELLOW}⚠${RESET}  ${msg}`);
}

function error(msg) {
  log(`${RED}✖${RESET}  ${msg}`);
}

/**
 * Create a question helper that works reliably with both interactive
 * terminals and piped/redirected stdin.
 */
function createPrompter(rl) {
  // Buffer lines that arrive before a question is asked (piped input)
  const lineBuffer = [];
  let pendingResolve = null;

  rl.on("line", (line) => {
    if (pendingResolve) {
      const resolve = pendingResolve;
      pendingResolve = null;
      resolve(line);
    } else {
      lineBuffer.push(line);
    }
  });

  rl.on("close", () => {
    // If a question is still pending when stdin closes, resolve with empty
    if (pendingResolve) {
      const resolve = pendingResolve;
      pendingResolve = null;
      resolve("");
    }
  });

  function ask(questionText) {
    return new Promise((resolve) => {
      process.stdout.write(questionText);
      if (lineBuffer.length > 0) {
        resolve(lineBuffer.shift());
      } else {
        pendingResolve = resolve;
      }
    });
  }

  return { ask };
}

/**
 * Prompt the user with a yes/no question. Returns true for yes.
 */
function confirm(prompter, question) {
  return prompter
    .ask(`${BOLD}${question}${RESET} (y/n): `)
    .then((answer) => answer.trim().toLowerCase().startsWith("y"));
}

/**
 * Prompt the user for a text value with a default.
 */
function prompt(prompter, question, defaultValue) {
  const display = defaultValue ? ` [${defaultValue}]` : "";
  return prompter
    .ask(`${BOLD}${question}${RESET}${display}: `)
    .then((answer) => answer.trim() || defaultValue || "");
}

/**
 * Recursively copy a directory, preserving structure.
 */
function copyDirSync(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

/**
 * Count files recursively in a directory.
 */
function countFiles(dir) {
  let count = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      count += countFiles(path.join(dir, entry.name));
    } else {
      count++;
    }
  }
  return count;
}

// ─── Parse CLI arguments ────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === "--workspace" && argv[i + 1]) {
      args.workspace = argv[++i];
    }
  }
  return args;
}

// ─── Main ───────────────────────────────────────────────────────────────────

async function main() {
  const args = parseArgs(process.argv);

  // Resolve paths relative to the repo root (parent of scripts/)
  const repoRoot = path.resolve(__dirname, "..");
  const sourceGithub = path.join(repoRoot, ".github");
  const sourceReadme = path.join(repoRoot, "README.md");
  const extensionDir = path.join(repoRoot, "extensions", "apex-neural-memory");
  const vsixPath = (() => {
    try {
      const files = fs.readdirSync(extensionDir);
      const vsix = files.find((f) => f.endsWith(".vsix"));
      return vsix ? path.join(extensionDir, vsix) : null;
    } catch {
      return null;
    }
  })();

  // ── Banner ──────────────────────────────────────────────────────────────
  log("");
  log(`${BOLD}${CYAN}╔════════════════════════════════════════════════╗${RESET}`);
  log(`${BOLD}${CYAN}║       Apex Neural — Workspace Setup           ║${RESET}`);
  log(`${BOLD}${CYAN}╚════════════════════════════════════════════════╝${RESET}`);
  log("");

  // ── Validate source files ───────────────────────────────────────────────
  if (!fs.existsSync(sourceGithub)) {
    error(`.github/ folder not found at: ${sourceGithub}`);
    error("Please run this script from the apex-neural repository root.");
    process.exit(1);
  }

  if (!fs.existsSync(sourceReadme)) {
    error(`README.md not found at: ${sourceReadme}`);
    process.exit(1);
  }

  // ── Interactive session ─────────────────────────────────────────────────
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false,
  });
  const prompter = createPrompter(rl);

  try {
    // Determine workspace root
    const defaultWorkspace = path.resolve(repoRoot, "..");
    const workspaceRoot = args.workspace
      ? path.resolve(args.workspace)
      : await prompt(
          prompter,
          "Workspace root directory (parent of all repos)",
          defaultWorkspace
        );

    if (!fs.existsSync(workspaceRoot)) {
      error(`Workspace directory does not exist: ${workspaceRoot}`);
      process.exit(1);
    }

    const destGithub = path.join(workspaceRoot, ".github");
    const destReadme = path.join(destGithub, "apex-neural-README.md");
    const fileCount = countFiles(sourceGithub);

    // ── Summary ─────────────────────────────────────────────────────────
    log("");
    info("The following actions will be performed:");
    log("");
    log(
      `  ${BOLD}1.${RESET} Copy ${CYAN}.github/${RESET} → ${CYAN}${destGithub}${RESET}`
    );
    log(
      `     (${fileCount} files)`
    );
    log(
      `  ${BOLD}2.${RESET} Copy ${CYAN}README.md${RESET} → ${CYAN}${destReadme}${RESET}`
    );
    log(
      `  ${BOLD}3.${RESET} Install VS Code extension: ${CYAN}apex-neural-memory${RESET}`
    );
    log("");

    if (fs.existsSync(destGithub)) {
      warn(
        `${destGithub} already exists. Files will be overwritten.`
      );
      log("");
    }

    const proceed = await confirm(prompter, "Proceed with setup?");
    if (!proceed) {
      info("Setup cancelled.");
      process.exit(0);
    }

    log("");

    // ── Step 1: Copy .github/ ───────────────────────────────────────────
    info("Copying .github/ folder...");
    copyDirSync(sourceGithub, destGithub);
    success(`.github/ copied to ${destGithub}`);

    // ── Step 2: Copy README ─────────────────────────────────────────────
    info("Copying README.md...");
    fs.copyFileSync(sourceReadme, destReadme);
    success(`README.md copied as ${destReadme}`);

    // ── Step 3: Install extension ───────────────────────────────────────
    if (!vsixPath) {
      warn(
        "No .vsix file found in extensions/apex-neural-memory/."
      );
      warn(
        "Build it with: cd extensions/apex-neural-memory && npm run package"
      );
    } else {
      const installExt = await confirm(
        prompter,
        "Install the apex-neural-memory VS Code extension now?"
      );

      if (installExt) {
        info("Installing VS Code extension...");
        try {
          execFileSync("code", ["--install-extension", vsixPath], {
            stdio: "inherit",
          });
          success("apex-neural-memory extension installed.");
        } catch (err) {
          warn("Could not install the extension automatically.");
          if (err.message) {
            warn(`Reason: ${err.message}`);
          }
          log("");
          info("To install manually, run:");
          log(
            `     code --install-extension ${vsixPath}`
          );
        }
      } else {
        info("Skipped extension installation.");
        info("To install manually later, run:");
        log(`     code --install-extension ${vsixPath}`);
      }
    }

    // ── Done ────────────────────────────────────────────────────────────
    log("");
    log(`${BOLD}${GREEN}╔════════════════════════════════════════════════╗${RESET}`);
    log(`${BOLD}${GREEN}║            Setup complete! 🚀                  ║${RESET}`);
    log(`${BOLD}${GREEN}╚════════════════════════════════════════════════╝${RESET}`);
    log("");
    info("Next steps:");
    log(`  1. Open the workspace folder in VS Code`);
    log(`  2. Enable these settings in your VS Code settings:`);
    log(`     ${CYAN}"chat.useCustomAgentHooks": true${RESET}`);
    log(`     ${CYAN}"chat.plugins.enabled": true${RESET}`);
    log(`  3. Ensure the ${BOLD}apex-neural-memory${RESET} extension is installed`);
    log(`  4. Open VS Code Chat and select ${BOLD}Orchestrator${RESET} to get started`);
    log("");
    info("Alternative: Install as a VS Code Copilot agent plugin:");
    log(`  Run ${CYAN}Chat: Install Plugin From Source${RESET} in the Command Palette`);
    log(`  and enter: ${CYAN}https://github.com/TheJagpreet/apex-neural${RESET}`);
    log("");
  } finally {
    rl.close();
  }
}

main().catch((err) => {
  error(err.message);
  process.exit(1);
});
