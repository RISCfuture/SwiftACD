#!/usr/bin/env python3
"""Generate sample_acd.xlsx — a minimal but standards-compliant FAA-shaped
Aircraft Characteristics Database workbook for SwiftACD tests.

Contains 8 representative aircraft including:
  * B738 (two variants — winglets vs. no winglets) for variant-fanout coverage
  * A320 (overlap with APD)
  * C172 (light piston, ACD-only)
  * B748 (heavy, ADG VI / TDG 7)
  * One row with an unparseable ADG to exercise per-row error handling.
"""

from __future__ import annotations
import io
import os
import zipfile
from xml.sax.saxutils import escape

OUTPUT = os.path.join(os.path.dirname(__file__), "sample_acd.xlsx")

HEADERS = [
  "ICAO Type Designator",
  "Manufacturer",
  "Model",
  "AAC",
  "ADG",
  "TDG",
  "MTOW (lbs)",
  "Wingspan (ft)",
  "Length (ft)",
  "Tail Height (ft)",
  "MGW (ft)",
  "CMG (ft)",
  "Approach Speed (kt)",
]

ROWS = [
  ["B738", "Boeing", "737-800",        "C", "III", "3", 174200, 117.4, 129.5, 41.3, 18.9, 49.2, 142],
  ["B738", "Boeing", "737-800W",       "C", "III", "3", 174200, 117.4, 129.5, 41.3, 18.9, 49.2, 142],
  ["A320", "Airbus", "A320-200",       "C", "III", "3", 169755, 111.8, 123.3, 38.6, 24.6, 41.7, 138],
  ["C172", "Cessna", "172 Skyhawk",    "A", "I",   "1A",  2550,  36.1,  27.2,  8.9,   8.4,  6.1,  61],
  ["B748", "Boeing", "747-8 Intercont","D", "VI",  "7",  987000, 224.4, 250.2, 63.5, 36.1,116.8, 154],
  ["DH8D", "Bombardier", "Dash 8 Q400","B", "III", "3",  64500,  93.3,  107.8, 27.4, 24.6, 38.0, 121],
  ["GLF6", "Gulfstream", "G650",       "C", "II",  "2A", 99600,  99.6,   99.7, 25.6, 14.8, 39.1, 132],
  ["XXXX", "BadEnumCo", "InvalidADG",  "C", "ZZZ", "3",  10000,  40.0,   30.0,  9.0,  8.0,  6.0, 100],
]


def cell_xml(reference: str, value, sst_index: dict, strings: list) -> str:
  """Emit an OOXML <c> element for one cell, using shared strings for text."""
  if isinstance(value, (int, float)):
    return f'<c r="{reference}"><v>{value}</v></c>'
  text = str(value)
  if text not in sst_index:
    sst_index[text] = len(strings)
    strings.append(text)
  return f'<c r="{reference}" t="s"><v>{sst_index[text]}</v></c>'


def column_letter(index: int) -> str:
  result = ""
  index += 1
  while index:
    index, rem = divmod(index - 1, 26)
    result = chr(65 + rem) + result
  return result


def build_sheet_xml(rows: list[list]) -> tuple[str, list[str]]:
  strings: list[str] = []
  sst_index: dict[str, int] = {}
  row_xmls = []
  for r_idx, row in enumerate(rows, start=1):
    cells = []
    for c_idx, value in enumerate(row):
      ref = f"{column_letter(c_idx)}{r_idx}"
      cells.append(cell_xml(ref, value, sst_index, strings))
    row_xmls.append(f'<row r="{r_idx}">{"".join(cells)}</row>')
  sheet = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    f'<sheetData>{"".join(row_xmls)}</sheetData>'
    '</worksheet>'
  )
  return sheet, strings


def build_shared_strings_xml(strings: list[str]) -> str:
  items = "".join(f"<si><t>{escape(s)}</t></si>" for s in strings)
  return (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    f'count="{len(strings)}" uniqueCount="{len(strings)}">{items}</sst>'
  )


CONTENT_TYPES = (
  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
  '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
  '<Default Extension="xml" ContentType="application/xml"/>'
  '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
  '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
  '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
  '</Types>'
)

ROOT_RELS = (
  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
  '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
  '</Relationships>'
)

WORKBOOK_XML = (
  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
  'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
  '<sheets><sheet name="ACD" sheetId="1" r:id="rId1"/></sheets>'
  '</workbook>'
)

WORKBOOK_RELS = (
  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
  '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
  '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
  '</Relationships>'
)


def main() -> None:
  sheet, strings = build_sheet_xml([HEADERS, *ROWS])
  shared = build_shared_strings_xml(strings)

  buf = io.BytesIO()
  with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.writestr("[Content_Types].xml", CONTENT_TYPES)
    zf.writestr("_rels/.rels", ROOT_RELS)
    zf.writestr("xl/workbook.xml", WORKBOOK_XML)
    zf.writestr("xl/_rels/workbook.xml.rels", WORKBOOK_RELS)
    zf.writestr("xl/worksheets/sheet1.xml", sheet)
    zf.writestr("xl/sharedStrings.xml", shared)

  with open(OUTPUT, "wb") as f:
    f.write(buf.getvalue())
  print(f"Wrote {OUTPUT} ({len(buf.getvalue())} bytes)")


if __name__ == "__main__":
  main()
