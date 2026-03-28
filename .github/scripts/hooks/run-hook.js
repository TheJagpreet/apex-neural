#!/usr/bin/env node
/**
 * Cross-platform hook runner for apex-neural agent hooks.
 *
 * Detects the current OS and runs the appropriate script:
 *   - Windows: PowerShell (.ps1) via powershell/pwsh
 *   - Linux/macOS: Shell (.sh) via sh
 *
 * Usage: node run-hook.js <hook-name>
 *   e.g. node run-hook.js pre-tool-guard
 *
 * Stdin is forwarded to the child process unchanged.
 */

const { execFileSync } = require("child_process");
const path = require("path");
const fs = require("fs");

const hookName = process.argv[2];
if (!hookName) {
  process.stderr.write("Usage: node run-hook.js <hook-name>\n");
  process.exit(1);
}

const hooksDir = __dirname;
const isWindows = process.platform === "win32";

// Collect stdin (hooks receive JSON on stdin)
let stdinData = "";
try {
  stdinData = fs.readFileSync(0, "utf8");
} catch {
  // No stdin available — continue with empty input
}

if (isWindows) {
  // Prefer pwsh (PowerShell Core), fall back to powershell (Windows PowerShell)
  const psScript = path.join(hooksDir, `${hookName}.ps1`);
  if (!fs.existsSync(psScript)) {
    process.stderr.write(`Hook script not found: ${psScript}\n`);
    process.exit(1);
  }

  const shell = (() => {
    try {
      execFileSync("pwsh", ["--version"], { stdio: "ignore" });
      return "pwsh";
    } catch {
      return "powershell";
    }
  })();

  try {
    const result = execFileSync(
      shell,
      ["-ExecutionPolicy", "Bypass", "-File", psScript],
      { input: stdinData, encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
    );
    process.stdout.write(result);
  } catch (err) {
    if (err.stdout) process.stdout.write(err.stdout);
    if (err.stderr) process.stderr.write(err.stderr);
    process.exit(err.status || 1);
  }
} else {
  // Linux / macOS — use the shell script
  const shScript = path.join(hooksDir, `${hookName}.sh`);
  if (!fs.existsSync(shScript)) {
    process.stderr.write(`Hook script not found: ${shScript}\n`);
    process.exit(1);
  }

  try {
    const result = execFileSync("sh", [shScript], {
      input: stdinData,
      encoding: "utf8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    process.stdout.write(result);
  } catch (err) {
    if (err.stdout) process.stdout.write(err.stdout);
    if (err.stderr) process.stderr.write(err.stderr);
    process.exit(err.status || 1);
  }
}
