from pathlib import Path
f=Path('scripts/benchmark-inventory.py');text=f.read_text()
needle='        if source == "nofib" and path == "real/hidden" and (parent / "MAIL").is_file():'
insert='''        if source == "nofib" and path in {"gc/fulsom/Main.hs", "real/fulsom/Main.hs",
                                          "gc/fulsom/Bah.hs", "real/fulsom/Bah.hs"}:
            module = parent / "Interval.hs"
            if module.is_file():
                heading = module.read_text(errors="replace")[:2500]
                if ("Copyright 1990,1991,1992,1993 Duncan Sinclair" in heading
                        and "Permissiom to use, copy, modify, and distribute this software for any" in heading
                        and "copyright notice and this permission notice appear in all copies" in heading):
                    authors.add("Duncan Sinclair")
                    item["evidence"].append(str(module.relative_to(root)) + ":author-and-individual-permission")
'''
assert text.count(needle)==1;f.write_text(text.replace(needle,insert+needle))
f=Path('tests/benchmarks/test-inventory.py');text=f.read_text()
needle='    def application_notice(self, directory, executable, file, source):'
insert='''    def fulsom_notice(self, family, heading):
        self.nofib_roots()
        self.file(family + "/fulsom/Makefile", "EXCLUDED_SRCS = Bah.hs\\n")
        self.file(family + "/fulsom/Main.hs", "import Interval\\nmain = print 0\\n")
        self.file(family + "/fulsom/Bah.hs", "main = print 0\\n")
        self.file(family + "/fulsom/Interval.hs", heading + "\\nmodule Interval where\\n")
        return next(row for row in self.build("nofib") if row["path"] == family + "/fulsom/Main.hs")

    def test_fulsom_gc_individual_credit_is_recorded(self):
        heading = (ROOT / "examples/benchmarks/fulsom-lazy/upstream/Interval.hs").read_text().split("module Interval")[0]
        row = self.fulsom_notice("gc", heading)
        self.assertIn("Duncan Sinclair", row["authors"])
        self.assertIn("gc/fulsom/Interval.hs:author-and-individual-permission", row["evidence"])

    def test_fulsom_real_individual_credit_is_recorded(self):
        heading = (ROOT / "examples/benchmarks/fulsom-nofib-lazy/upstream/Interval.hs").read_text().split("module Interval")[0]
        self.assertIn("Duncan Sinclair", self.fulsom_notice("real", heading)["authors"])

    def test_changed_fulsom_author_requires_review(self):
        heading = (ROOT / "examples/benchmarks/fulsom-lazy/upstream/Interval.hs").read_text().split("module Interval")[0]
        self.assertNotIn("Duncan Sinclair", self.fulsom_notice("gc", heading.replace("Duncan Sinclair", "Another author"))["authors"])

    def test_changed_fulsom_permission_requires_review(self):
        heading = (ROOT / "examples/benchmarks/fulsom-lazy/upstream/Interval.hs").read_text().split("module Interval")[0]
        self.assertNotIn("Duncan Sinclair", self.fulsom_notice("gc", heading.replace("notice appear in all copies", "notice has changed"))["authors"])

'''
assert text.count(needle)==1;f.write_text(text.replace(needle,insert+needle))
