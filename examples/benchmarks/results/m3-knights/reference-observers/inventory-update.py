from pathlib import Path
import csv,hashlib
root=Path.cwd();script=root/'scripts/benchmark-inventory.py';text=script.read_text();marker='        if source == "nofib" and path in {"gc/linear", "real/linear"}:'
addition='''        if source == "nofib" and path == "spectral/knights":
            readme = parent / "README"
            if readme.is_file() and "The Knights Tour in Haskell\\n---------------------------\\n\\nJonathan Hill\\n" in readme.read_text(errors="replace"):
                authors.add("Jonathan Hill")
                item["evidence"].append("spectral/knights/README:authorship-heading")
'''
assert marker in text;text=text.replace(marker,addition+marker);script.write_text(text)
tests=root/'tests/benchmarks/test-inventory.py';text=tests.read_text();pos=text.index('    def test_linear_authorship')
addition='''    def test_knights_readme_author_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/knights/Makefile", "\\n")
        self.file("spectral/knights/Main.hs", "main = print 0\\n")
        self.file("spectral/knights/README", "The Knights Tour in Haskell\\n---------------------------\\n\\nJonathan Hill\\n")
        row = self.build("nofib")[0]
        self.assertIn("Jonathan Hill", row["authors"])
        self.assertIn("spectral/knights/README:authorship-heading", row["evidence"])

    def test_changed_knights_readme_heading_requires_review(self):
        self.nofib_roots()
        self.file("spectral/knights/Makefile", "\\n")
        self.file("spectral/knights/Main.hs", "main = print 0\\n")
        self.file("spectral/knights/README", "Another tour author\\n")
        self.assertNotIn("Jonathan Hill", self.build("nofib")[0]["authors"])

'''
tests.write_text(text[:pos]+addition+text[pos:])
f=root/'examples/benchmarks/source-variants.tsv'
with f.open()as stream:reader=csv.DictReader(stream,delimiter='\t');fields=reader.fieldnames;rows=list(reader)
path='spectral/knights/ChessSetArray.lhs';original=root/'tests/out/benchmarks/pinned/nofib'/path
assert not any(r['path']==path for r in rows)
rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','spectral/knights',path,'knights-array','Haskell','inactive persistent-array board representation','Jonathan Hill (program README)',hashlib.sha256(original.read_bytes()).hexdigest(),'import','ported as knights-array-lazy/strict with immutable boxed arrays; original renderer logTen 1 base loops at zero; one-line formatting repair logTen 0 is reviewed against an adapted original, with bounded failing-original evidence; retain distinct layout, deletion metadata and indexTile quirk','no separate individual redistribution grant stated; retain original module, README and bibliography'])))
with f.open('w')as stream:writer=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');writer.writeheader();writer.writerows(rows)
