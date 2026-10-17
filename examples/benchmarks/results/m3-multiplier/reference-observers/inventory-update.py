from pathlib import Path
root=Path.cwd();script=root/'scripts/benchmark-inventory.py';text=script.read_text();marker='        if source == "nofib" and path == "spectral/expert":'
addition='''        if source == "nofib" and path == "spectral/multiplier":
            main = parent / "Main.hs"
            if main.is_file():
                heading = main.read_text(errors="replace")
                if ("-- John O'Donnell, University of Glasgow. jtod@dcs.glasgow.ac.uk" in heading
                        and "-- Copyright (c) 1992 by John T. O'Donnell" in heading):
                    authors.add("John T. O'Donnell")
                    item["evidence"].append("spectral/multiplier/Main.hs:author-and-copyright-heading")
        if source == "sandmark" and path == "benchmarks/benchmarksgame/regexredux2.exe":
            main = parent / "regexredux2.ml"
            if main.is_file():
                heading = main.read_text(errors="replace")
                if ("regex-dna program contributed by Christophe TROESTLER" in heading
                        and "updated by Roman Kashitsyn: use Bytes instead of String" in heading):
                    authors.add("Roman Kashitsyn")
                    item["evidence"].append("benchmarks/benchmarksgame/regexredux2.ml:Bytes-adaptation-credit")
'''
assert marker in text;script.write_text(text.replace(marker,addition+marker))
f=root/'tests/benchmarks/test-inventory.py';text=f.read_text();pos=text.index('    def test_expert_readme')
addition='''    def test_multiplier_author_and_copyright_are_recorded(self):
        self.nofib_roots()
        self.file("spectral/multiplier/Makefile", "\\n")
        self.file("spectral/multiplier/Main.hs", "-- John O'Donnell, University of Glasgow. jtod@dcs.glasgow.ac.uk\\n-- Copyright (c) 1992 by John T. O'Donnell\\nmain = print 0\\n")
        row = self.build("nofib")[0]
        self.assertIn("John T. O'Donnell", row["authors"])
        self.assertIn("spectral/multiplier/Main.hs:author-and-copyright-heading", row["evidence"])

    def test_changed_multiplier_author_requires_review(self):
        self.nofib_roots()
        self.file("spectral/multiplier/Makefile", "\\n")
        self.file("spectral/multiplier/Main.hs", "-- Another multiplier author\\nmain = print 0\\n")
        self.assertNotIn("John T. O'Donnell", self.build("nofib")[0]["authors"])

    def test_regexredux_bytes_adaptation_credit_is_recorded(self):
        self.file("benchmarks/benchmarksgame/dune", "(executable (name regexredux2))\\n")
        self.file("benchmarks/benchmarksgame/regexredux2.ml", "(* regex-dna program contributed by Christophe TROESTLER\\nupdated by Roman Kashitsyn: use Bytes instead of String *)\\nlet () = ()\\n")
        row = self.build("sandmark")[0]
        self.assertIn("Roman Kashitsyn", row["authors"])
        self.assertIn("benchmarks/benchmarksgame/regexredux2.ml:Bytes-adaptation-credit", row["evidence"])

    def test_changed_regexredux_adaptation_credit_requires_review(self):
        self.file("benchmarks/benchmarksgame/dune", "(executable (name regexredux2))\\n")
        self.file("benchmarks/benchmarksgame/regexredux2.ml", "(* Another regex adaptation *)\\nlet () = ()\\n")
        self.assertNotIn("Roman Kashitsyn", self.build("sandmark")[0]["authors"])

'''
f.write_text(text[:pos]+addition+text[pos:])
