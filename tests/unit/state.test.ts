import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { gcState } from "../../extensions/pi-intern-feishu-bridge/bridge-store.js";
import type { FeishuBridgeState } from "../../extensions/pi-intern-feishu-bridge/types.js";

const NOW = 1_700_000_000_000;
const DAY = 24 * 60 * 60 * 1000;

function state(overrides: Partial<FeishuBridgeState> = {}): FeishuBridgeState {
  return { version: 1, routes: {}, jobs: {}, sent: {}, ...overrides };
}

function route(updatedAt: number) {
  return {
    sessionKey: "k", chatId: "oc_1", chatType: "group" as const,
    lastMessageId: "om_1", updatedAt,
  };
}

describe("bridge.json 回收", () => {
  it("投递去重表按 TTL 过期，避免无界增长", () => {
    const result = gcState(state({
      sent: { fresh: NOW - 1000, old: NOW - 2 * DAY },
    }), NOW);
    expect(Object.keys(result.sent)).toEqual(["fresh"]);
  });

  it("超过 90 天没动过的路由被清掉", () => {
    const result = gcState(state({
      routes: { live: route(NOW - DAY), stale: route(NOW - 100 * DAY) },
    }), NOW);
    expect(Object.keys(result.routes)).toEqual(["live"]);
  });

  it("条数超上限时保留最近使用的", () => {
    const routes: Record<string, ReturnType<typeof route>> = {};
    for (let i = 0; i < 600; i += 1) routes[`k${i}`] = route(NOW - i * 1000);
    const result = gcState(state({ routes }), NOW);
    expect(Object.keys(result.routes)).toHaveLength(500);
    expect(result.routes.k0).toBeDefined();       // 最新
    expect(result.routes.k599).toBeUndefined();   // 最旧
  });

  it("缺字段的历史数据不会被误删或导致崩溃", () => {
    const result = gcState({ version: 1, routes: { noTs: { sessionKey: "k" } as any }, jobs: {}, sent: {} }, NOW);
    expect(result.routes.noTs).toBeDefined();
    expect(() => gcState({} as FeishuBridgeState, NOW)).not.toThrow();
  });
});

describe("原子写", () => {
  let sandbox: string;
  const original = { HOME: process.env.HOME, USERPROFILE: process.env.USERPROFILE };

  beforeEach(() => {
    sandbox = mkdtempSync(join(tmpdir(), "pi-write-test-"));
    process.env.HOME = sandbox;
    process.env.USERPROFILE = sandbox;
    vi.resetModules();
  });

  afterEach(() => {
    process.env.HOME = original.HOME;
    process.env.USERPROFILE = original.USERPROFILE;
    try { rmSync(sandbox, { recursive: true, force: true }); } catch {}
  });

  it("写入后内容可读回，且不留临时文件", async () => {
    const { writeJson, readJson } = await import("../../extensions/pi-intern-feishu-bridge/config.js");
    const target = join(sandbox, "nested", "state.json");
    writeJson(target, { hello: "世界", n: 1 });
    expect(readJson(target, {})).toEqual({ hello: "世界", n: 1 });
    expect(readFileSync(target, "utf8").endsWith("\n")).toBe(true);
  });

  it("覆盖写不会产生半截文件：旧内容在 rename 前始终完整", async () => {
    const { writeJson, readJson } = await import("../../extensions/pi-intern-feishu-bridge/config.js");
    const target = join(sandbox, "state.json");
    writeJson(target, { version: 1 });
    writeJson(target, { version: 2 });
    expect(readJson(target, {})).toEqual({ version: 2 });
  });

  it("读到损坏的 JSON 时退回默认值而不是抛错", async () => {
    const { readJson } = await import("../../extensions/pi-intern-feishu-bridge/config.js");
    const target = join(sandbox, "broken.json");
    writeFileSync(target, '{"half":');
    expect(readJson(target, { fallback: true })).toEqual({ fallback: true });
  });
});
