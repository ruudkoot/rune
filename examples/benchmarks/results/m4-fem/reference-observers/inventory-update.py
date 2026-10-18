from pathlib import Path
f=Path('scripts/benchmark-inventory.py');s=f.read_text()
needle='        if source == "nofib" and path in {"gc/cacheprof", "real/cacheprof"}:'
insert='''        if source == "nofib" and path == "real/fem":
            readme = parent / "README"
            if readme.is_file():
                heading = readme.read_text(errors="replace")
                if ("Dr. Junxian Liu" in heading and "Department of Computing" in heading
                        and "Imperial College, London SW7 2BZ" in heading):
                    authors.add("Junxian Liu")
                    item["evidence"].append("real/fem/README:author-and-model-description")
            for name in ("data.0", "data.1", "data.2", "data.3"):
                data = parent / name
                if data.is_file():
                    inputs.add(str(data.relative_to(root)))
                    item["evidence"].append("real/fem/" + name + ":reviewed-model-input")
'''
assert s.count(needle)==1;f.write_text(s.replace(needle,insert+needle))
f=Path('tests/benchmarks/test-inventory.py');s=f.read_text()
needle='    def cacheprof_notice(self, family, heading, full=False):'
insert=(Path(__file__).resolve().parent/'inventory-tests-insert.txt').read_text()
assert s.count(needle)==1;compile(s.replace(needle,insert+needle),str(f),'exec');f.write_text(s.replace(needle,insert+needle))
