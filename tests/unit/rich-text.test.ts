import { describe, expect, it } from "vitest";
import {
  buildMarkdownCardParts,
  buildPostMessages,
  chooseMessageMode,
} from "../../extensions/pi-intern-feishu-bridge/rich-text.js";

describe("chooseMessageMode", () => {
  it("短句走纯文本", () => {
    expect(chooseMessageMode("好了")).toBe("text");
    expect(chooseMessageMode("")).toBe("text");
    expect(chooseMessageMode("   ")).toBe("text");
  });

  it("表格和代码块必须走卡片（post 渲染不了）", () => {
    expect(chooseMessageMode("| a | b |\n| - | - |\n| 1 | 2 |")).toBe("interactive");
    expect(chooseMessageMode("说明\n```js\nconst a = 1;\n```")).toBe("interactive");
  });

  it("长文、多标题、长列表、多链接走卡片", () => {
    expect(chooseMessageMode("x".repeat(1200))).toBe("interactive");
    expect(chooseMessageMode("# 一\n## 二\n### 三")).toBe("interactive");
    expect(chooseMessageMode(Array.from({ length: 8 }, (_, i) => `- 第${i}项`).join("\n"))).toBe("interactive");
    expect(chooseMessageMode(Array.from({ length: 5 }, (_, i) => `[链接${i}](https://e.com/${i})`).join("\n"))).toBe("interactive");
  });

  it("多行 markdown 走富文本 post", () => {
    expect(chooseMessageMode("**要点**\n第二行说明")).toBe("post");
  });
});

describe("buildPostMessages", () => {
  it("超长文本切成多条且不丢内容", () => {
    const source = Array.from({ length: 4000 }, (_, i) => `第${i}行`).join("\n");
    const posts = buildPostMessages(source);
    expect(posts.length).toBeGreaterThan(1);

    const rendered = posts
      .map((post) => JSON.stringify((post as any).zh_cn))
      .join("");
    for (const probe of ["第0行", "第2000行", "第3999行"]) {
      expect(rendered).toContain(probe);
    }
  });

  it("每条 post 的正文都在飞书单条上限内", () => {
    for (const post of buildPostMessages("段落内容\n".repeat(4000))) {
      const chars = JSON.stringify((post as any).zh_cn.content).length;
      expect(chars).toBeLessThan(30_000);
    }
  });

  it("空文本也产出合法结构，不返回空数组", () => {
    const posts = buildPostMessages("");
    expect(posts.length).toBeGreaterThanOrEqual(1);
    expect(JSON.stringify(posts[0])).toContain("zh_cn");
  });

  it("按语言选 locale", () => {
    expect(JSON.stringify(buildPostMessages("hello\nworld", "en"))).toContain("en_us");
  });
});

describe("buildMarkdownCardParts", () => {
  it("单卡场景：首行提为卡片标题，其余作为正文原样保留", () => {
    const parts = buildMarkdownCardParts("结论如下\n**要点一**\n**要点二**");
    expect(parts).toHaveLength(1);
    expect(JSON.stringify(parts[0].card)).toContain("结论如下");
    expect(parts[0].markdown).toContain("**要点一**");
    expect(parts[0].markdown).toContain("**要点二**");
  });

  it("超过飞书单卡上限时拆分，每张卡都在限制内", () => {
    const parts = buildMarkdownCardParts("表格行 | 数据\n".repeat(4000));
    expect(parts.length).toBeGreaterThan(1);
    for (const part of parts) {
      expect(Buffer.byteLength(JSON.stringify(part.card), "utf8")).toBeLessThanOrEqual(30 * 1024);
    }
  });

  it("给了 copySourceId 生成器就带上复制按钮", () => {
    const parts = buildMarkdownCardParts("内容", "zh", (i) => `src-${i}`);
    expect(JSON.stringify(parts[0].card)).toContain("pi_feishu_copy_markdown");
  });

  it("不带 copySourceId 时不生成按钮", () => {
    const parts = buildMarkdownCardParts("内容");
    expect(JSON.stringify(parts[0].card)).not.toContain("pi_feishu_copy_markdown");
  });

  it("中文和 emoji 不会被切成半个字符", () => {
    const parts = buildMarkdownCardParts("汉字🎉".repeat(6000));
    for (const part of parts) {
      // 落单的代理对会被 JSON.stringify 编成 \ud800-\udfff 单体
      expect(/\\u[dD][89abAB][0-9a-fA-F]{2}(?!\\u[dD][c-fC-F])/.test(JSON.stringify(part.card))).toBe(false);
    }
  });
});
