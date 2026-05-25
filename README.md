<h1 align="center">🔥 burnrate</h1>

<p align="center">
  <strong>你今天用 Claude Code 烧了多少钱?</strong><br/>
  <em>Real-time cost tracker for Claude Code · 单文件 Python · 零依赖 · 永不联网</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT"></a>
  <img src="https://img.shields.io/badge/python-3.10+-blue.svg" alt="Python 3.10+">
  <a href="#install"><img src="https://img.shields.io/badge/install-curl_%7C_bash-green.svg" alt="curl | bash"></a>
  <img src="https://img.shields.io/badge/phones%20home-never-red.svg" alt="never phones home">
  <a href="README.en.md"><img src="https://img.shields.io/badge/lang-中文_%7C_English-orange.svg" alt="bilingual"></a>
</p>

---

## 这只是一个简单的问题

> **你过去 7 天用 Claude Code 烧了多少钱?**

**99% 的人答不上来。**

Anthropic 的 console 给你的是 raw event 列表,Cursor / Codex 干脆不告诉你,你只能等下个月信用卡账单。

`burnrate` 直接读 `~/.claude/projects/**/*.jsonl`,告诉你三个数:

```
$ burnrate

  🔥 burnrate  2026-05-25 Mon · 14:58

    今日            $44.21
    vs 昨日         ↑ 1143%   (昨日 $3.56)
    vs 7日均        ↓ 69%     (7日均 $142/天)

  按模型
    opus-4-7             $44.21  100%  ████████████████

  按项目
    ~                                            $20.89   47%
    ~/Dmall_projects/agent_hub                   $9.90    22%
    ~/projects/awesome-claude-code-cn            $4.40    10%
    ~/projects/burnrate                          $1.43     3%

  缓存命中         95%    (省下约 $165)
  最贵一轮         14:47   $0.80   ~/projects/burnrate
```

```
$ burnrate week

  🔥 burnrate · 过去 7 天  共 $854

    Tue 05-19  ███░░░░░░░░░░░░░░░░░░░░░    $51.47
    Wed 05-20  ██████████░░░░░░░░░░░░░░    $145
    Thu 05-21  ███████████░░░░░░░░░░░░░    $172
    Fri 05-22  ████████████████████████    $361
    Sat 05-23  █████░░░░░░░░░░░░░░░░░░░    $76.83
    Sun 05-24  ░░░░░░░░░░░░░░░░░░░░░░░░    $3.56
    Mon 05-25  ███░░░░░░░░░░░░░░░░░░░░░    $44.30 ← today

  缓存命中率       97%    省下约 $4,922
  日均             $122 / 天   (月度估算 $3,662)
```

```
$ burnrate live

  🔥 burnrate · LIVE
  watching ~/.claude/projects/-Users-zhangyida/.../...jsonl

  🔥 session $1.56  ·  上一轮 $0.20 (opus-4-7, cache 80%)  ·  19 轮  ·  avg $0.08/轮
```

---

## install

一行装,挂到 `~/.local/bin/`:

```bash
curl -fsSL https://raw.githubusercontent.com/yli769227-jpg/burnrate/main/install.sh | bash
```

需要 **Python 3.10+**(macOS / Linux 默认装的够新)。**零依赖,只用标准库**。

可选参数:

```bash
# 看脚本要做啥但不写
curl -fsSL https://raw.githubusercontent.com/yli769227-jpg/burnrate/main/install.sh | bash -s -- --dry-run

# 覆盖已存在副本
curl -fsSL ... | bash -s -- --force

# 卸载(精确移除 ~/.local/bin/burnrate + ~/.local/bin/pricing.json + .zshrc 标记块)
curl -fsSL ... | bash -s -- --uninstall
```

或者手动:

```bash
git clone https://github.com/yli769227-jpg/burnrate.git
cp burnrate/burnrate ~/.local/bin/burnrate && chmod +x ~/.local/bin/burnrate
cp burnrate/pricing.json ~/.local/bin/pricing.json
```

---

## 它为什么不会偷你的数据

- **本地文件 parser**,从头到尾只读 `~/.claude/projects/**/*.jsonl`
- **永不联网**(连 telemetry 都没有,你 grep 整个 codebase 找不到一个 http 请求)
- **价格表是静态 JSON**,可以自己改:

  ```bash
  vim ~/.local/bin/pricing.json   # 改完直接生效,不用重装
  ```

不放心? 整个工具就 1 个 `.py` 文件,500 行,你 `cat ~/.local/bin/burnrate` 自己 review。

---

## 三个命令

| 命令 | 用法 |
|---|---|
| `burnrate` | 今日烧钱速率 + 与昨日/7日均对比 + 按模型/项目切分 + 缓存命中 |
| `burnrate week` | 过去 7 天 ASCII 柱状图 + 模型分布 + 日均/月度估算 |
| `burnrate live` | 实时盯当前 session,每轮更新 |

---

## 价格表(2026-05)

| 模型 | input | output | cache write | cache read |
|---|---|---|---|---|
| Opus 4.7 | $5/M | $25/M | $6.25/M | $0.50/M |
| Sonnet 4.6 | $3/M | $15/M | $3.75/M | $0.30/M |
| Haiku 4.5 | $1/M | $5/M | $1.25/M | $0.10/M |

价格变了? **欢迎 PR 一行改 `pricing.json`**。

---

## FAQ

**Q: 我不用 Claude Code,用 Codex / Cursor 能用吗?**
A: V1 只读 Claude Code transcripts。Codex / Cursor 有类似 jsonl 但 schema 不同,在 backlog 里。

**Q: 那我跑 `burnrate` 显示的是 Anthropic 的实际账单吗?**
A: 不完全是 —— 我们读的是本地 transcript 的 `usage` 字段,Anthropic 后台可能有微小校准。差异通常 <1%。

**Q: cache hit rate 怎么定义?**
A: `cache_read_input_tokens / (input_tokens + cache_creation_input_tokens + cache_read_input_tokens)`。简单说: **总输入里有多少是命中缓存的**。

**Q: "省下约 $X" 怎么算的?**
A: `cache_read_input_tokens × (input_price - cache_read_price)`。意思: 如果你没用 prompt caching,这部分多花的钱。

---

## 路线图

- [x] V1: `today` / `week` / `live` 三命令 + curl 一行装
- [ ] `burnrate leaks` —— 找重复昂贵 turn / 低 cache hit / 注释 token 占比
- [ ] `burnrate top` —— 历史最贵 N 个 session
- [ ] `burnrate breakdown` —— 按时段/工具调用/分支切分
- [ ] Claude Code status line 集成
- [ ] 兼容 Codex / Cursor transcript schema

---

## 谁会用到

- 自费跑 Claude Code 的独立开发者(知道自己烧多少)
- 公司付费的开发者(给 PM/老板看一组数字证明价值,或证明该升 Sonnet)
- 在意 prompt caching 的人(看自己 hit rate 多少)
- 想在 Twitter 发"我这周烧了 $X"的 vibe-coder

---

## 致谢

灵感来自 [`caveman`](https://github.com/JuliusBrussee/caveman) —— "why use many token when few do trick" 的兄弟项目,它**减少 token 输出**,burnrate **测量 token 成本**。一前一后,刚好闭环。

---

## License

[MIT](LICENSE) —— 拿去用,记得给我 star ⭐

---

<p align="center">
  <em>burnrate is paranoid-friendly: zero deps, zero network, zero telemetry.<br/>
  Your transcripts never leave your machine.</em>
</p>
