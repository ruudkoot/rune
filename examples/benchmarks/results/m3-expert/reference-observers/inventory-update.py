from pathlib import Path
root=Path.cwd();script=root/'scripts/benchmark-inventory.py';text=script.read_text();marker='        if source == "nofib" and path == "spectral/knights":'
addition='''        if source == "nofib" and path == "spectral/expert":
            readme = parent / "README"
            if readme.is_file() and "Ian Holyer\\nMarch 1993" in readme.read_text(errors="replace"):
                authors.add("Ian Holyer")
                item["evidence"].append("spectral/expert/README:authorship-and-adaptation-heading")
'''
assert marker in text;script.write_text(text.replace(marker,addition+marker))
f=root/'tests/benchmarks/test-inventory.py';text=f.read_text();pos=text.index('    def test_knights_readme')
addition='''    def test_expert_readme_author_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/expert/Makefile", "\\n")
        self.file("spectral/expert/Main.hs", "main = print 0\\n")
        self.file("spectral/expert/README", "Ian Holyer\\nMarch 1993\\n")
        row = self.build("nofib")[0]
        self.assertIn("Ian Holyer", row["authors"])
        self.assertIn("spectral/expert/README:authorship-and-adaptation-heading", row["evidence"])

    def test_changed_expert_readme_credit_requires_review(self):
        self.nofib_roots()
        self.file("spectral/expert/Makefile", "\\n")
        self.file("spectral/expert/Main.hs", "main = print 0\\n")
        self.file("spectral/expert/README", "Another adaptation\\n")
        self.assertNotIn("Ian Holyer", self.build("nofib")[0]["authors"])

'''
f.write_text(text[:pos]+addition+text[pos:])
