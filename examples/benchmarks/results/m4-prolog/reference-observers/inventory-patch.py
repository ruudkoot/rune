from pathlib import Path
f=Path('scripts/benchmark-inventory.py');s=f.read_text()
needle='            reviewed_prime_author = (\n'
insert='''            if (source == "nofib" and path == "real/prolog"
                    and re.search(r"(?m)^-- Mark P\\. Jones November 1990$", header)):
                authors.add("Mark P. Jones")
                item["evidence"].append(str(p.relative_to(root)) + ":author-heading")
'''
assert needle in s;s=s.replace(needle,insert+needle);f.write_text(s)
f=Path('tests/benchmarks/test-inventory.py');s=f.read_text();pos=s.index('    def test_pic_author_heading_is_recorded')
s=s[:pos]+r'''    def test_prolog_author_heading_is_recorded(self):
        self.nofib_roots()
        self.file("real/prolog/Makefile", "\n")
        self.file("real/prolog/Main.hs",
                  "-- Mark P. Jones November 1990\nmain = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Mark P. Jones")
        self.assertIn("real/prolog/Main.hs:author-heading", row["evidence"])

    def test_changed_prolog_author_heading_requires_review(self):
        self.nofib_roots()
        self.file("real/prolog/Makefile", "\n")
        self.file("real/prolog/Main.hs",
                  "-- Another author November 1990\nmain = print 0\n")
        self.assertNotIn("Mark P. Jones", self.build("nofib")[0]["authors"])

'''+s[pos:];f.write_text(s)
