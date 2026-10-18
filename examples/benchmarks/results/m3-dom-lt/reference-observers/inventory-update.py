from pathlib import Path
import hashlib,csv
root=Path.cwd();script=root/'scripts/benchmark-inventory.py';text=script.read_text()
original=root/'tests/out/benchmarks/pinned/nofib/spectral/dom-lt/Dom.hs';digest=hashlib.sha256(original.read_bytes()).hexdigest()
marker='        if source == "nofib" and path == "spectral/multiplier":'
addition='''        if source == "nofib" and path == "spectral/dom-lt":
            module = parent / "Dom.hs"
            if module.is_file():
                heading = module.read_text(errors="replace")
                if "Copyright   :  (c) Matt Morrow 2009" in heading and "License     :  BSD3" in heading:
                    authors.add("Matt Morrow")
                    item["evidence"].append("spectral/dom-lt/Dom.hs:algorithm-author-and-BSD3-heading")
'''
assert marker in text;text=text.replace(marker,addition+marker)
reasonMarker='    return milestone, disposition, reason'
print('reason marker occurrences',text.count(reasonMarker))
assert text.count(reasonMarker)==1
reason='''    if source == "nofib" and path == "spectral/dom-lt" and disposition == "import":
        module = root / "spectral/dom-lt/Dom.hs"
        if module.is_file() and hashlib.sha256(module.read_bytes()).hexdigest() == "DIGEST":
            reason = ("portable with reviewed semidominator-minimum repair; pinned source reuses "
                      "a stale threshold and returns incorrect parents on supplied graphs; preserve "
                      "original checksums while validating all corrected parents against independent results")
'''.replace('DIGEST',digest)
text=text.replace(reasonMarker,reason+reasonMarker);script.write_text(text)
tests=root/'tests/benchmarks/test-inventory.py';text=tests.read_text();pos=text.index('    def test_multiplier_author')
addition='''    def test_dominator_algorithm_author_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/dom-lt/Makefile", "\\n")
        self.file("spectral/dom-lt/Main.hs", "module Main where\\nmain = print 0\\n")
        self.file("spectral/dom-lt/Dom.hs", "Copyright   :  (c) Matt Morrow 2009\\nLicense     :  BSD3\\nmodule Dom where\\n")
        row = self.build("nofib")[0]
        self.assertIn("Matt Morrow", row["authors"])
        self.assertIn("spectral/dom-lt/Dom.hs:algorithm-author-and-BSD3-heading", row["evidence"])

    def test_changed_dominator_author_requires_review(self):
        self.nofib_roots()
        self.file("spectral/dom-lt/Makefile", "\\n")
        self.file("spectral/dom-lt/Main.hs", "main = print 0\\n")
        self.file("spectral/dom-lt/Dom.hs", "Another author\\nmodule Dom where\\n")
        self.assertNotIn("Matt Morrow", self.build("nofib")[0]["authors"])

    def test_pinned_dominator_threshold_defect_requires_recorded_repair(self):
        self.nofib_roots()
        self.file("spectral/dom-lt/Makefile", "\\n")
        self.file("spectral/dom-lt/Main.hs", "main = print 0\\n")
        self.file("spectral/dom-lt/Dom.hs", (ROOT / "examples/benchmarks/dom-lt/upstream/Dom.hs").read_text())
        self.assertIn("semidominator-minimum repair", self.build("nofib")[0]["reason"])

    def test_changed_dominator_kernel_does_not_inherit_repair_claim(self):
        self.nofib_roots()
        self.file("spectral/dom-lt/Makefile", "\\n")
        self.file("spectral/dom-lt/Main.hs", "main = print 0\\n")
        self.file("spectral/dom-lt/Dom.hs", "module Dom where\\nvalue = 0\\n")
        self.assertNotIn("semidominator-minimum repair", self.build("nofib")[0]["reason"])

'''
tests.write_text(text[:pos]+addition+text[pos:])
f=root/'examples/benchmarks/source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;rows=list(r)
rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','spectral/dom-lt','spectral/dom-lt/Dom.hs','dom-lt-unrepaired','Haskell','unrepaired semidominator threshold','Matt Morrow',digest,'defer','unmodified kernel returns incorrect parents on 15 of 17 supplied graphs and a three-node counterexample; list-length checksums conceal the error; only the reviewed minimum-threshold repair is runnable; reconsider unrepaired baseline only after an upstream revision fixes the defect and full parent results pass independent checks','Copyright Matt Morrow 2009; BSD3 declaration retained'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
