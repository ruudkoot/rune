from pathlib import Path
import subprocess,os
root=Path.cwd();p=Path(__file__).resolve().parent
f=root/'scripts/benchmark-inventory.py';t=f.read_text();needle='        if source == "nofib" and path == "real/fem":'
new=r'''        if source == "nofib" and path == "real/lift":
            paper = parent / "LambdaLift.lhs"
            if paper.is_file():
                heading = paper.read_text(errors="replace")
                if (r"\title{A modular fully-lazy lambda lifter in \Haskell{}}" in heading
                        and "Simon L Peyton Jones" in heading
                        and "David Lester" in heading
                        and r"\begin{abstract}" in heading):
                    authors.update({"Simon L. Peyton Jones", "David Lester"})
                    item["evidence"].append("real/lift/LambdaLift.lhs:executable-paper-title-and-author-block")
'''
assert needle in t;f.write_text(t.replace(needle,new+needle))
f=root/'tests/benchmarks/test-inventory.py';t=f.read_text();pos=t.index('    def fulsom_notice(')
new=r'''    def lift_paper(self, heading):
        self.nofib_roots()
        self.file("real/lift/Makefile", "\n")
        self.file("real/lift/Main.lhs", "> module Main where\n> import LambdaLift\n> main = print 0\n")
        self.file("real/lift/LambdaLift.lhs", heading + "\n> module LambdaLift where\n")
        return next(row for row in self.build("nofib") if row["path"] == "real/lift")

    def lift_heading(self):
        return (ROOT / "examples/benchmarks/lift-lazy/upstream/LambdaLift.lhs").read_text().split(r"\end{abstract}")[0]

    def test_lift_executable_paper_authors_are_recorded(self):
        row = self.lift_paper(self.lift_heading())
        self.assertIn("Simon L. Peyton Jones", row["authors"])
        self.assertIn("David Lester", row["authors"])
        self.assertIn("real/lift/LambdaLift.lhs:executable-paper-title-and-author-block", row["evidence"])

    def test_changed_lift_title_requires_review(self):
        row = self.lift_paper(self.lift_heading().replace("A modular fully-lazy lambda lifter", "Another lifter"))
        self.assertNotIn("Simon L. Peyton Jones", row["authors"])

    def test_changed_lift_author_requires_review(self):
        row = self.lift_paper(self.lift_heading().replace("David Lester", "Another author"))
        self.assertNotIn("David Lester", row["authors"])

    def test_incomplete_lift_paper_heading_requires_review(self):
        row = self.lift_paper(self.lift_heading().replace(r"\begin{abstract}", ""))
        self.assertNotIn("Simon L. Peyton Jones", row["authors"])

'''
f.write_text(t[:pos]+new+t[pos:])
commands=[
 ['python3','tests/benchmarks/test-inventory.py'],
 ['python3','scripts/benchmark-inventory.py']]
args=[]
for name,path in [('mlton','pinned/mlton'),('smlnj','pinned/smlnj'),('mlkit','pinned/mlkit'),('nofib','pinned/nofib'),('sandmark','upstreams/sandmark')]:
 args+=['--source',name+'='+str(root/'tests/out/benchmarks'/path)]
with(p/'inventory-tests.log').open('w')as log:subprocess.run(commands[0],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'inventory-write.log').open('w')as log:subprocess.run(commands[1]+args+['--write'],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'inventory-check.log').open('w')as log:subprocess.run(commands[1]+args+['--check'],stdout=log,stderr=subprocess.STDOUT,check=True)
