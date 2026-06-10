#!/usr/bin/env bash
#
# burnrate installer
#
# Drops `burnrate` + `pricing.json` into ~/.local/bin (or $BURNRATE_BIN_DIR),
# ensures that dir is on PATH (adds a shim to ~/.zshrc / ~/.bashrc once).
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/yli769227-jpg/burnrate/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --force        # 覆盖已存在
#   curl -fsSL ... | bash -s -- --dry-run      # 只打印
#   curl -fsSL ... | bash -s -- --uninstall    # 卸载
#
# 也可本地直跑: bash install.sh [--force|--dry-run|--uninstall]
#

set -euo pipefail

REPO_TARBALL_URL="https://github.com/yli769227-jpg/burnrate/archive/refs/heads/main.tar.gz"
BIN_DIR="${BURNRATE_BIN_DIR:-$HOME/.local/bin}"
RC_MARKER_START="# >>> burnrate PATH >>>"
RC_MARKER_END="# <<< burnrate PATH <<<"

if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YEL=''; C_DIM=''; C_BLD=''; C_RST=''
fi
info() { printf '%s[+]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YEL" "$C_RST" "$*"; }
err()  { printf '%s[x]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
dim()  { printf '%s    %s%s\n' "$C_DIM" "$*" "$C_RST"; }

print_help() {
  # 内嵌 heredoc,而非 sed 读 "$0" —— curl|bash 方式下 $0 不是可读脚本文件,
  # sed 会失败,导致 README 主推的 `curl ... | bash -s -- --help` 不工作。
  cat <<'HELP'
burnrate installer

把 `burnrate` + `pricing.json` 装进 ~/.local/bin(或 $BURNRATE_BIN_DIR),
并确保该目录在 PATH 上(只向 ~/.zshrc / ~/.bashrc 注入一次)。

用法:
  curl -fsSL https://raw.githubusercontent.com/yli769227-jpg/burnrate/main/install.sh | bash
  curl -fsSL ... | bash -s -- --force        # 覆盖已存在
  curl -fsSL ... | bash -s -- --dry-run      # 只打印
  curl -fsSL ... | bash -s -- --uninstall    # 卸载

也可本地直跑: bash install.sh [--force|--dry-run|--uninstall]
HELP
}

FORCE=0; DRY_RUN=0; DO_UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --uninstall) DO_UNINSTALL=1 ;;
    --help|-h) print_help; exit 0 ;;
    *) err "未知参数: $arg (用 --help)"; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { err "需要 $1 但没找到"; exit 1; }; }

# ---------- uninstall ----------
remove_path_block() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  if grep -qF "$RC_MARKER_START" "$rc"; then
    info "剥离 $rc 的 PATH 标记块"
    # 注意: 不要写成 `[ "$DRY_RUN" = 0 ] && cmd` —— dry-run 下该模式让函数返回 1,
    # 配合 set -e 会使脚本提前退出。
    if [ "$DRY_RUN" = 0 ]; then
      awk -v s="$RC_MARKER_START" -v e="$RC_MARKER_END" '
        index($0,s) { skip=1; next }
        skip && index($0,e) { skip=0; next }
        !skip { print }
      ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
    fi
  fi
}

if [ "$DO_UNINSTALL" = 1 ]; then
  info "卸载 burnrate"
  for f in burnrate pricing.json; do
    if [ -f "$BIN_DIR/$f" ]; then
      info "删除 $BIN_DIR/$f"
      if [ "$DRY_RUN" = 0 ]; then rm -f "$BIN_DIR/$f"; fi
    fi
  done
  remove_path_block "$HOME/.zshrc"
  remove_path_block "$HOME/.bashrc"
  remove_path_block "$HOME/.profile"
  info "卸载完成 ✅"
  exit 0
fi

# ---------- install ----------
need curl
need tar
need python3

py_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
py_major=$(python3 -c 'import sys; print(sys.version_info.major)')
py_minor=$(python3 -c 'import sys; print(sys.version_info.minor)')
if [ "$py_major" -lt 3 ] || { [ "$py_major" = 3 ] && [ "$py_minor" -lt 10 ]; }; then
  err "需要 Python 3.10+,当前 $py_version"
  exit 1
fi
dim "python3 $py_version ✓"

TMP_DIR="$(mktemp -d -t burnrate-XXXXXX)"
cleanup() { [ -n "${TMP_DIR:-}" ] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd 2>/dev/null || pwd)"
if [ -f "$SCRIPT_DIR/burnrate" ] && [ -f "$SCRIPT_DIR/pricing.json" ]; then
  info "检测到本地仓库,跳过下载"
  SRC_ROOT="$SCRIPT_DIR"
else
  info "下载 burnrate 源码到临时目录"
  if ! curl -fsSL "$REPO_TARBALL_URL" | tar -xz -C "$TMP_DIR" --strip-components=1; then
    err "下载/解压失败,检查网络"
    exit 1
  fi
  SRC_ROOT="$TMP_DIR"
fi

if [ "$DRY_RUN" = 1 ]; then warn "DRY RUN 模式 —— 不会写文件"; fi
info "目标目录: $BIN_DIR"
if [ "$DRY_RUN" = 0 ]; then mkdir -p "$BIN_DIR"; fi

for f in burnrate pricing.json; do
  src="$SRC_ROOT/$f"
  dst="$BIN_DIR/$f"
  if [ ! -f "$src" ]; then
    err "源文件缺失: $src"; exit 1
  fi
  if [ -f "$dst" ] && [ "$FORCE" != 1 ]; then
    dim "$f 已存在,跳过(--force 覆盖)"
  else
    info "安装 $f"
    if [ "$DRY_RUN" = 0 ]; then
      cp "$src" "$dst"
      if [ "$f" = "burnrate" ]; then chmod +x "$dst"; fi
    fi
  fi
done

# ---------- 确保 PATH ----------
ensure_path() {
  if echo ":$PATH:" | grep -qF ":$BIN_DIR:"; then
    dim "PATH 已包含 $BIN_DIR"
    return 0
  fi

  # pick rc file
  local rc=""
  if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
    rc="$HOME/.zshrc"
  elif [ -n "${BASH_VERSION:-}" ] || [ -f "$HOME/.bashrc" ]; then
    rc="$HOME/.bashrc"
  else
    rc="$HOME/.profile"
  fi

  if [ -f "$rc" ] && grep -qF "$RC_MARKER_START" "$rc"; then
    dim "$rc 已有 burnrate PATH 块"
    return 0
  fi

  info "向 $rc 添加 PATH(标记块,可幂等卸载)"
  if [ "$DRY_RUN" = 0 ]; then
    {
      printf '\n%s\n' "$RC_MARKER_START"
      printf 'export PATH="%s:$PATH"\n' "$BIN_DIR"
      printf '%s\n' "$RC_MARKER_END"
    } >> "$rc"
  fi
  warn "新 shell 才生效。当前 shell 临时启用:  export PATH=\"$BIN_DIR:\$PATH\""
}
ensure_path

echo
info "完成 ✅"
dim "burnrate 在 $BIN_DIR/burnrate"
dim "试试: ${C_BLD}burnrate${C_RST}${C_DIM}  /  burnrate week  /  burnrate live${C_RST}"
dim "卸载: curl -fsSL https://raw.githubusercontent.com/yli769227-jpg/burnrate/main/install.sh | bash -s -- --uninstall"
