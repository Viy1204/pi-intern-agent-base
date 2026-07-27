import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { join } from "node:path";
import { ensureRoot, readJson, ROOT_DIR, writeJson } from "./config.js";

export const CARD_SECRET_PATH = join(ROOT_DIR, "card-secret.json");

const SIGNED_ACTION_PREFIX = "pi_feishu_";
const TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

let cachedSecret: Buffer | undefined;

function secret(): Buffer {
  if (cachedSecret) return cachedSecret;
  ensureRoot();
  const stored = readJson<{ secret?: string }>(CARD_SECRET_PATH, {});
  if (stored.secret && /^[0-9a-f]{64}$/.test(stored.secret)) {
    cachedSecret = Buffer.from(stored.secret, "hex");
    return cachedSecret;
  }
  const fresh = randomBytes(32);
  writeJson(CARD_SECRET_PATH, { secret: fresh.toString("hex") });
  cachedSecret = fresh;
  return fresh;
}

export function resetCardSecretCache() {
  cachedSecret = undefined;
}

/**
 * Stable stringify with sorted keys, so sign/verify agree regardless of key
 * order. Mirrors JSON.stringify semantics for undefined (dropped in objects,
 * null in arrays) so the digest survives the Feishu round-trip.
 */
function canonicalize(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(",")}]`;
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const keys = Object.keys(obj).filter((k) => obj[k] !== undefined).sort();
    return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalize(obj[k])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}

function computeSig(value: Record<string, unknown>) {
  const { sig: _sig, ...rest } = value;
  return createHmac("sha256", secret()).update(canonicalize(rest)).digest("hex");
}

export function isBridgeActionValue(value: unknown): value is Record<string, unknown> {
  return Boolean(
    value
    && typeof value === "object"
    && typeof (value as Record<string, unknown>).action === "string"
    && ((value as Record<string, unknown>).action as string).startsWith(SIGNED_ACTION_PREFIX),
  );
}

export function signActionValue(value: Record<string, unknown>) {
  if (typeof value.sig === "string") return value;
  value.exp = Date.now() + TOKEN_TTL_MS;
  value.sig = computeSig(value);
  return value;
}

export function verifyActionValue(value: unknown): boolean {
  if (!isBridgeActionValue(value)) return false;
  if (typeof value.sig !== "string" || typeof value.exp !== "number") return false;
  if (value.exp < Date.now()) return false;
  const expected = Buffer.from(computeSig(value), "hex");
  let actual: Buffer;
  try {
    actual = Buffer.from(value.sig, "hex");
  } catch {
    return false;
  }
  if (actual.length !== expected.length) return false;
  return timingSafeEqual(actual, expected);
}

/** Walk a card JSON tree and sign every pi_feishu_* button value in place. */
export function signCardButtonValues<T>(card: T): T {
  walk(card);
  return card;
}

function walk(node: unknown) {
  if (Array.isArray(node)) {
    for (const item of node) walk(item);
    return;
  }
  if (!node || typeof node !== "object") return;
  const obj = node as Record<string, unknown>;
  if (isBridgeActionValue(obj.value)) signActionValue(obj.value);
  for (const value of Object.values(obj)) walk(value);
}
