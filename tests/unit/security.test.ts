import { mkdtempSync, rmSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const ORIGINAL_HOME = { HOME: process.env.HOME, USERPROFILE: process.env.USERPROFILE };
let sandbox: string;

beforeEach(() => {
  sandbox = mkdtempSync(join(tmpdir(), "pi-bridge-test-"));
  process.env.HOME = sandbox;
  process.env.USERPROFILE = sandbox;
  vi.resetModules();
});

afterEach(() => {
  process.env.HOME = ORIGINAL_HOME.HOME;
  process.env.USERPROFILE = ORIGINAL_HOME.USERPROFILE;
  try { rmSync(sandbox, { recursive: true, force: true }); } catch {}
});

describe("workspace 护栏", () => {
  it("拒绝盘根、主目录及其上级、Desktop/Downloads、系统目录", async () => {
    const { assertWorkspaceAllowed } = await import(
      "../../extensions/pi-intern-feishu-bridge/workspace-policy.js"
    );
    const home = homedir();
    const tooBroad = [
      process.platform === "win32" ? "C:\\" : "/",
      home,
      join(home, ".."),
      join(home, "Desktop"),
      join(home, "Downloads"),
      process.platform === "win32" ? "C:\\Windows" : "/usr",
    ];
    for (const path of tooBroad) {
      expect(() => assertWorkspaceAllowed(path), path).toThrow();
    }
  });

  it("放行具体项目目录，并忽略大小写和尾部分隔符差异", async () => {
    const { assertWorkspaceAllowed } = await import(
      "../../extensions/pi-intern-feishu-bridge/workspace-policy.js"
    );
    expect(() => assertWorkspaceAllowed(join(homedir(), "projects", "demo"))).not.toThrow();
    if (process.platform === "win32") {
      expect(() => assertWorkspaceAllowed("c:\\program files")).toThrow();
      expect(() => assertWorkspaceAllowed("C:\\Windows\\")).toThrow();
    }
  });
});

describe("卡片回调签名", () => {
  it("签名后往返 JSON 仍可验证，篡改任一字段即失效", async () => {
    const { signCardButtonValues, verifyActionValue } = await import(
      "../../extensions/pi-intern-feishu-bridge/card-auth.js"
    );
    const card: any = {
      elements: [{ actions: [{ value: { action: "pi_feishu_stop_task", key: "p2p:ou_x", runId: "r1" } }] }],
    };
    signCardButtonValues(card);
    const signed = JSON.parse(JSON.stringify(card.elements[0].actions[0].value));

    expect(verifyActionValue(signed)).toBe(true);
    expect(verifyActionValue({ ...signed, key: "p2p:ou_attacker" })).toBe(false);
    expect(verifyActionValue({ ...signed, runId: "r2" })).toBe(false);
    expect(verifyActionValue({ ...signed, exp: Date.now() + 999_999 })).toBe(false);
  });

  it("未签名、过期、非本扩展的 value 都不放行", async () => {
    const { signActionValue, verifyActionValue, isBridgeActionValue } = await import(
      "../../extensions/pi-intern-feishu-bridge/card-auth.js"
    );
    expect(verifyActionValue({ action: "pi_feishu_stop_task", key: "k" })).toBe(false);
    expect(isBridgeActionValue({ action: "other_app_action" })).toBe(false);

    const expired: any = { action: "pi_feishu_stop_task", key: "k", exp: Date.now() - 1 };
    signActionValue(expired);
    expired.exp = Date.now() - 1;
    expect(verifyActionValue(expired)).toBe(false);
  });

  it("undefined 字段在 JSON 往返中被丢弃后签名依然有效", async () => {
    const { signCardButtonValues, verifyActionValue } = await import(
      "../../extensions/pi-intern-feishu-bridge/card-auth.js"
    );
    const card: any = { actions: [{ value: { action: "pi_feishu_stop_task", key: "k", runId: undefined } }] };
    signCardButtonValues(card);
    expect(verifyActionValue(JSON.parse(JSON.stringify(card.actions[0].value)))).toBe(true);
  });
});

describe("访问控制", () => {
  const config: any = {
    appId: "cli_x",
    appSecret: "s",
    domain: "feishu",
    groupPolicy: "open",
    allowedUsers: ["ou_friend"],
    allowedChats: ["oc_team"],
  };

  it("首个私聊者成为 owner，之后陌生人被拒", async () => {
    const { FeishuAccess } = await import("../../extensions/pi-intern-feishu-bridge/access.js");
    const access = new FeishuAccess(config);
    expect(access.ownerOpenId()).toBeUndefined();

    const first = access.checkMessage("ou_owner", "oc_p2p", "p2p");
    expect(first).toEqual({ allowed: true, claimedOwner: true });
    expect(access.checkMessage("ou_owner", "oc_p2p", "p2p").allowed).toBe(true);
    expect(access.checkMessage("ou_stranger", "oc_other", "p2p").allowed).toBe(false);
  });

  it("owner 认领结果持久化，新实例仍然认得", async () => {
    const { FeishuAccess } = await import("../../extensions/pi-intern-feishu-bridge/access.js");
    new FeishuAccess(config).checkMessage("ou_owner", "oc_p2p", "p2p");
    expect(new FeishuAccess(config).ownerOpenId()).toBe("ou_owner");
  });

  it("白名单用户与白名单群放行，群里的陌生人不能抢 owner", async () => {
    const { FeishuAccess } = await import("../../extensions/pi-intern-feishu-bridge/access.js");
    const access = new FeishuAccess(config);
    expect(access.checkMessage("ou_stranger", "oc_random", "group").allowed).toBe(false);
    expect(access.ownerOpenId()).toBeUndefined();
    expect(access.checkMessage("ou_friend", "oc_any", "p2p").allowed).toBe(true);
    expect(access.checkMessage("ou_stranger", "oc_team", "group").allowed).toBe(true);
  });

  it("openAccess 恢复旧的全放行行为", async () => {
    const { FeishuAccess } = await import("../../extensions/pi-intern-feishu-bridge/access.js");
    const access = new FeishuAccess({ ...config, openAccess: true });
    expect(access.checkMessage("ou_anyone", "oc_any", "group").allowed).toBe(true);
    expect(access.isAuthorized("ou_anyone")).toBe(true);
  });
});
