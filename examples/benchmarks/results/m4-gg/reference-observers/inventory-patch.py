from pathlib import Path
f=Path('scripts/benchmark-inventory.py');s=f.read_text()
needle='        item["evidence"].extend(str(p.relative_to(root)) for p in context)\n'
insert='''        if source == "nofib" and path == "real/gg" and (parent / "gg.1").is_file():
            manual = (parent / "gg.1").read_text(errors="replace")
            if ".SH AUTHOR\\nIain Checkland, University of York." in manual:
                authors.add("Iain Checkland")
                item["evidence"].append("real/gg/gg.1:author-section")
'''
assert needle in s;s=s.replace(needle,insert+needle);f.write_text(s)
f=Path('tests/benchmarks/test-inventory.py');s=f.read_text();pos=s.index('    def test_pic_author_heading_is_recorded')
s=s[:pos]+r'''    def test_gg_manual_author_section_is_recorded(self):
        self.nofib_roots()
        self.file("real/gg/Makefile", "\n")
        self.file("real/gg/Main.hs", "main = print 0\n")
        self.file("real/gg/gg.1", ".SH AUTHOR\nIain Checkland, University of York.\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Iain Checkland")
        self.assertIn("real/gg/gg.1:author-section", row["evidence"])

    def test_changed_gg_manual_author_requires_review(self):
        self.nofib_roots()
        self.file("real/gg/Makefile", "\n")
        self.file("real/gg/Main.hs", "main = print 0\n")
        self.file("real/gg/gg.1", ".SH AUTHOR\nAnother author.\n")
        self.assertNotIn("Iain Checkland", self.build("nofib")[0]["authors"])

'''+s[pos:];f.write_text(s)
