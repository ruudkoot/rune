#!/usr/bin/env python3
"""Exercise upstream discovery and classification with small source fixtures."""
import copy
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("benchmark_inventory", ROOT / "scripts/benchmark-inventory.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class InventoryTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def file(self, path, text):
        p = self.root / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        return p

    def nofib_roots(self):
        for name in ("imaginary", "spectral", "real", "gc", "shootout", "parallel", "smp"):
            (self.root / name).mkdir(exist_ok=True)

    def build(self, source):
        return AUDIT.build(source, self.root, {"notices": ""})

    def test_haskell_main_need_not_be_named_Main(self):
        self.nofib_roots()
        self.file("gc/hash/Makefile", "SRCS = hash.hs\n")
        self.file("gc/hash/hash.hs", "import Data.List\nmain = print 42\n")
        rows = self.build("nofib")
        self.assertEqual([(r["path"], r["disposition"]) for r in rows], [("gc/hash", "import")])

    def test_nested_haskell_programs_are_not_an_aggregate_workload(self):
        self.nofib_roots()
        self.file("spectral/group/Makefile", "SUBDIRS = one\n")
        self.file("spectral/group/Helper.hs", "module Helper where\n")
        self.file("spectral/group/one/Makefile", "\n")
        self.file("spectral/group/one/Main.hs", "module Main where\nmain = print 1\n")
        rows = {r["path"]: r for r in self.build("nofib")}
        self.assertEqual(rows["spectral/group"]["disposition"], "exclude")
        self.assertEqual(rows["spectral/group/one"]["disposition"], "import")

    def test_haskell_multiplication_section_is_not_an_ML_comment(self):
        self.nofib_roots()
        self.file("imaginary/numbers/Makefile", "\n")
        self.file("imaginary/numbers/Main.hs", "powers = zipWith (*) [1,2] [3,4]\nmain = print powers\n")
        self.assertEqual(self.build("nofib")[0]["disposition"], "import")

    def test_literate_prose_does_not_hide_bird_style_entrypoint(self):
        self.nofib_roots()
        self.file("real/document/Makefile", "\n")
        self.file("real/document/Main.lhs", 'Prose has an unmatched " quote.\n> main = print 1\n')
        self.assertEqual(self.build("nofib")[0]["disposition"], "import")

    def test_literate_latex_code_blocks_supply_entrypoints(self):
        self.nofib_roots()
        self.file("spectral/document/Makefile", "\n")
        self.file("spectral/document/Main.lhs", 'Prose with a " quote\n\\begin{code}\nmodule Main where\nmain = print 1\n\\end{code}\n')
        self.assertEqual(self.build("nofib")[0]["disposition"], "import")

    def test_multiple_haskell_entrypoints_have_separate_records(self):
        self.nofib_roots()
        self.file("parallel/OLD/kernels/Makefile", "\n")
        self.file("parallel/OLD/kernels/one.hs", "module Main where\nmain = print 1\n")
        self.file("parallel/OLD/kernels/two.lhs", "> module Main where\n> main = print 2\n")
        rows = self.build("nofib")
        self.assertEqual({r["path"] for r in rows}, {"parallel/OLD/kernels/one.hs", "parallel/OLD/kernels/two.lhs"})
        self.assertTrue(all(r["disposition"] == "defer" for r in rows))

    def sandmark_program(self, name, text):
        self.file("benchmarks/kernels/dune", "(executable (name " + name + ") (modes native byte))\n")
        self.file("benchmarks/kernels/" + name + ".ml", text)

    def test_nested_comments_do_not_invent_runtime_dependencies(self):
        self.sandmark_program("trees", '(* Gc.set { (* nested *) } *)\nlet label = "Effect.perform x"\nlet result = 42\n')
        self.assertEqual(self.build("sandmark")[0]["disposition"], "import")

    def test_effect_syntax_is_deferred_even_without_perform(self):
        self.sandmark_program("fib", "effect E : unit\nlet result = try 1 with effect E k -> 2\n")
        self.assertEqual(self.build("sandmark")[0]["disposition"], "defer")

    def test_foreign_library_declaration_is_deferred(self):
        self.sandmark_program("capi", "let result = 42\n")
        self.file("benchmarks/kernels/dune", "(executable (name capi) (libraries ocamlcapi))\n")
        self.file("benchmarks/kernels/capi-dune.inc", "(library (name ocamlcapi) (foreign_stubs (language c) (names binding)))\n")
        self.assertEqual(self.build("sandmark")[0]["disposition"], "defer")

    def test_runplan_names_and_bytecode_variants_share_an_executable(self):
        self.sandmark_program("main", "let result = 42\n")
        self.file("run_config.json", '{"benchmarks":[{"name":"logical-name","executable":"benchmarks/kernels/main.exe"}]}')
        self.file("run_config_byte.json", '{"benchmarks":[{"name":"logical-name.bc","executable":"benchmarks/kernels/main.bc"}]}')
        rows = self.build("sandmark")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["name"], "logical-name")
        self.assertIn("run_config_byte.json", rows[0]["evidence"])

    def test_executable_group_does_not_import_other_main_modules(self):
        self.file("benchmarks/kernels/dune", "(executables (names pure effectful) (modules pure effectful helper))\n")
        self.file("benchmarks/kernels/pure.ml", "let result = Helper.value\n")
        self.file("benchmarks/kernels/helper.ml", "let value = 42\n")
        self.file("benchmarks/kernels/effectful.ml", "effect E : unit\n")
        rows = {r["name"]: r for r in self.build("sandmark")}
        self.assertEqual(rows["pure"]["disposition"], "import")
        self.assertEqual(rows["effectful"]["disposition"], "defer")
        self.assertNotIn("effectful.ml", rows["pure"]["members"])
        self.assertIn("helper.ml", rows["pure"]["members"])

    def test_external_commands_do_not_capture_entire_source_tree(self):
        self.sandmark_program("kernel", "let result = 42\n")
        self.file("run_config.json", '{"benchmarks":[{"name":"external-app","executable":"external-app"}]}')
        rows = {r["path"]: r for r in self.build("sandmark")}
        self.assertEqual(rows["external-app"]["members"], "")
        self.assertEqual(rows["external-app"]["disposition"], "defer")

    def test_strings_are_not_all_treated_as_input_files(self):
        self.sandmark_program("strings", 'let result = "' + "x" * 10000 + '"\n')
        self.assertEqual(self.build("sandmark")[0]["inputs"], "")

    def test_digest_includes_member_identity_and_content(self):
        a = self.file("a.sml", "structure A = struct end\n")
        b = self.file("b.sml", a.read_text())
        self.assertNotEqual(AUDIT.digest(self.root, [a]), AUDIT.digest(self.root, [b]))
        before = AUDIT.digest(self.root, [a])
        a.write_text("structure A = struct val x = 1 end\n")
        self.assertNotEqual(before, AUDIT.digest(self.root, [a]))

    def test_classic_names_are_reserved_before_foreign_variants(self):
        rows = [dict(source="nofib", path="spectral/tak", name="tak", disposition="import"),
                dict(source="mlton", path="benchmark/tests/tak.sml", name="tak", disposition="import")]
        AUDIT.names(rows)
        self.assertEqual([r["rune_name"] for r in rows], ["tak-nofib", "tak"])

    def test_duplicate_inventory_keys_are_rejected(self):
        self.sandmark_program("kernel", "let result = 42\n")
        row = self.build("sandmark")[0]
        with self.assertRaisesRegex(ValueError, "duplicate"):
            AUDIT.validate([row, copy.deepcopy(row)], {"sandmark": {}})

    def test_invalid_disposition_is_rejected(self):
        self.sandmark_program("kernel", "let result = 42\n")
        row = self.build("sandmark")[0]
        row["disposition"] = "pass"
        with self.assertRaisesRegex(ValueError, "bad disposition"):
            AUDIT.validate([row], {"sandmark": {}})

    def test_empty_or_truncated_inventory_cannot_pass(self):
        with self.assertRaisesRegex(ValueError, "incomplete source"):
            AUDIT.validate([], {"sandmark": {"entries": "1"}})

    def test_wrong_table_columns_are_rejected(self):
        path = self.file("inventory.tsv", "source\tname\nsandmark\tkernel\n")
        with self.assertRaisesRegex(ValueError, "columns"):
            AUDIT.table(path)


if __name__ == "__main__":
    unittest.main()
