import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PendingQueue } from "../../extensions/pi-intern-feishu-bridge/pending-queue.js";

const DEBOUNCE_MS = 600;

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe("PendingQueue", () => {
  it("静默窗口内连发的消息合并成一批", async () => {
    const batches: string[][] = [];
    const queue = new PendingQueue<string>(async (_key, items) => { batches.push(items); });

    queue.push("k", "帮我查一下");
    await vi.advanceTimersByTimeAsync(200);
    queue.push("k", "钟诚的信息");
    await vi.advanceTimersByTimeAsync(200);
    queue.push("k", "在花名册里");
    expect(batches).toHaveLength(0);           // 还在静默窗口内

    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS);
    expect(batches).toEqual([["帮我查一下", "钟诚的信息", "在花名册里"]]);
  });

  it("不同会话互不影响", async () => {
    const seen: Array<[string, string[]]> = [];
    const queue = new PendingQueue<string>(async (key, items) => { seen.push([key, items]); });

    queue.push("a", "1");
    queue.push("b", "2");
    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS);
    expect(seen.sort()).toEqual([["a", ["1"]], ["b", ["2"]]]);
  });

  it("run 进行中到达的消息累积，解锁后合并成下一轮", async () => {
    const batches: string[][] = [];
    const queue = new PendingQueue<string>(async (_key, items) => { batches.push(items); });

    queue.block("k");
    queue.push("k", "第一条");
    queue.push("k", "第二条");
    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS * 3);
    expect(batches).toHaveLength(0);           // 被 block，不该触发
    expect(queue.pendingCount("k")).toBe(2);

    queue.unblock("k");
    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS);
    expect(batches).toEqual([["第一条", "第二条"]]);
  });

  it("解锁时没有积压则不空跑", async () => {
    const calls: number[] = [];
    const queue = new PendingQueue<string>(async () => { calls.push(1); });
    queue.block("k");
    queue.unblock("k");
    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS * 2);
    expect(calls).toHaveLength(0);
  });

  it("回调抛错不影响后续批次", async () => {
    let first = true;
    const done: string[][] = [];
    const queue = new PendingQueue<string>(async (_key, items) => {
      if (first) { first = false; throw new Error("boom"); }
      done.push(items);
    });

    queue.push("k", "会失败的一批");
    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS);
    queue.push("k", "后一批");
    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS);
    expect(done).toEqual([["后一批"]]);
  });

  it("reset 清空积压和阻塞状态", async () => {
    const batches: string[][] = [];
    const queue = new PendingQueue<string>(async (_key, items) => { batches.push(items); });
    queue.push("k", "x");
    queue.block("k");
    queue.reset();
    expect(queue.isBlocked("k")).toBe(false);
    expect(queue.pendingCount("k")).toBe(0);
    await vi.advanceTimersByTimeAsync(DEBOUNCE_MS * 2);
    expect(batches).toHaveLength(0);
  });
});
