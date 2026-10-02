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

    def test_region_reset_variants_require_their_storage_model(self):
        (self.root / "test_dev").mkdir()
        self.file("test/kitlife35u.sml", "fun run () = resetRegions ()\n")
        row = self.build("mlkit")[0]
        self.assertEqual(row["disposition"], "defer")
        self.assertIn("region-reset", row["reason"])

    def test_named_development_regressions_are_not_misidentified_as_kernels(self):
        (self.root / "test").mkdir()
        for name in ("life", "rev", "listsort"):
            self.file("test_dev/" + name + ".sml", "val example = [0,1]\n")
        rows = self.build("mlkit")
        self.assertTrue(all(r["disposition"] == "exclude" for r in rows))
        self.assertTrue(all(r["reason"] for r in rows))

    def test_region_reset_in_prose_is_not_a_runtime_dependency(self):
        (self.root / "test_dev").mkdir()
        self.file("test/kitfib35.sml", "(* resetRegions () was removed *)\nfun fib n = n\n")
        self.assertEqual(self.build("mlkit")[0]["disposition"], "import")

    def test_upstream_noop_region_controls_are_portable_variants(self):
        (self.root / "test_dev").mkdir()
        self.file("test/kitlife35u_smlnj.sml", "fun resetRegions _ = ()\nfun run x = resetRegions x\n")
        row = self.build("mlkit")[0]
        self.assertEqual(row["disposition"], "import")
        self.assertIn("no-ops", row["reason"])

    def test_one_noop_does_not_hide_another_missing_region_control(self):
        (self.root / "test_dev").mkdir()
        self.file("test/kitlife35u_smlnj.sml", "fun resetRegions _ = ()\nfun run x = (resetRegions x; forceResetting x)\n")
        self.assertEqual(self.build("mlkit")[0]["disposition"], "defer")

    def test_entrypoint_only_alias_is_a_duplicate(self):
        (self.root / "test_dev").mkdir()
        self.file("test/tak.sml", "fun tak n = n\nval _ = Main.doit()\n")
        self.file("test/tak_smlnj.sml", "fun tak n = n\nfun doit() = Main.doit()\n")
        rows = {r["path"]: r for r in self.build("mlkit")}
        self.assertEqual(rows["test/tak_smlnj.sml"]["disposition"], "duplicate")

    def test_changed_alias_kernel_or_string_is_preserved(self):
        (self.root / "test_dev").mkdir()
        self.file("test/checksum.sml", 'val data = "original"\nval _ = Main.doit()\n')
        self.file("test/checksum_smlnj.sml", 'val data = "changed"\nfun doit() = Main.doit()\n')
        rows = {r["path"]: r for r in self.build("mlkit")}
        self.assertEqual(rows["test/checksum_smlnj.sml"]["disposition"], "import")

    def test_noop_life_host_launchers_share_one_implementation(self):
        (self.root / "test_dev").mkdir()
        body = 'local\nfun resetRegions _ = ()\nfun testit _ = show(iter 250)\n'
        self.file("test/kitlife35u_mlton.sml", body + 'val _ = (testit (); testit (); testit ())\nin\nval done = "done";\nend\n')
        self.file("test/kitlife35u_smlnj.sml", body + 'in\nval done = "done";\nfun doit() = (testit(); testit(); testit())\nend\n')
        rows = {r["path"]: r for r in self.build("mlkit")}
        self.assertEqual(rows["test/kitlife35u_mlton.sml"]["disposition"], "duplicate")
        self.assertEqual(rows["test/kitlife35u_smlnj.sml"]["disposition"], "import")

    def test_sml_functor_members_are_included_in_directory_inventory(self):
        self.file("README.md", "# benchmarks\n")
        self.file("programs/generator/sources.cm", "Group is table.fun main.sml\n")
        self.file("programs/generator/table.fun", "functor Table()=struct end\n")
        self.file("programs/generator/main.sml", "structure Main=struct end\n")
        rows = self.build("smlnj")
        row = next(r for r in rows if r["path"] == "programs/generator")
        self.assertIn("programs/generator/table.fun", row["members"])

    def test_native_reference_build_caches_do_not_change_source_inventory(self):
        self.file("README.md", "# benchmarks\n")
        self.file("programs/generator/main.sml", "structure Main=struct end\n")
        before = self.build("smlnj")
        self.file("programs/generator/.cm/SKEL/main.sml", "binary source-looking cache")
        self.file("programs/generator/MLB/RI_GC/generated.sml", "cached generated source")
        self.assertEqual(before, self.build("smlnj"))

    def test_generated_ocaml_build_tree_does_not_invent_workloads(self):
        self.sandmark_program("main", "let result = 42\n")
        before = self.build("sandmark")
        self.file("benchmarks/_build/default/copied/dune", "(executable (name copy))\n")
        self.file("benchmarks/_build/default/copied/copy.ml", "let result = 17\n")
        self.assertEqual(before, self.build("sandmark"))

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

    def test_file_entrypoint_retains_transitive_local_dependencies(self):
        self.nofib_roots()
        self.file("real/app/Makefile", "\n")
        self.file("real/app/Main.hs", "module Main where\nimport First\nmain = print First.value\n")
        self.file("real/app/Other.hs", "module Main where\nmain = print 2\n")
        self.file("real/app/First.hs", "module First where\nimport qualified Second\nvalue = Second.value\n")
        self.file("real/app/Second.lhs", "> module Second where\n> import NofibUtils\n> value = 1\n")
        self.file("common/NofibUtils.hs", "module NofibUtils where\nhash = id\n")
        self.file("real/app/LICENSE", "individual program notice\n")
        rows = {r["path"]: r for r in self.build("nofib")}
        row = rows["real/app/Main.hs"]
        self.assertIn("real/app/First.hs", row["members"])
        self.assertIn("real/app/Second.lhs", row["members"])
        self.assertIn("common/NofibUtils.hs", row["members"])
        self.assertNotIn("Other.hs", row["members"])
        self.assertIn("real/app/LICENSE", row["notices"])

    def test_excluded_test_entrypoints_are_not_application_workloads(self):
        self.nofib_roots()
        self.file("real/app/Makefile", "EXCLUDED_SRCS=Test.hs\n")
        self.file("real/app/Main.hs", "module Main where\nmain = print 1\n")
        self.file("real/app/Test.hs", "module Main where\nmain = print True\n")
        rows = {r["path"]: r for r in self.build("nofib")}
        self.assertEqual(rows["real/app/Main.hs"]["disposition"], "import")
        self.assertEqual(rows["real/app/Test.hs"]["disposition"], "exclude")

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
