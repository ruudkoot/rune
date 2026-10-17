from pathlib import Path
f=Path('scripts/benchmark-inventory.py');s=f.read_text()
needle='            reviewed_prime_author = (\n'
insert=r'''            if (source == "nofib" and path == "real/mkhprog"
                    and r"\author{N D North\\" in header.splitlines()
                    and "% Crown Copyright 1992" in header.splitlines()):
                authors.add("N. D. North")
                item["evidence"].append(str(p.relative_to(root)) + ":author-and-crown-heading")
'''
assert needle in s;s=s.replace(needle,insert+needle);f.write_text(s)
f=Path('tests/benchmarks/test-inventory.py');s=f.read_text();pos=s.index('    def test_pic_author_heading_is_recorded')
s=s[:pos]+r'''    def test_mkhprog_literate_author_heading_is_recorded(self):
        self.nofib_roots()
        self.file("real/mkhprog/Makefile", "\n")
        self.file("real/mkhprog/Main.lhs",
                  "% Crown Copyright 1992\n\\author{N D North\\\\\n\n> main = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "N. D. North")
        self.assertIn("real/mkhprog/Main.lhs:author-and-crown-heading", row["evidence"])

    def test_changed_mkhprog_author_heading_requires_review(self):
        self.nofib_roots()
        self.file("real/mkhprog/Makefile", "\n")
        self.file("real/mkhprog/Main.lhs",
                  "% Crown Copyright 1992\n\\author{Another author\\\\\n\n> main = print 0\n")
        self.assertNotIn("N. D. North", self.build("nofib")[0]["authors"])

'''+s[pos:];f.write_text(s)
