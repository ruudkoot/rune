from pathlib import Path
f=Path('scripts/benchmark-inventory.py');s=f.read_text();needle='        item["evidence"].extend(str(p.relative_to(root)) for p in context)\n'
insert='''        if source == "nofib" and path == "spectral/para" and (parent / "Main.lhs").is_file():
            header = (parent / "Main.lhs").read_text(errors="replace")
            if "% \\tA program by Oege de Moor and Jeremy Gibbons" in header:
                authors.update(("Oege de Moor", "Jeremy Gibbons"))
                item["evidence"].append("spectral/para/Main.lhs:author-heading")
            data = parent / "runtime_files/input-data"
            if data.is_file():
                text = data.read_text(errors="replace")
                if ("Far From The Madding Crowd, by Thomas Hardy" in text and
                        "*END*THE SMALL PRINT! FOR PUBLIC DOMAIN ETEXTS*Ver.04.29.93*END*" in text):
                    notices.add("spectral/para/runtime_files/input-data:Project-Gutenberg-1993-notice")
                    item["evidence"].append("spectral/para/runtime_files/input-data:individual-dataset-notice")
'''
assert needle in s;s=s.replace(needle,insert+needle);f.write_text(s)
f=Path('tests/benchmarks/test-inventory.py');s=f.read_text();pos=s.index('    def test_lambda_source_author_header_is_recorded')
s=s[:pos]+'''    def test_para_article_authors_are_recorded(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\\n")
        self.file("spectral/para/Main.lhs", "% \\tA program by Oege de Moor and Jeremy Gibbons\\n> module Main where\\n> main = print 0\\n")
        row = self.build("nofib")[0]
        self.assertIn("Oege de Moor", row["authors"])
        self.assertIn("Jeremy Gibbons", row["authors"])

    def test_changed_para_article_author_requires_review(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\\n")
        self.file("spectral/para/Main.lhs", "% A program by Another author\\n> module Main where\\n> main = print 0\\n")
        self.assertNotIn("Oege de Moor", self.build("nofib")[0]["authors"])

    def test_para_individual_data_notice_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\\n")
        self.file("spectral/para/Main.lhs", "> module Main where\\n> main = print 0\\n")
        self.file("spectral/para/runtime_files/input-data", "Far From The Madding Crowd, by Thomas Hardy\\n*END*THE SMALL PRINT! FOR PUBLIC DOMAIN ETEXTS*Ver.04.29.93*END*\\n")
        self.assertIn("spectral/para/runtime_files/input-data:Project-Gutenberg-1993-notice", self.build("nofib")[0]["notices"])

    def test_incomplete_para_notice_requires_review(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\\n")
        self.file("spectral/para/Main.lhs", "> module Main where\\n> main = print 0\\n")
        self.file("spectral/para/runtime_files/input-data", "Far From The Madding Crowd, by Thomas Hardy\\n")
        self.assertNotIn("spectral/para/runtime_files/input-data:Project-Gutenberg-1993-notice", self.build("nofib")[0]["notices"])

'''+s[pos:];f.write_text(s)
