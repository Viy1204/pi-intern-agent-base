import { describe, expect, it } from "vitest";
import {
  conversationKey,
  conversationLabel,
  normalizeForDedupe,
  parseBotCommand,
  parseMessageInput,
  pruneRecentMap,
  stripThinkingTags,
} from "../../extensions/pi-intern-feishu-bridge/messages.js";
import type { FeishuMessage } from "../../extensions/pi-intern-feishu-bridge/types.js";

function msg(overrides: Partial<FeishuMessage> = {}): FeishuMessage {
  return {
    messageId: "om_1",
    chatId: "oc_1",
    chatType: "group",
    senderOpenId: "ou_1",
    msgType: "text",
    content: JSON.stringify({ text: "hi" }),
    ...overrides,
  };
}

describe("conversationKey", () => {
  it("按人隔离私聊，同一个人换群不串会话", () => {
    expect(conversationKey(msg({ chatType: "p2p", senderOpenId: "ou_a" }))).toBe("p2p:ou_a");
    expect(conversationKey(msg({ chatType: "p2p", senderOpenId: "ou_b" }))).toBe("p2p:ou_b");
  });

  it("普通群共享一个会话", () => {
    expect(conversationKey(msg({ chatId: "oc_x", senderOpenId: "ou_a" })))
      .toBe(conversationKey(msg({ chatId: "oc_x", senderOpenId: "ou_b" })));
  });

  it("话题按 thread 隔离，threadId 优先于 rootId/parentId", () => {
    expect(conversationKey(msg({ threadId: "t1", rootId: "r1" }))).toBe("group:oc_1:thread:t1");
    expect(conversationKey(msg({ rootId: "r1" }))).toBe("group:oc_1:thread:r1");
    expect(conversationKey(msg({ parentId: "p1" }))).toBe("group:oc_1:thread:p1");
  });

  it("话题群的首条消息自己当 thread 根", () => {
    expect(conversationKey(msg({ chatMode: "topic", messageId: "om_root" })))
      .toBe("group:oc_1:thread:om_root");
  });
});

describe("conversationLabel", () => {
  it("标注会话形态供 prompt 使用", () => {
    expect(conversationLabel(msg({ chatType: "p2p" }))).toBe("[飞书私聊]");
    expect(conversationLabel(msg())).toBe("[飞书群聊]");
    expect(conversationLabel(msg({ threadId: "t1" }))).toBe("[飞书话题]");
    expect(conversationLabel(msg({ chatMode: "topic" }))).toBe("[飞书话题]");
  });
});

describe("parseMessageInput", () => {
  it("剥掉 @机器人 的 open_id", () => {
    const parsed = parseMessageInput(
      msg({ content: JSON.stringify({ text: "@ou_bot 帮我查一下" }) }),
      "ou_bot",
    );
    expect(parsed.text).toBe("帮我查一下");
  });

  it("解析富文本 post 的标题、正文与内嵌图片", () => {
    const content = JSON.stringify({
      post: {
        zh_cn: {
          title: "标题",
          content: [[
            { tag: "text", text: "正文" },
            { tag: "a", text: "链接" },
            { tag: "img", image_key: "img_1" },
          ]],
        },
      },
    });
    const parsed = parseMessageInput(msg({ msgType: "post", content }));
    expect(parsed.text).toBe("标题正文链接");
    expect(parsed.attachments).toEqual([{ kind: "image", fileKey: "img_1" }]);
  });

  it("图片和文件消息各自产出附件", () => {
    expect(parseMessageInput(msg({ msgType: "image", content: JSON.stringify({ image_key: "k1" }) })).attachments)
      .toEqual([{ kind: "image", fileKey: "k1" }]);

    const file = parseMessageInput(msg({
      msgType: "file",
      content: JSON.stringify({ file_key: "f1", file_name: "a.txt" }),
    }));
    expect(file.attachments).toEqual([{ kind: "file", fileKey: "f1", fileName: "a.txt" }]);
  });

  it("同一个 file_key 不会因嵌套结构被收集两次", () => {
    const content = JSON.stringify({ image_key: "dup", nested: { image_key: "dup" } });
    const parsed = parseMessageInput(msg({ msgType: "image", content }));
    expect(parsed.attachments).toHaveLength(1);
  });

  it("content 不是 JSON 时不抛异常", () => {
    expect(parseMessageInput(msg({ content: "not json" })).text).toBe("not json");
    expect(parseMessageInput(msg({ msgType: "audio", content: "" })).text).toBe("[audio]");
  });
});

describe("parseBotCommand", () => {
  it("识别无参命令，容忍多余空白", () => {
    expect(parseBotCommand("/new")).toEqual({ name: "new" });
    expect(parseBotCommand("  /stop  ")).toEqual({ name: "stop" });
    expect(parseBotCommand("/model")).toEqual({ name: "model" });
    expect(parseBotCommand("/resume")).toEqual({ name: "resume" });
  });

  it("workspace 可带路径也可不带", () => {
    expect(parseBotCommand("/workspace")).toEqual({ name: "workspace", path: undefined });
    expect(parseBotCommand("/workspace C:\\work\\repo")).toEqual({ name: "workspace", path: "C:\\work\\repo" });
  });

  it("普通消息和形似命令的文本都不算命令", () => {
    expect(parseBotCommand("你好")).toBeUndefined();
    expect(parseBotCommand("/newxyz")).toBeUndefined();
    expect(parseBotCommand("讲讲 /new 是什么")).toBeUndefined();
  });
});

describe("stripThinkingTags", () => {
  it("去掉推理块但保留正文", () => {
    expect(stripThinkingTags("<think>内部推理</think>答案")).toBe("答案");
    expect(stripThinkingTags("前<THINK>x</THINK>后")).toBe("前后");
  });

  it("压缩连续空行", () => {
    expect(stripThinkingTags("a\n\n\n\nb")).toBe("a\n\nb");
  });
});

describe("normalizeForDedupe / pruneRecentMap", () => {
  it("空白归一后相同文本视作重复", () => {
    expect(normalizeForDedupe("  查   一下\n数据 ")).toBe("查 一下 数据");
  });

  it("只删过期条目", () => {
    const map = new Map([["old", 0], ["fresh", 900]]);
    pruneRecentMap(map, 1000, 500);
    expect([...map.keys()]).toEqual(["fresh"]);
  });
});
