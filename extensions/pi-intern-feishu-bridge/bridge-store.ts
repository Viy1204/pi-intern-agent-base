import { BRIDGE_PATH, readJson, writeJson } from "./config.js";
import type { FeishuBridgeState, FeishuJobRoute, FeishuMessage, FeishuRoute } from "./types.js";

const DEFAULT_STATE: FeishuBridgeState = { version: 1, routes: {}, jobs: {}, sent: {} };

// 投递去重表只用于防重复推送，过期即无意义；路由/任务保留更久但也要有上限，
// 否则 bridge.json 随使用无限增长（长期运行后会到几 MB，每次读写都全量解析）。
const SENT_TTL_MS = 24 * 60 * 60 * 1000;
const ROUTE_TTL_MS = 90 * 24 * 60 * 60 * 1000;
const MAX_ROUTES = 500;
const MAX_JOBS = 500;

export class FeishuBridgeStore {
  bindConversation(sessionKey: string, msg: FeishuMessage, sessionId?: string) {
    const state = this.read();
    const previous = state.routes[sessionKey];
    const route: FeishuRoute = {
      sessionKey,
      sessionId: sessionId || previous?.sessionId,
      chatId: msg.chatId,
      chatType: msg.chatType,
      threadMessageId: routeThreadMessageId(msg, previous),
      lastMessageId: msg.messageId,
      updatedAt: Date.now(),
    };
    state.routes[sessionKey] = route;
    this.write(state);
    return route;
  }

  attachSession(sessionKey: string, sessionId: string) {
    const state = this.read();
    const route = state.routes[sessionKey];
    if (!route || route.sessionId === sessionId) return;
    state.routes[sessionKey] = { ...route, sessionId, updatedAt: Date.now() };
    this.write(state);
  }

  getRoute(sessionKey: string): FeishuRoute | undefined {
    return this.read().routes[sessionKey];
  }

  bindJob(sessionKey: string, jobId: string, jobName?: string, sessionId?: string): FeishuJobRoute | undefined {
    const state = this.read();
    const route = state.routes[sessionKey];
    if (!route) return undefined;
    const jobRoute: FeishuJobRoute = {
      ...route,
      sessionId: sessionId || route.sessionId,
      jobId,
      jobName,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    state.jobs[jobId] = jobRoute;
    this.write(state);
    return jobRoute;
  }

  getJob(jobId: string): FeishuJobRoute | undefined {
    return this.read().jobs[jobId];
  }

  markSent(deliveryKey: string) {
    const state = this.read();
    state.sent[deliveryKey] = Date.now();
    this.write(state);
  }

  hasSent(deliveryKey: string) {
    return Boolean(this.read().sent[deliveryKey]);
  }

  private read(): FeishuBridgeState {
    const raw = readJson<FeishuBridgeState>(BRIDGE_PATH, DEFAULT_STATE);
    return {
      version: 1,
      routes: { ...(raw.routes || {}) },
      jobs: { ...(raw.jobs || {}) },
      sent: { ...(raw.sent || {}) },
    };
  }

  private write(state: FeishuBridgeState) {
    writeJson(BRIDGE_PATH, gcState(state));
  }
}

/** 写入前顺手回收：先按 TTL 删过期项，再按条数上限保留最近的。 */
export function gcState(state: FeishuBridgeState, now = Date.now()): FeishuBridgeState {
  const sent: Record<string, number> = {};
  for (const [key, at] of Object.entries(state.sent || {})) {
    if (typeof at === "number" && now - at <= SENT_TTL_MS) sent[key] = at;
  }
  return {
    version: 1,
    routes: capByRecency(state.routes || {}, MAX_ROUTES, now, ROUTE_TTL_MS),
    jobs: capByRecency(state.jobs || {}, MAX_JOBS, now, ROUTE_TTL_MS),
    sent,
  };
}

function capByRecency<T extends { updatedAt?: number }>(
  entries: Record<string, T>,
  max: number,
  now: number,
  ttlMs: number,
): Record<string, T> {
  const fresh = Object.entries(entries).filter(([, item]) => {
    const at = item?.updatedAt;
    return typeof at !== "number" || now - at <= ttlMs;
  });
  if (fresh.length <= max) return Object.fromEntries(fresh) as Record<string, T>;
  fresh.sort((a, b) => (b[1]?.updatedAt || 0) - (a[1]?.updatedAt || 0));
  return Object.fromEntries(fresh.slice(0, max)) as Record<string, T>;
}

function routeThreadMessageId(msg: FeishuMessage, previous?: FeishuRoute) {
  if (msg.rootId || msg.parentId) return msg.rootId || msg.parentId;
  if (previous?.threadMessageId) return previous.threadMessageId;
  if (msg.threadId || msg.chatMode === "topic") return msg.messageId;
  return undefined;
}
