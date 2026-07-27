import { homedir } from "node:os";
import { parse, resolve } from "node:path";

/**
 * Reject overly broad workspace roots (drive root, home dir and its
 * ancestors, Desktop/Downloads, system dirs). The agent gets full tool
 * access inside the workspace, so pointing it at C:\ or $HOME hands over
 * the whole machine.
 */
export function assertWorkspaceAllowed(path: string) {
  const resolved = resolve(path);
  const normalized = normalize(resolved);
  const home = normalize(homedir());

  const denied: Array<[string, string]> = [
    [normalize(parse(resolved).root), "磁盘根目录"],
    [home, "用户主目录"],
  ];

  let cursor = homedir();
  for (;;) {
    const parent = resolve(cursor, "..");
    if (parent === cursor) break;
    denied.push([normalize(parent), "用户主目录的上级目录"]);
    cursor = parent;
  }

  for (const child of ["Desktop", "Downloads"]) {
    denied.push([normalize(resolve(homedir(), child)), `${child} 目录`]);
  }

  const systemDirs = process.platform === "win32"
    ? ["C:\\Windows", "C:\\Program Files", "C:\\Program Files (x86)", "C:\\ProgramData"]
    : ["/tmp", "/usr", "/etc", "/var", "/bin", "/sbin", "/opt", "/System", "/Library"];
  for (const dir of systemDirs) denied.push([normalize(dir), "系统目录"]);

  for (const [deniedPath, label] of denied) {
    if (normalized === deniedPath) {
      throw new Error(`工作区范围太宽（${label}）：${path}\n请切换到具体的项目目录，例如 /workspace ~/projects/your-project`);
    }
  }
}

function normalize(p: string) {
  const stripped = p.replace(/[\\/]+$/, "") || p;
  return process.platform === "win32" ? stripped.toLowerCase() : stripped;
}
