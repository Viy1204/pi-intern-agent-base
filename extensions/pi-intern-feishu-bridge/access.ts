import { join } from "node:path";
import { ensureRoot, readJson, ROOT_DIR, writeJson } from "./config.js";
import { debugLog } from "./debug.js";
import type { FeishuConfig } from "./types.js";

export const ACCESS_PATH = join(ROOT_DIR, "access.json");

type AccessState = {
  ownerOpenId?: string;
  claimedAt?: string;
};

export type AccessDecision = {
  allowed: boolean;
  claimedOwner?: boolean;
};

/**
 * Access control for the Feishu bridge. Default policy: only the owner and
 * explicitly allowed users/chats may talk to the agent; everyone else is
 * silently ignored (no reply, no reaction) so the bot's existence is not
 * confirmed to strangers.
 *
 * The owner is auto-claimed by the first user who DMs the bot after setup
 * (normally the person who just ran /feishu setup), and can be overridden
 * via config `ownerOpenId` / env FEISHU_OWNER_OPEN_ID.
 */
export class FeishuAccess {
  private state: AccessState;

  constructor(private readonly config: FeishuConfig | undefined) {
    this.state = readJson<AccessState>(ACCESS_PATH, {});
  }

  ownerOpenId() {
    return this.config?.ownerOpenId || this.state.ownerOpenId;
  }

  describe() {
    if (this.config?.openAccess) return "open（未启用鉴权，所有用户可用）";
    const owner = this.ownerOpenId();
    return [
      `owner=${owner || "未认领（第一个私聊机器人的用户将成为 owner）"}`,
      `allowedUsers=${this.config?.allowedUsers?.length || 0}`,
      `allowedChats=${this.config?.allowedChats?.length || 0}`,
    ].join(", ");
  }

  checkMessage(senderOpenId: string, chatId: string, chatType: "p2p" | "group"): AccessDecision {
    if (this.config?.openAccess) return { allowed: true };
    if (!senderOpenId || senderOpenId === "unknown") return { allowed: false };
    if (this.isAuthorized(senderOpenId, chatId)) return { allowed: true };
    if (!this.ownerOpenId() && chatType === "p2p") {
      this.claimOwner(senderOpenId);
      return { allowed: true, claimedOwner: true };
    }
    return { allowed: false };
  }

  isAuthorized(openId: string, chatId?: string) {
    if (this.config?.openAccess) return true;
    if (!openId) return false;
    if (openId === this.ownerOpenId()) return true;
    if (this.config?.allowedUsers?.includes(openId)) return true;
    if (chatId && this.config?.allowedChats?.includes(chatId)) return true;
    return false;
  }

  private claimOwner(openId: string) {
    this.state = { ownerOpenId: openId, claimedAt: new Date().toISOString() };
    ensureRoot();
    writeJson(ACCESS_PATH, this.state);
    debugLog("feishu.access.owner_claimed", { ownerOpenId: openId });
  }
}
