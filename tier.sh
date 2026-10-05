#!/usr/bin/env bash
# tier.sh — 设置 / 查看 / 测试 Claude Code 各档位（opus/sonnet/haiku/fable/smallfast）
# 到真实模型的映射。配置源是 CCR 的 config.sqlite。
set -euo pipefail

CCR_DIR="$HOME/.claude-code-router"
DB="$CCR_DIR/config.sqlite"
KEYFILE="$CCR_DIR/bin/ccr-claude-code-api-key-default-claude-code"
WRAPPER="$CCR_DIR/bin/ccr-claude-code-wrapper-default-claude-code"
GATEWAY="http://127.0.0.1:3456"
BACKUP_ROOT="$CCR_DIR/_backup-tier-map"
PROFILE_KEY="default"
PROFILE_ID="default-claude-code"

claude_bin() { ls -1 "$HOME"/.config/Claude-3p/claude-code/*/claude 2>/dev/null | sort -V | tail -1; }
appimage()   { ls -1 "$HOME"/Softwares/Claude-Code-Router_*.AppImage 2>/dev/null | sort -V | tail -1; }
apikey()     { bash "$KEYFILE" 2>/dev/null; }

# ---------- 依赖检查 ----------
have()      { command -v "$1" >/dev/null 2>&1; }
gw_up() {
  local k code; k=$(apikey 2>/dev/null)
  code=$(curl -s -m 5 -o /dev/null -w '%{http_code}' -H "x-api-key: $k" "$GATEWAY/v1/models" 2>/dev/null || echo 000)
  [ "$code" = "200" ]
}
config_ok() { [ -f "$DB" ] && db_dump >/dev/null 2>&1; }

# check_deps <命令>  —— 只检查该命令真正需要的项；缺项返回 1
check_deps() {
  local cmd="${1:-get}" FAILED=0
  _ok()  { printf '  [ok]  %s\n' "$1"; }
  _bad() { printf '  [!!]  %s\n' "$1"; FAILED=1; }
  echo "依赖检查（$cmd）:"

  if have python3 && python3 -c 'import sqlite3' 2>/dev/null; then _ok "python3 + sqlite3 模块"; else _bad "python3 + sqlite3 模块"; fi
  if config_ok; then _ok "CCR 配置可读 ($DB)"; else _bad "CCR 配置可读 ($DB)"; fi

  case "$cmd" in
    list|test|restart)
      have curl && _ok curl || _bad curl
      [ -x "$KEYFILE" ] && _ok "网关 API key 文件" || _bad "网关 API key 文件 ($KEYFILE)"
      ;;
  esac
  case "$cmd" in
    list|test)
      if gw_up; then _ok "网关在线 ($GATEWAY)"; else _bad "网关离线 ($GATEWAY) — 先跑: tier.sh restart"; fi
      ;;
  esac
  case "$cmd" in
    restart)
      [ -n "$(appimage)" ] && _ok "CCR AppImage" || _bad "CCR AppImage"
      have pkill  && _ok pkill  || _bad pkill
      have setsid && _ok setsid || _bad setsid
      ;;
    test)
      [ -f "$WRAPPER" ] && _ok "CCR wrapper（含档位映射）" || _bad "CCR wrapper — 先跑: tier.sh restart"
      [ -n "$(claude_bin)" ] && _ok "claude 可执行文件" || _bad "claude 可执行文件"
      ;;
  esac

  [ "$FAILED" = 0 ] && echo "  → 通过" || echo "  → 有缺失项，已中止"
  return $FAILED
}

# tier 名 -> config 字段名
field_of() {
  case "$1" in
    opus)      echo opusModel ;;
    sonnet)    echo sonnetModel ;;
    haiku)     echo haikuModel ;;
    fable)     echo fableModel ;;
    smallfast) echo smallFastModel ;;
    *) echo "unknown-tier:$1" >&2; return 1 ;;
  esac
}

db_dump() { python3 - "$DB" "$PROFILE_KEY" <<'PY'
import sqlite3, json, sys
db, key = sys.argv[1], sys.argv[2]
c = sqlite3.connect(db)
print(c.execute("select value_json from app_config where key=?", (key,)).fetchone()[0])
PY
}

db_write() {  # $1=field $2=value
  python3 - "$DB" "$PROFILE_KEY" "$PROFILE_ID" "$1" "$2" <<'PY'
import sqlite3, json, sys
db, key, pid, field, val = sys.argv[1:6]
c = sqlite3.connect(db)
d = json.loads(c.execute("select value_json from app_config where key=?", (key,)).fetchone()[0])
d["profile"]["claudeCode"][field] = val
for p in d["profile"].get("profiles", []):
    if p.get("id") == pid:
        p[field] = val
c.execute("update app_config set value_json=?, updated_at=datetime('now') where key=?",
          (json.dumps(d, ensure_ascii=False), key))
c.commit()
PY
}

cmd_list() {
  local k tmp; k=$(apikey); tmp=$(mktemp)
  curl -s -m 10 "$GATEWAY/v1/models" -H "x-api-key: $k" -o "$tmp"
  python3 - "$tmp" <<'PY'
import sys, json
from collections import defaultdict
g = defaultdict(list)
for m in json.load(open(sys.argv[1]))["data"]:
    g[m["owned_by"]].append(m["id"].split("/", 1)[1])
for p, ms in g.items():
    print("%s: %s" % (p, ", ".join(ms)))
PY
  rm -f "$tmp"
}

cmd_get() {
  db_dump | python3 -c '
import sys, json
cc = json.load(sys.stdin)["profile"]["claudeCode"]
for k in ("opusModel","sonnetModel","haikuModel","fableModel","smallFastModel"):
    print(f"  {k:14}= {cc.get(k)!r}")
'
}

cmd_backup() {
  local ts dir; ts=$(date +%Y%m%dT%H%M%S); dir="$BACKUP_ROOT/$ts"
  mkdir -p "$dir"
  cp -a "$DB" "$dir"/ 2>/dev/null || true
  cp -a "$DB-wal" "$dir"/ 2>/dev/null || true
  cp -a "$DB-shm" "$dir"/ 2>/dev/null || true
  cp -a "$HOME/.claude/settings.json" "$dir"/settings.json 2>/dev/null || true
  cat > "$dir/restore.sh" <<EOF
#!/bin/sh
set -e
D="\$(cd "\$(dirname "\$0")" && pwd)"
cp -a "\$D"/config.sqlite* "$CCR_DIR"/ 2>/dev/null || true
[ -f "\$D/settings.json" ] && cp -a "\$D/settings.json" "\$HOME/.claude/settings.json"
echo "已恢复。重启 CCR 后生效。"
EOF
  chmod +x "$dir/restore.sh"
  echo "$dir"
}

cmd_set() {  # $1=tier $2=value
  local tier="$1" val="$2" field bk
  field=$(field_of "$tier") || exit 1
  [ -z "${val:-}" ] && { echo "用法: tier.sh set <tier> <Provider/model>" >&2; exit 1; }
  bk=$(cmd_backup)
  db_write "$field" "$val"
  echo "已设置 $tier ($field) = $val"
  echo "备份: $bk"
  echo "→ 需重启 CCR 才对新建会话生效: tier.sh restart"
}

cmd_restart() {
  local APP; APP=$(appimage)
  [ -z "$APP" ] && { echo "找不到 AppImage" >&2; exit 1; }
  local LOG=/tmp/ccr-restart.log; : > "$LOG"
  export DISPLAY="${DISPLAY:-:1}"
  export XAUTHORITY="${XAUTHORITY:-/run/user/1000/gdm/Xauthority}"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
  export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/1000/bus}"
  pkill -f '/tmp/.mount_Claude.*/claude-code-router' 2>/dev/null || true
  pkill -f 'Claude-Code-Router_.*AppImage' 2>/dev/null || true
  for i in $(seq 1 30); do pgrep -f 'Claude-Code-Router_.*AppImage' >/dev/null || break; sleep 1; done
  setsid nohup "$APP" --no-sandbox >/tmp/ccr-app.out 2>&1 < /dev/null & disown
  local k code; k=$(apikey)
  for i in $(seq 1 90); do
    code=$(curl -s -m 3 -o /dev/null -w '%{http_code}' -H "x-api-key: $k" "$GATEWAY/v1/models" 2>/dev/null || echo 000)
    [ "$code" = "200" ] && { echo "网关已恢复 (${i}s)"; return 0; }
    sleep 1
  done
  echo "网关未在 90s 内恢复 (last=$code)" >&2; return 1
}

cmd_test() {  # $1=tier
  local tier="${1:-sonnet}" CB; CB=$(claude_bin)
  [ -z "$CB" ] && { echo "找不到 claude 可执行文件" >&2; exit 1; }
  [ -f "$WRAPPER" ] || { echo "找不到 wrapper；先 restart" >&2; exit 1; }
  # 取 CCR 生成的 ANTHROPIC_*/CLAUDE_* 环境（含档位映射），再补 App 注入的 key
  local envs
  envs=$(grep -E '^export (ANTHROPIC|CLAUDE_)' "$WRAPPER")
  local out
  out=$(env -i HOME="$HOME" PATH="$PATH" bash -c "
    $envs
    export ANTHROPIC_API_KEY='$(apikey)'
    echo \"映射值: \$ANTHROPIC_DEFAULT_$(echo "$tier" | tr a-z A-Z)_MODEL\" >&2
    '$CB' --model '$tier' -p 'Reply with exactly: $tier-OK' 2>&1
  ")
  echo "$out" | grep -v 'unrecognized_model'
  echo "--- 网关最近路由 ---"
  python3 - "$CCR_DIR/app-data/usage.sqlite" <<'PY'
import sqlite3, sys
c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
for r in c.execute("select created_at,model,provider,status_code from usage_events order by created_at desc limit 3"):
    print("  ", r)
PY
}

case "${1:-}" in
  check)    shift; check_deps "${1:-get}"; exit $? ;;
  help|-h|--help|"") cat <<EOF
用法: tier.sh <命令>
  check [命令]           只做依赖检查（可指定针对哪个命令，默认 get）
  list                   列出网关可用 provider/model
  get                    显示当前各档位映射
  set <tier> <值>        设置映射（tier: opus|sonnet|haiku|fable|smallfast，值: Provider/model），自动备份
  restart                重启 CCR 应用并等待网关恢复
  test [tier]            用新环境跑一次 claude --model <tier> 并看网关路由（默认 sonnet）
  backup                 手动备份配置
（list/set/restart/test 会先自动做依赖检查）
EOF
     exit 1 ;;
esac
# 其余命令先过依赖检查
CMD="$1"; shift
check_deps "$CMD" || exit 1
case "$CMD" in
  list)     cmd_list ;;
  get)      cmd_get ;;
  backup)   cmd_backup ;;
  set)      cmd_set "$@" ;;
  restart)  cmd_restart ;;
  test)     cmd_test "$@" ;;
esac
