#!/usr/bin/env python3
"""Пересчитывает аналитику (индекс отклонений + экспертная система) по всем отчётам.

Нужен после переноса данных из Node-версии: сами отчёты переносятся, а аналитика
хранится отдельно и считается Java-версией заново. Работает только stdlib.

    python scripts/regenerate_analytics.py --api https://reportmed-api-v3.onrender.com \
        --username admin --password '...'
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request


def call(base: str, method: str, path: str, token: str | None = None, body: dict | None = None):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(base + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, raw.decode("utf-8", "replace")


def main() -> int:
    parser = argparse.ArgumentParser(description="Пересчёт аналитики по всем отчётам (от имени администратора)")
    parser.add_argument("--api", required=True, help="адрес API, например https://reportmed-api-v3.onrender.com")
    parser.add_argument("--username", required=True, help="логин администратора")
    parser.add_argument("--password", required=True, help="пароль администратора")
    args = parser.parse_args()
    base = args.api.rstrip("/")

    status, login = call(base, "POST", "/login", body={"username": args.username, "password": args.password})
    if status != 200 or not isinstance(login, dict) or not login.get("token"):
        print(f"не удалось войти: HTTP {status} {login}", file=sys.stderr)
        return 1
    token = login["token"]

    status, reports = call(base, "GET", "/admin/reports", token)
    if status != 200 or not isinstance(reports, list):
        print(f"не удалось получить список отчётов: HTTP {status} {reports}", file=sys.stderr)
        return 1

    ok = failed = 0
    for report in reports:
        rid = report.get("id")
        status, result = call(base, "POST", f"/analytics/report/{rid}/generate", token)
        if status == 200:
            ok += 1
            count = len(result) if isinstance(result, list) else "?"
            print(f"отчёт {rid}: ок, пациентов {count}")
        else:
            failed += 1
            print(f"отчёт {rid}: HTTP {status} {str(result)[:200]}", file=sys.stderr)

    print(f"\nготово: {ok} пересчитано, {failed} с ошибками, всего {len(reports)}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
