#!/usr/bin/env python3
"""Snapshots the authoritative DEFECT LIST sheet of DEFECT_REPORT_LIST.xlsx
into tool/defect_list_source.json, so tests can prove the generated
catalogue (tool/generate_defect_catalogue.py -> Flutter + Functions) still
matches the source workbook.

Usage: python3 tool/extract_defect_list_source.py path/to/DEFECT_REPORT_LIST.xlsx
Needs openpyxl. Columns A:D of sheet "DEFECT LIST" only.

Blank Main Element / Component cells inherit the previous row's value; a
row with only an action continues the previous action (a cell the
workbook split across two rows). Whitespace is collapsed and spacing
around "/" is normalised (the sheet's "a/ b" is a line-wrap artefact).
"""
import json
import re
import sys
from pathlib import Path

import openpyxl


def clean(value):
    if value is None:
        return None
    text = re.sub(r"\s*/\s*", "/", str(value))
    return re.sub(r"\s+", " ", text).strip() or None


def main(path):
    sheet = openpyxl.load_workbook(path, data_only=True)["DEFECT LIST"]
    elements, rows = [], []
    element = component = None
    for a, b, c, d in sheet.iter_rows(min_row=3, max_col=4, values_only=True):
        a, b, c, d = clean(a), clean(b), clean(c), clean(d)
        if a:
            element, component = a, None
            if a not in elements:
                elements.append(a)
        if b:
            component = b
        if not c:
            if d and rows:
                rows[-1]["action"] = f"{rows[-1]['action'] or ''} {d}".strip()
            continue
        rows.append({"element": element, "component": component,
                     "defect": c, "action": d})
    out = Path(__file__).with_name("defect_list_source.json")
    out.write_text(json.dumps({"elements": elements, "entries": rows},
                              indent=1, ensure_ascii=False) + "\n")
    print(f"{len(elements)} elements, "
          f"{len({(r['element'], r['component']) for r in rows})} components, "
          f"{len(rows)} defects -> {out}")


if __name__ == "__main__":
    main(sys.argv[1])
