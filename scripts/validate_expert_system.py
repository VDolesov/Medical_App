

from __future__ import annotations

import argparse
import io
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import pandas as pd

EXTRA_FIELDS = {
    "Диагноз по TNM. T": ("tnm_t_pre", "string"),
    "Диагноз по TNM. N": ("tnm_n_pre", "string"),
    "Диагноз по TNM. M": ("tnm_m_pre", "string"),
    "Диагноз по TNM после гистологии. T": ("tnm_t_post", "string"),
    "Диагноз по TNM после гистологии. N": ("tnm_n_post", "string"),
    "Диагноз по TNM после гистологии. M": ("tnm_m_post", "string"),
    "Вид операции": ("operation_type", "string"),
    "Длительность заболевания (месяц)": ("disease_duration_months", "int"),
    "Время нахождения в стационаре после операции (дни)": ("hospital_stay_days", "int"),
    "Сопутствующие заболевания ССС": ("comorbidity_cv", "int"),
    "Сопутствующие заболевания ЖКТ": ("comorbidity_gi", "int"),
    "Сопутствующие заболевания ДС": ("comorbidity_resp", "int"),
    "Интероперационные осложнения": ("intraop_complications", "int"),
    "Послеоперационный рецидив": ("known_recurrence", "int"),
    "Цитологическая классификация после ТАБ по  системе Bethesda (диагностическая категория от 1 до 5)": ("bethesda", "int"),
    "Цитологическая классификация после ТАБ по системе Bethesda (диагностическая категория от 1 до 5)": ("bethesda", "int"),
}

def resolve_marker(col_name: str) -> tuple[str, bool] | None:
    s = (col_name or "").strip().lower()
    post = "после операции" in s
    s = s.replace("после операции", "").strip()

    if "(" in s:
        s = s.split("(")[0].strip()
    if "," in s:
        s = s.split(",")[0].strip()
    table = {
        "ттг": "tsh",
        "т4 свободный": "t4_free",
        "т4": "t4_free",
        "кальцитонин": "calcitonin",
        "паратгормон": "parathyroid",
        "антитела к тиреоглобулину": "antibody_to_tg",
        "рэа": "cea",
        "кальций общий": "calcium",
        "щелочная фосфатаза": "alp",
    }
    base = table.get(s)
    return (base, post) if base else None

def row_to_facts(row: pd.Series, columns: list[str]) -> dict[str, Any]:
    facts: dict[str, Any] = {}
    facts["age"] = _safe_int(row.get("Возраст"))
    for col in columns:
        if col in EXTRA_FIELDS:
            key, kind = EXTRA_FIELDS[col]
            v = row.get(col)
            if pd.isna(v):
                continue
            facts[key] = int(v) if kind == "int" else str(v).strip()
            continue
        mk = resolve_marker(col)
        if mk is None:
            continue
        base, post = mk
        v = row.get(col)
        if pd.isna(v):
            continue
        facts[f"{base}_{'post' if post else 'pre'}"] = float(v)

    for base in ("calcitonin", "antibody_to_tg", "cea", "tsh"):
        pre = facts.get(f"{base}_pre")
        post = facts.get(f"{base}_post")
        if pre is not None and post is not None:
            facts[f"{base}_delta"] = float(post) - float(pre)
    return facts

def _safe_int(v: Any) -> int | None:
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    try:
        return int(v)
    except (ValueError, TypeError):
        return None

def evaluate(condition: dict[str, Any], facts: dict[str, Any]) -> tuple[bool, dict[str, Any]]:
    matched: dict[str, Any] = {}
    ok = _eval_node(condition, facts, matched)
    return ok, matched if ok else {}

def _eval_node(node: dict[str, Any], facts: dict[str, Any], matched: dict[str, Any]) -> bool:
    if not node:
        return False
    if "all" in node:
        for c in node["all"]:
            tmp: dict[str, Any] = {}
            if not _eval_node(c, facts, tmp):
                return False
            matched.update(tmp)
        return True
    if "any" in node:
        for c in node["any"]:
            tmp: dict[str, Any] = {}
            if _eval_node(c, facts, tmp):
                matched.update(tmp)
                return True
        return False
    if "not" in node:
        tmp: dict[str, Any] = {}
        return not _eval_node(node["not"], facts, tmp)
    if "feature" in node and "op" in node:
        return _eval_leaf(node, facts, matched)
    return False

def _eval_leaf(leaf: dict[str, Any], facts: dict[str, Any], matched: dict[str, Any]) -> bool:
    feature = leaf["feature"]
    op = leaf["op"]
    fv = facts.get(feature)
    exp = leaf.get("value")
    exp_list = leaf.get("values")

    def num(a: Any) -> float | None:
        if a is None:
            return None
        try:
            return float(a)
        except (TypeError, ValueError):
            return None

    res = False
    if op == "present":
        res = fv is not None
    elif op == "absent":
        res = fv is None
    elif op == "eq":
        res = _eq(fv, exp)
    elif op == "neq":
        res = fv is not None and not _eq(fv, exp)
    elif op in ("gt", "gte", "lt", "lte"):
        x, y = num(fv), num(exp)
        if x is None or y is None:
            res = False
        else:
            res = {"gt": x > y, "gte": x >= y, "lt": x < y, "lte": x <= y}[op]
    elif op == "in":
        res = fv is not None and any(_eq(fv, e) for e in (exp_list or []))
    elif op == "not_in":
        res = fv is not None and not any(_eq(fv, e) for e in (exp_list or []))
    elif op == "range":
        x = num(fv)
        if x is None or not exp_list or len(exp_list) != 2:
            res = False
        else:
            lo, hi = num(exp_list[0]), num(exp_list[1])
            res = lo is not None and hi is not None and lo <= x <= hi
    elif op == "out_of_range":
        x = num(fv)
        if x is None or not exp_list or len(exp_list) != 2:
            res = False
        else:
            lo, hi = num(exp_list[0]), num(exp_list[1])
            res = lo is not None and hi is not None and (x < lo or x > hi)
    if res:
        matched[feature] = fv
    return res

def _eq(a: Any, b: Any) -> bool:
    if a is None or b is None:
        return a is b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(float(a) - float(b)) < 1e-9
    return str(a) == str(b)

RISK_RULE_CODES = {"R-002", "R-003", "R-005", "R-006", "R-011"}

@dataclass
class PatientVerdict:
    triggered: list[str]
    severities: list[str]
    flag_risk: bool

def apply_rules(rules: list[dict[str, Any]], facts: dict[str, Any]) -> PatientVerdict:
    triggered: list[str] = []
    severities: list[str] = []
    for r in rules:
        ok, _ = evaluate(r["condition"], facts)
        if ok:
            triggered.append(r["code"])
            severities.append(r["severity"])
    flag = any(c in RISK_RULE_CODES for c in triggered)
    return PatientVerdict(triggered=triggered, severities=severities, flag_risk=flag)

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--xlsx", required=True, help="путь к dataspeed.xlsx")
    parser.add_argument("--rules", default="scripts/rules_export.json")
    parser.add_argument("--out", default="scripts/out")
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    with open(args.rules, "r", encoding="utf-8") as f:
        rules_doc = json.load(f)
    rules = rules_doc["rules"]
    print(f"Загружено правил: {len(rules)} (версия {rules_doc.get('version','—')})")

    df = pd.read_excel(args.xlsx).dropna(how="all")

    bethesda_col = next(
        (c for c in df.columns if "Bethesda" in c or "ethesda" in c),
        None,
    )
    if bethesda_col:
        df.loc[df[bethesda_col] > 5, bethesda_col] = None
    print(f"Пациентов в датасете: {len(df)}")

    columns = list(df.columns)
    verdicts: list[PatientVerdict] = []
    facts_list: list[dict[str, Any]] = []
    for _, row in df.iterrows():
        facts = row_to_facts(row, columns)
        verdicts.append(apply_rules(rules, facts))
        facts_list.append(facts)

    df_out = df.copy().reset_index(drop=True)
    df_out["es_triggered_codes"] = [",".join(v.triggered) for v in verdicts]
    df_out["es_triggered_count"] = [len(v.triggered) for v in verdicts]
    df_out["es_flag_risk"] = [int(v.flag_risk) for v in verdicts]

    has_truth = "Послеоперационный рецидив" in df.columns
    if has_truth:
        truth = df["Послеоперационный рецидив"].reset_index(drop=True).fillna(-1).astype(int)
        pred = df_out["es_flag_risk"].astype(int)
        valid_mask = truth.isin([0, 1])
        y_true = truth[valid_mask].to_numpy()
        y_pred = pred[valid_mask].to_numpy()
        _print_classification(y_true, y_pred)
        _save_confusion(y_true, y_pred, out_dir / "confusion_matrix.png")
        _save_rule_frequency(rules, verdicts, out_dir / "rule_frequency.png")
        _save_severity_per_truth(verdicts, truth.to_numpy(), out_dir / "severity_by_recurrence.png")
    else:
        print("Колонка 'Послеоперационный рецидив' не найдена — пропускаем оценку точности.")

    csv_path = out_dir / "verdicts.csv"
    df_out.to_csv(csv_path, index=False, encoding="utf-8-sig")
    print(f"Результаты по пациентам: {csv_path}")
    print(f"Графики в:               {out_dir.resolve()}")
    return 0

def _print_classification(y_true, y_pred) -> None:
    tp = int(((y_pred == 1) & (y_true == 1)).sum())
    tn = int(((y_pred == 0) & (y_true == 0)).sum())
    fp = int(((y_pred == 1) & (y_true == 0)).sum())
    fn = int(((y_pred == 0) & (y_true == 1)).sum())
    n = tp + tn + fp + fn
    sens = tp / (tp + fn) if (tp + fn) else 0.0
    spec = tn / (tn + fp) if (tn + fp) else 0.0
    ppv = tp / (tp + fp) if (tp + fp) else 0.0
    npv = tn / (tn + fn) if (tn + fn) else 0.0
    acc = (tp + tn) / n if n else 0.0
    f1 = (2 * tp) / (2 * tp + fp + fn) if (2 * tp + fp + fn) else 0.0
    print(f"\n=== Оценка согласованности с известным рецидивом (n={n}) ===")
    print(f"TP={tp}  FP={fp}  FN={fn}  TN={tn}")
    print(f"Чувствительность (recall): {sens:.3f}")
    print(f"Специфичность:             {spec:.3f}")
    print(f"PPV (точность):            {ppv:.3f}")
    print(f"NPV:                       {npv:.3f}")
    print(f"Accuracy:                  {acc:.3f}")
    print(f"F1:                        {f1:.3f}")

def _save_confusion(y_true, y_pred, path: Path) -> None:
    try:
        import matplotlib.pyplot as plt
    except Exception:
        return
    import numpy as np
    tp = int(((y_pred == 1) & (y_true == 1)).sum())
    tn = int(((y_pred == 0) & (y_true == 0)).sum())
    fp = int(((y_pred == 1) & (y_true == 0)).sum())
    fn = int(((y_pred == 0) & (y_true == 1)).sum())
    matrix = np.array([[tn, fp], [fn, tp]])
    fig, ax = plt.subplots(figsize=(4.5, 4))
    im = ax.imshow(matrix, cmap="Blues")
    ax.set_xticks([0, 1]); ax.set_yticks([0, 1])
    ax.set_xticklabels(["pred = 0", "pred = 1"])
    ax.set_yticklabels(["true = 0", "true = 1"])
    for i in range(2):
        for j in range(2):
            ax.text(j, i, str(matrix[i, j]), ha="center", va="center",
                    color="white" if matrix[i, j] > matrix.max() / 2 else "black")
    ax.set_title("Confusion matrix — экспертная система vs рецидив")
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    plt.close(fig)

def _save_rule_frequency(rules: list[dict[str, Any]], verdicts: list[PatientVerdict], path: Path) -> None:
    try:
        import matplotlib.pyplot as plt
    except Exception:
        return
    codes = [r["code"] for r in rules]
    counts = {c: 0 for c in codes}
    for v in verdicts:
        for c in v.triggered:
            if c in counts:
                counts[c] += 1
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar(list(counts.keys()), list(counts.values()), color="#3949ab")
    ax.set_xticklabels(list(counts.keys()), rotation=30, ha="right")
    ax.set_ylabel("Количество срабатываний")
    ax.set_title("Как часто срабатывает каждое правило (n={n})".format(n=len(verdicts)))
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    plt.close(fig)

def _save_severity_per_truth(verdicts: list[PatientVerdict], truth, path: Path) -> None:
    try:
        import matplotlib.pyplot as plt
    except Exception:
        return
    import numpy as np
    severity_weight = {"INFO": 1, "WARNING": 2, "CRITICAL": 3}
    counts = {0: [0, 0, 0, 0], 1: [0, 0, 0, 0]}
    for v, t in zip(verdicts, truth):
        if t not in (0, 1):
            continue
        if not v.severities:
            counts[t][0] += 1
            continue
        max_sev = max(severity_weight[s] for s in v.severities)
        counts[t][max_sev] += 1
    labels = ["нет правил", "INFO", "WARNING", "CRITICAL"]
    x = np.arange(len(labels))
    width = 0.4
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar(x - width / 2, counts[0], width, label="без рецидива", color="#388e3c")
    ax.bar(x + width / 2, counts[1], width, label="с рецидивом", color="#c62828")
    ax.set_xticks(x); ax.set_xticklabels(labels)
    ax.set_ylabel("Пациентов")
    ax.set_title("Severity по группам исхода")
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    plt.close(fig)

if __name__ == "__main__":
    sys.exit(main())
