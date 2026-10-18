from pathlib import Path
f=Path('scripts/benchmark-inventory.py');text=f.read_text()
needle='        if source == "nofib" and path in {"gc/fulsom/Main.hs", "real/fulsom/Main.hs",'
insert='''        if source == "nofib" and path in {"gc/cacheprof", "real/cacheprof"}:
            module = parent / "Main.hs"
            if module.is_file():
                heading = module.read_text(errors="replace")[:2500]
                if ("Copyright (C) 1999 Julian Seward (jseward@acm.org)" in heading
                        and "either version 2 of the" in heading
                        and "License, or (at your option) any later version." in heading):
                    authors.add("Julian Seward")
                    item["evidence"].append(path + "/Main.hs:author-and-GPL2-or-later-heading")
            full = parent / "cacheprof.full"
            if full.is_file():
                inputs.add(str(full.relative_to(root)))
                item["evidence"].append(path + "/cacheprof.full:complete-assembly-input-reservoir")
'''
assert text.count(needle)==1;f.write_text(text.replace(needle,insert+needle))
f=Path('tests/benchmarks/test-inventory.py');text=f.read_text()
needle='    def fulsom_notice(self, family, heading):'
insert=(Path(__file__).resolve().parent/'inventory-tests-insert.txt').read_text()
assert text.count(needle)==1
compile(text.replace(needle,insert+needle),str(f),'exec')
f.write_text(text.replace(needle,insert+needle))
