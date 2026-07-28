import { debugLog } from "./debug.js";

const DEBOUNCE_MS = 600;

/**
 * 按会话 key 攒消息，静默 DEBOUNCE_MS 后一次性交给 agent。
 *
 * 用户在飞书里习惯把一件事拆成几条短消息连发，逐条起 run 会让 agent 只看到
 * 半个需求（还会互相抢同一个会话）。run 进行中调 block()，期间到达的消息继续
 * 累积，unblock() 后重新计时再一起送出。
 */
export class PendingQueue<T> {
  private readonly pending = new Map<string, T[]>();
  private readonly timers = new Map<string, NodeJS.Timeout>();
  private readonly blocked = new Set<string>();

  constructor(private readonly onFlush: (key: string, items: T[]) => Promise<void>) {}

  push(key: string, item: T) {
    const items = this.pending.get(key) || [];
    items.push(item);
    this.pending.set(key, items);
    this.schedule(key);
  }

  block(key: string) {
    this.blocked.add(key);
    this.clearTimer(key);
  }

  unblock(key: string) {
    this.blocked.delete(key);
    if (this.pending.get(key)?.length) this.schedule(key);
  }

  isBlocked(key: string) {
    return this.blocked.has(key);
  }

  pendingCount(key: string) {
    return this.pending.get(key)?.length || 0;
  }

  reset() {
    for (const key of [...this.timers.keys()]) this.clearTimer(key);
    this.pending.clear();
    this.blocked.clear();
  }

  private schedule(key: string) {
    if (this.blocked.has(key)) return;
    this.clearTimer(key);
    const timer = setTimeout(() => {
      this.timers.delete(key);
      void this.flush(key);
    }, DEBOUNCE_MS);
    timer.unref?.();
    this.timers.set(key, timer);
  }

  private clearTimer(key: string) {
    const timer = this.timers.get(key);
    if (!timer) return;
    clearTimeout(timer);
    this.timers.delete(key);
  }

  private async flush(key: string) {
    if (this.blocked.has(key)) return;
    const items = this.pending.get(key) || [];
    if (!items.length) return;
    this.pending.delete(key);
    debugLog("feishu.queue.flush", { key, count: items.length });
    try {
      await this.onFlush(key, items);
    } catch (error) {
      debugLog("feishu.queue.flush_error", {
        key,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}
