from pathlib import Path
f=Path('scripts/benchmark-inventory.py');s=f.read_text().replace('source == "nofib" and path == "real/pic"','source == "nofib" and path in {"real/pic", "real/gamteb"}');f.write_text(s)
f=Path('tests/benchmarks/test-inventory.py');s=f.read_text();pos=s.index('    def test_pic_author_heading_is_recorded')
s=s[:pos]+r'''    def test_gamteb_author_heading_is_recorded(self):
        self.nofib_roots()
        self.file("real/gamteb/Makefile", "\n")
        self.file("real/gamteb/Main.hs",
                  "--      Patricia Fasel\n--      Los Alamos National Laboratory\nmain = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Patricia Fasel")
        self.assertIn("real/gamteb/Main.hs:author-heading", row["evidence"])

    def test_changed_gamteb_author_heading_requires_review(self):
        self.nofib_roots()
        self.file("real/gamteb/Makefile", "\n")
        self.file("real/gamteb/Main.hs",
                  "--      Another author\n--      Another laboratory\nmain = print 0\n")
        self.assertNotIn("Patricia Fasel", self.build("nofib")[0]["authors"])

'''+s[pos:];f.write_text(s)
