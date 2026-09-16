#!/usr/bin/env python3
"""Check feature coverage and local documentation links without third-party modules."""
import json
import re
from pathlib import Path
from generate import ROOT, rows


def main():
    features = rows("docs/features.tsv")
    ids = {f["id"] for f in features}
    assert len(ids) == len(features), "duplicate feature IDs"
    fixtures = json.loads((ROOT / "tests/cases.json").read_text())
    positive, boundary, rejected = set(), set(), set()
    for case in fixtures:
        path = ROOT / case["path"]
        assert path.is_file(), f"missing fixture: {path}"
        assert case["kind"] in {"run", "reject", "runtime"}, case
        if "reference_reject_hosts" in case:
            hosts = case["reference_reject_hosts"]
            assert case["kind"] == "reject" and hosts, case
            assert len(set(hosts)) == len(hosts) and set(hosts) <= {"smlnj", "polyml", "mlton"}, case
        mapped = set(case["features"])
        assert mapped <= ids, f"unknown feature IDs: {mapped - ids}"
        edges = set(case.get("boundary", []))
        assert edges <= mapped, "boundary feature must also be mapped"
        if case["kind"] == "run":
            positive.update(mapped)
        elif case["kind"] == "reject":
            rejected.update(mapped)
        boundary.update(edges)
    for f in features:
        fid, status = f["id"], f["status"]
        assert status in {"planned", "partial", "implemented", "deferred"}, f
        assert f["boundary"], f"missing boundary: {fid}"
        if status in {"implemented", "partial"}:
            assert fid in positive and fid in boundary, f"missing positive/boundary coverage: {fid}"
        if status in {"deferred", "partial"}:
            assert fid in rejected, f"missing rejection coverage: {fid}"
    for path in ROOT.glob("docs/*.md"):
        text = path.read_text()
        assert text.count("```") % 2 == 0, f"unbalanced fences: {path}"
        for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
            if "://" in target:
                continue
            file_part = target.partition("#")[0]
            assert not file_part or (path.parent / file_part).exists(), f"broken link: {path}: {target}"
    for path in ROOT.glob("examples/*.sml"):
        name = str(path.relative_to(ROOT))
        assert any(c["path"] == name and c["kind"] == "run" for c in fixtures), f"untested example: {name}"
    print(f"Documentation: {len(features)} features and {len(fixtures)} fixtures checked.")


if __name__ == "__main__":
    main()
