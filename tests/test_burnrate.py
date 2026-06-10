# -*- coding: utf-8 -*-
"""burnrate 纯函数 + CLI 聚合测试。

主脚本 `burnrate` 无 .py 后缀,用 importlib SourceFileLoader 按路径加载;
today 聚合走 subprocess 跑真实 CLI。
"""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "burnrate"
PRICING = json.loads((REPO / "pricing.json").read_text())


def _load_module():
    loader = importlib.machinery.SourceFileLoader("burnrate_mod", str(SCRIPT))
    spec = importlib.util.spec_from_loader("burnrate_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


br = _load_module()


# ---------- normalize_model ----------
def test_normalize_model_none():
    assert br.normalize_model(None) is None
    assert br.normalize_model("") is None


def test_normalize_model_strips_bracket_suffix():
    assert br.normalize_model("claude-opus-4-7[1m]") == "claude-opus-4-7"


def test_normalize_model_strips_date_suffix():
    assert br.normalize_model("claude-haiku-4-5-20251001") == "claude-haiku-4-5"


def test_normalize_model_plain():
    assert br.normalize_model("claude-sonnet-4-6") == "claude-sonnet-4-6"


# ---------- price_for ----------
def test_price_for_known_model():
    assert br.price_for("claude-haiku-4-5", PRICING) == PRICING["models"]["claude-haiku-4-5"]


def test_price_for_none_returns_fallback():
    assert br.price_for(None, PRICING) == PRICING["fallback"]


def test_price_for_unknown_model_falls_back_not_prefix(capsys):
    """未知新模型(claude-opus-4-8)必须走 fallback,不能前缀命中 claude-opus-4 按旧款高价计。"""
    br._warned_models.clear()
    p = br.price_for("claude-opus-4-8", PRICING)
    assert p == PRICING["fallback"]
    assert p != PRICING["models"]["claude-opus-4"]
    err = capsys.readouterr().err
    assert "未知模型 claude-opus-4-8" in err


def test_price_for_unknown_model_warns_once(capsys):
    br._warned_models.clear()
    br.price_for("claude-opus-4-9", PRICING)
    br.price_for("claude-opus-4-9", PRICING)
    err = capsys.readouterr().err
    assert err.count("未知模型 claude-opus-4-9") == 1


def test_price_for_known_model_no_warning(capsys):
    br._warned_models.clear()
    br.price_for("claude-sonnet-4-6", PRICING)
    assert capsys.readouterr().err == ""


# ---------- cost_of ----------
def test_cost_of():
    usage = {
        "input_tokens": 1_000_000,
        "output_tokens": 100_000,
        "cache_creation_input_tokens": 200_000,
        "cache_read_input_tokens": 500_000,
    }
    price = {"input": 1, "output": 5, "cache_write": 1.25, "cache_read": 0.10}
    # 1*1 + 0.1*5 + 0.2*1.25 + 0.5*0.10 = 1.80
    assert abs(br.cost_of(usage, price) - 1.80) < 1e-9


def test_cost_of_missing_fields():
    assert br.cost_of({}, {"input": 3}) == 0


# ---------- 去重 ----------
def _event_line(ts, msg_id, req_id, model="claude-haiku-4-5", input_tokens=1_000_000):
    d = {
        "timestamp": ts,
        "sessionId": "s1",
        "cwd": "/tmp/projA",
        "message": {
            "role": "assistant",
            "model": model,
            "usage": {
                "input_tokens": input_tokens,
                "output_tokens": 0,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0,
            },
        },
    }
    if msg_id is not None:
        d["message"]["id"] = msg_id
    if req_id is not None:
        d["requestId"] = req_id
    return json.dumps(d)


def _utc_ts(dt=None):
    dt = dt or datetime.now(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")


def test_iter_events_dedup_across_files(tmp_path):
    """同一 message.id + requestId 出现在两个文件(--resume 复制历史)只计一次。"""
    ts = _utc_ts()
    (tmp_path / "a.jsonl").write_text(_event_line(ts, "msg_1", "req_1") + "\n")
    (tmp_path / "b.jsonl").write_text(_event_line(ts, "msg_1", "req_1") + "\n")
    events = list(br.iter_events(tmp_path))
    assert len(events) == 1


def test_iter_events_distinct_request_ids_kept(tmp_path):
    ts = _utc_ts()
    lines = _event_line(ts, "msg_1", "req_1") + "\n" + _event_line(ts, "msg_1", "req_2") + "\n"
    (tmp_path / "a.jsonl").write_text(lines)
    assert len(list(br.iter_events(tmp_path))) == 2


def test_iter_events_missing_id_not_deduped(tmp_path):
    """缺 message.id / requestId 的行无法判重,照常全计。"""
    ts = _utc_ts()
    (tmp_path / "a.jsonl").write_text(_event_line(ts, None, None) + "\n")
    (tmp_path / "b.jsonl").write_text(_event_line(ts, None, None) + "\n")
    assert len(list(br.iter_events(tmp_path))) == 2


# ---------- CLI today 聚合 ----------
def _run_cli(projects_dir, *args):
    env = dict(os.environ, BURNRATE_PROJECTS_DIR=str(projects_dir), NO_COLOR="1")
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, env=env, timeout=30,
    )


def test_cli_today_dedup_and_avg7d(tmp_path):
    """fixture jsonl 跑 today: 去重后今日 $1.000;7日均只算过去 7 个完整日(不含今天)。"""
    now = datetime.now(timezone.utc)
    today_ts = _utc_ts(now)
    yest_ts = _utc_ts(now - timedelta(hours=24))
    # 今日: haiku 1M input = $1.000,同一 message.id+requestId 复制进两个文件
    (tmp_path / "a.jsonl").write_text(
        _event_line(today_ts, "msg_t", "req_t") + "\n"
        + _event_line(yest_ts, "msg_y", "req_y", input_tokens=7_000_000) + "\n"
    )
    (tmp_path / "b.jsonl").write_text(_event_line(today_ts, "msg_t", "req_t") + "\n")
    r = _run_cli(tmp_path, "today")
    assert r.returncode == 0, r.stderr
    out = r.stdout
    # 去重: 今日 $1.000 而非 $2.000
    assert "$1.000" in out
    assert "$2.000" not in out
    # 7日均 = 昨日 $7 / 7 完整日 = $1.000/天 (若含今天则为 8/7=$1.143 → 断言失败)
    assert "7日均 $1.000/天" in out
    assert "$1.143" not in out


def test_cli_week_runs(tmp_path):
    (tmp_path / "a.jsonl").write_text(_event_line(_utc_ts(), "msg_1", "req_1") + "\n")
    r = _run_cli(tmp_path, "week")
    assert r.returncode == 0, r.stderr
    assert "过去 7 天" in r.stdout
    assert "$1.000" in r.stdout


def test_cli_version():
    r = subprocess.run([sys.executable, str(SCRIPT), "--version"],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 0
    assert "burnrate" in r.stdout
