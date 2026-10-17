from pathlib import Path
import csv,hashlib
f=Path('scripts/benchmark-inventory.py');s=f.read_text();needle='        item["evidence"].extend(str(p.relative_to(root)) for p in context)\n'
insert='''        if source == "nofib" and path in {"gc/linear", "real/linear"}:
            main = parent / "Main.lhs"
            if main.is_file():
                text = main.read_text(errors="replace")
                if ("Written by Brian D. Moe (Summer 1990)" in text and
                        "Modified by Kamini Shenoi (Summer 1991)" in text and
                        "Converted to Haskell by Ian R McLelland and Cordelia V Hall (Nov 1992)" in text):
                    authors.update(("Brian D. Moe", "Kamini Shenoi", "Ian R. McLelland", "Cordelia V. Hall"))
                    item["evidence"].append(path + "/Main.lhs:authorship-and-conversion-roles")
            data = parent / "Input.lhs"
            if data.is_file():
                text = data.read_text(errors="replace")
                if "Roger L. Wainwright  6-8-90" in text:
                    authors.add("Roger L. Wainwright")
                    item["evidence"].append(path + "/Input.lhs:data-representation-credit")
                if "written by Dan Vasicek and copied from his directory 6/22/90" in text:
                    authors.add("Dan Vasicek")
                    item["evidence"].append(path + "/Input.lhs:input-reader-credit")
'''
assert needle in s;s=s.replace(needle,insert+needle);f.write_text(s)
f=Path('tests/benchmarks/test-inventory.py');s=f.read_text();pos=s.index('    def test_sphere_source_port_author_is_recorded')
s=s[:pos]+'''    def test_linear_authorship_and_conversion_roles_are_recorded(self):
        self.nofib_roots()
        self.file("real/linear/Makefile", "\\n")
        self.file("real/linear/Main.lhs", "Written by Brian D. Moe (Summer 1990)\\nModified by Kamini Shenoi (Summer 1991)\\nConverted to Haskell by Ian R McLelland and Cordelia V Hall (Nov 1992)\\n\\\\begin{code}\\nmain = print 0\\n\\\\end{code}\\n")
        row = self.build("nofib")[0]
        for name in ["Brian D. Moe", "Kamini Shenoi", "Ian R. McLelland", "Cordelia V. Hall"]:
            self.assertIn(name, row["authors"])
        self.assertIn("real/linear/Main.lhs:authorship-and-conversion-roles", row["evidence"])

    def test_changed_linear_conversion_header_requires_review(self):
        self.nofib_roots()
        self.file("real/linear/Makefile", "\\n")
        self.file("real/linear/Main.lhs", "Another conversion\\n\\\\begin{code}\\nmain = print 0\\n\\\\end{code}\\n")
        self.assertNotIn("Cordelia V. Hall", self.build("nofib")[0]["authors"])

    def test_linear_input_roles_are_recorded(self):
        self.nofib_roots()
        self.file("gc/linear/Makefile", "\\n")
        self.file("gc/linear/Main.lhs", "\\\\begin{code}\\nmain = print 0\\n\\\\end{code}\\n")
        self.file("gc/linear/Input.lhs", "Roger L. Wainwright  6-8-90\\nwritten by Dan Vasicek and copied from his directory 6/22/90\\n")
        row = self.build("nofib")[0]
        self.assertIn("Roger L. Wainwright", row["authors"])
        self.assertIn("Dan Vasicek", row["authors"])

    def test_changed_linear_input_credit_requires_review(self):
        self.nofib_roots()
        self.file("gc/linear/Makefile", "\\n")
        self.file("gc/linear/Main.lhs", "\\\\begin{code}\\nmain = print 0\\n\\\\end{code}\\n")
        self.file("gc/linear/Input.lhs", "Another input author\\n")
        self.assertNotIn("Dan Vasicek", self.build("nofib")[0]["authors"])

'''+s[pos:];f.write_text(s)
suite=Path('examples/benchmarks');f=suite/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;rows=list(r)
for category in ['gc','real']:
 path=category+'/linear/Input.lhs';file=Path('tests/out/benchmarks/pinned/nofib')/path
 rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798',category+'/linear',path,category+'-linear-gcomp-data','Haskell','documented inactive reservoir-data mode','Roger L. Wainwright;Dan Vasicek',hashlib.sha256(file.read_bytes()).hexdigest(),'defer','reservoir readers return literal abc and referenced Data/gcomp.mat*.one/.twoa/.twob/.twoc/.three/.four/.soln/.well fixtures are absent; reconsider with deterministically versioned/licensed datasets and a reviewed reader; default executable uses generated hard_data','individual source credit headers retained; no separate dataset notice or dataset files supplied'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
