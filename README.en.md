<h1 align="center">🔥 burnrate</h1>

<p align="center">
  <strong>How much money did you burn on Claude Code today?</strong><br/>
  <em>Real-time cost tracker for Claude Code · single-file Python · zero deps · never phones home</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT"></a>
  <img src="https://img.shields.io/badge/python-3.10+-blue.svg" alt="Python 3.10+">
  <a href="#install"><img src="https://img.shields.io/badge/install-curl_%7C_bash-green.svg" alt="curl | bash"></a>
  <img src="https://img.shields.io/badge/phones%20home-never-red.svg" alt="never phones home">
  <a href="README.md"><img src="https://img.shields.io/badge/lang-中文_%7C_English-orange.svg" alt="bilingual"></a>
</p>

---

## A simple question

> **How much did you spend on Claude Code in the last 7 days?**

**99% of users can't answer.**

Anthropic's console gives you raw event lists, Cursor and Codex don't tell you at all — you wait for your credit card statement.

`burnrate` reads `~/.claude/projects/**/*.jsonl` directly and gives you three numbers:

```
$ burnrate

  🔥 burnrate  2026-05-25 Mon · 14:58

    today           $44.21
    vs yesterday    ↑ 1143%   (yesterday $3.56)
    vs 7-day avg    ↓ 69%     (7d avg $142/day)

  by model
    opus-4-7             $44.21  100%  ████████████████

  by project
    ~                                            $20.89   47%
    ~/Dmall_projects/agent_hub                   $9.90    22%
    ~/projects/awesome-claude-code-cn            $4.40    10%

  cache hit         95%    (saved ~$165)
  most expensive    14:47   $0.80   ~/projects/burnrate
```

```
$ burnrate week

  🔥 burnrate · last 7 days  total $854

    Tue 05-19  ███░░░░░░░░░░░░░░░░░░░░░    $51.47
    Wed 05-20  ██████████░░░░░░░░░░░░░░    $145
    Thu 05-21  ███████████░░░░░░░░░░░░░    $172
    Fri 05-22  ████████████████████████    $361
    Sat 05-23  █████░░░░░░░░░░░░░░░░░░░    $76.83
    Sun 05-24  ░░░░░░░░░░░░░░░░░░░░░░░░    $3.56
    Mon 05-25  ███░░░░░░░░░░░░░░░░░░░░░    $44.30 ← today

  cache hit rate   97%    saved ~$4,922
  daily avg        $122 / day   (monthly est. $3,662)
```

```
$ burnrate live

  🔥 burnrate · LIVE
  watching ~/.claude/projects/-Users-zhangyida/.../...jsonl

  🔥 session $1.56  ·  last turn $0.20 (opus-4-7, cache 80%)  ·  19 turns  ·  avg $0.08/turn
```

---

## install

One line, drops binary into `~/.local/bin/`:

```bash
curl -fsSL https://raw.githubusercontent.com/yli769227-jpg/burnrate/main/install.sh | bash
```

Requires **Python 3.10+**. **Zero deps, stdlib only.**

```bash
# preview only (no writes)
curl -fsSL ... | bash -s -- --dry-run

# overwrite existing
curl -fsSL ... | bash -s -- --force

# uninstall (precise — removes binary, pricing.json, and .zshrc PATH block)
curl -fsSL ... | bash -s -- --uninstall
```

---

## Why this never steals your data

- **Pure local file parser**, only reads `~/.claude/projects/**/*.jsonl`
- **Never phones home** — grep the source, no `http` calls anywhere
- **Pricing is a static JSON**, edit it yourself:

  ```bash
  vim ~/.local/bin/pricing.json   # takes effect immediately
  ```

Don't trust me? It's one `.py` file, 500 lines. `cat ~/.local/bin/burnrate` and review it yourself.

---

## Three commands

| Command | What it does |
|---|---|
| `burnrate` | today + delta vs yesterday/7d-avg + by model/project + cache hit |
| `burnrate week` | last 7 days ASCII bar chart + daily avg + monthly estimate |
| `burnrate live` | watch current session, update every turn |

---

## Pricing (May 2026)

| Model | input | output | cache write | cache read |
|---|---|---|---|---|
| Opus 4.7 | $5/M | $25/M | $6.25/M | $0.50/M |
| Sonnet 4.6 | $3/M | $15/M | $3.75/M | $0.30/M |
| Haiku 4.5 | $1/M | $5/M | $1.25/M | $0.10/M |

Pricing changed? **PR welcome** — one-line edit to `pricing.json`.

---

## FAQ

**Q: I use Codex / Cursor, not Claude Code. Will it work?**
A: V1 reads Claude Code transcripts only. Codex / Cursor have similar JSONL with different schemas — on the backlog.

**Q: Does this match my actual Anthropic invoice?**
A: Not exactly — we read local transcript `usage` fields; Anthropic's backend may have small reconciliation differences (<1% typical).

**Q: How is cache hit rate defined?**
A: `cache_read_input_tokens / (input + cache_create + cache_read)`. In short: **fraction of total input that was cached**.

**Q: How is "saved ~$X" computed?**
A: `cache_read_input_tokens × (input_price - cache_read_price)`. Meaning: **what you would have paid without prompt caching**.

---

## Roadmap

- [x] V1: `today` / `week` / `live` + curl one-liner install
- [ ] `burnrate leaks` — find expensive repeated turns / low cache hit / % spent on comments
- [ ] `burnrate top` — top N most expensive historical sessions
- [ ] `burnrate breakdown` — by hour / tool-use / branch
- [ ] Claude Code statusline integration
- [ ] Codex / Cursor transcript support

---

## Who would use this

- Indie devs paying out of pocket (know what you burned)
- Devs at companies paying (show PM/manager a number that justifies the spend, or argue to drop to Sonnet)
- Anyone caring about prompt caching (see your hit rate)
- Vibe-coders who want to tweet "I burned $X this week"

---

## Credits

Inspired by [`caveman`](https://github.com/JuliusBrussee/caveman) — "why use many token when few do trick", a sibling project. `caveman` **reduces** token output, `burnrate` **measures** token cost. Use them together.

---

## License

[MIT](LICENSE) — take it, star it ⭐
