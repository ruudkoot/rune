from pathlib import Path
import subprocess
root=Path.cwd();p=Path(__file__).resolve().parent;file=root/'scripts/benchmark-inventory.py';t=file.read_text()
old='''        files = sorted(set(files))
        text = "\\n".join'''
new='''        if source == "nofib" and path == "spectral/simple":
            # Reviewed historical Fortran comparator, outside SRCS=Main.hs.
            fortran = root / path / "simple.f"
            if fortran.is_file():
                files.append(fortran)
        files = sorted(set(files))
        text = "\\n".join'''
assert old in t;t=t.replace(old,new)
point='''        if source == "nofib" and path == "real/lift":
'''
block='''        if source == "nofib" and path == "spectral/simple":
            main = parent / "Main.hs"
            if main.is_file():
                heading = main.read_text(errors="replace")
                if ("Original Author: Kattamuri Ekanadham <EKNATH@ibm.com>" in heading
                        and "translated to haskell by an id to ph translator" in heading):
                    item["evidence"].append("spectral/simple/Main.hs:Id-author-and-anonymous-translator-role")
            c_source = parent / "simple.c"
            if c_source.is_file():
                heading = c_source.read_text(errors="replace")[:1000]
                if ("Andy Shaw and Kofi Fynn." in heading
                        and "Wed Feb  2 14:59:18 EST 1994" in heading):
                    authors.update({"Andy Shaw (C comparator)", "Kofi Fynn (C comparator)"})
                    item["evidence"].append("spectral/simple/simple.c:C-comparator-authors")
            mail = parent / "MAIL"
            if mail.is_file():
                context.append(mail)
                correspondence = mail.read_text(errors="replace")
                if ("RPaul Johnson told me" in correspondence
                        and "This version may be useful because it is in 1.2 Haskell" in correspondence):
                    authors.add("RPaul Johnson (Haskell/pH correspondence)")
                    item["evidence"].append("spectral/simple/MAIL:Haskell-port-correspondence")
                if "Here is the fortran in its original form from Olaf Lubeck:" in correspondence:
                    authors.add("Olaf Lubeck (Fortran supplier, not asserted sole author)")
                    item["evidence"].append("spectral/simple/MAIL:Fortran-supplier")
            makefile = parent / "Makefile"
            if makefile.is_file() and "SRCS = Main.hs" in makefile.read_text():
                item["evidence"].append("spectral/simple/Makefile:excludes-C-and-Fortran-comparators")
'''
assert point in t;t=t.replace(point,block+point)
file.write_text(t)
tests=root/'tests/benchmarks/test-inventory.py';t=tests.read_text();point='''    def fem_header(self, heading, data=False):
'''
block='''    def simple_sources(self, c_header="Andy Shaw and Kofi Fynn.\\\\nWed Feb  2 14:59:18 EST 1994"):
        self.nofib_roots()
        self.file("spectral/simple/Makefile", "SRCS = Main.hs\\\\n")
        self.file("spectral/simple/Main.hs", "main = print 0\\\\n")
        self.file("spectral/simple/simple.c", "/* " + c_header + " */\\\\n")
        self.file("spectral/simple/simple.f", "      PARAMETER(II=101,JJ=100)\\\\n")
        return self.root / "spectral/simple"

    def test_simple_records_both_C_comparator_authors(self):
        self.simple_sources()
        row = self.build("nofib")[0]
        self.assertIn("Andy Shaw (C comparator)", row["authors"])
        self.assertIn("Kofi Fynn (C comparator)", row["authors"])

    def test_simple_changed_C_header_requires_review(self):
        self.simple_sources("Other authors")
        self.assertNotIn("Kofi Fynn (C comparator)", self.build("nofib")[0]["authors"])

    def test_simple_preserves_Fortran_comparator_and_build_scope(self):
        self.simple_sources()
        row = self.build("nofib")[0]
        self.assertIn("spectral/simple/simple.f", row["members"])
        self.assertIn("spectral/simple/Makefile:excludes-C-and-Fortran-comparators", row["evidence"])

    def test_simple_Fortran_identity_changes_with_source(self):
        directory = self.simple_sources()
        before = self.build("nofib")[0]["sha256"]
        (directory / "simple.f").write_text("      PARAMETER(II=102,JJ=100)\\\\n")
        self.assertNotEqual(before, self.build("nofib")[0]["sha256"])

    def test_simple_records_correspondence_roles(self):
        self.simple_sources()
        self.file("spectral/simple/MAIL", "RPaul Johnson told me\\\\n"
                  "This version may be useful because it is in 1.2 Haskell\\\\n"
                  "Here is the fortran in its original form from Olaf Lubeck:\\\\n")
        row = self.build("nofib")[0]
        self.assertIn("RPaul Johnson (Haskell/pH correspondence)", row["authors"])
        self.assertIn("Olaf Lubeck (Fortran supplier, not asserted sole author)", row["authors"])

    def test_simple_changed_correspondence_does_not_invent_roles(self):
        self.simple_sources()
        self.file("spectral/simple/MAIL", "A different correspondence.\\\\n")
        self.assertNotIn("Olaf Lubeck", self.build("nofib")[0]["authors"])

'''
block=block.replace('\\\\n','\\n')
assert point in t;tests.write_text(t.replace(point,block+point))
with(p/'inventory-tests.log').open('w')as log:subprocess.run(['python3',str(tests)],stdout=log,stderr=subprocess.STDOUT,check=True)
args=['python3','scripts/benchmark-inventory.py']
for name,path in [('mlton','pinned/mlton'),('smlnj','pinned/smlnj'),('mlkit','pinned/mlkit'),('nofib','pinned/nofib'),('sandmark','upstreams/sandmark')]:args+=['--source',name+'='+str(root/'tests/out/benchmarks'/path)]
for mode in ['write','check']:
 with(p/('inventory-'+mode+'.log')).open('w')as log:subprocess.run(args+['--'+mode],stdout=log,stderr=subprocess.STDOUT,check=True)
