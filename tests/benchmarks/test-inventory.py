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

    def constraints_pair(self, second_source="main = print 1\n", second_normal="7"):
        self.nofib_roots()
        for directory, source, normal in [("gc/constraints", "main = print 1\n", "7"),
                                           ("spectral/constraints", second_source, second_normal)]:
            self.file(directory + "/Main.hs", source)
            self.file(directory + "/Makefile", "FAST_OPTS = 6\nNORM_OPTS = " + normal + "\nSLOW_OPTS = 8\n")

    def test_identical_constraints_share_implementation(self):
        self.constraints_pair()
        rows = {row["path"]: row for row in self.build("nofib")}
        self.assertEqual(rows["gc/constraints"]["disposition"], "import")
        self.assertEqual(rows["spectral/constraints"]["disposition"], "duplicate")
        self.assertIn("measurement configurations", rows["spectral/constraints"]["reason"])

    def test_changed_constraints_kernel_remains_distinct(self):
        self.constraints_pair(second_source="main = print 2\n")
        rows = {row["path"]: row for row in self.build("nofib")}
        self.assertEqual(rows["spectral/constraints"]["disposition"], "import")

    def test_changed_constraints_inputs_remain_distinct(self):
        self.constraints_pair(second_normal="9")
        rows = {row["path"]: row for row in self.build("nofib")}
        self.assertEqual(rows["spectral/constraints"]["disposition"], "import")

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

    def test_circuit_authorship_is_recorded_from_the_literate_heading(self):
        self.nofib_roots()
        self.file("gc/circsim/Makefile", "\n")
        self.file("gc/circsim/Main.lhs",
                  "The Circuit Simulator example\nDavid J. King & John O'Donnell\nJanuary, 1998\n\n> main = return ()\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "David J. King;John O'Donnell")
        self.assertIn("gc/circsim/Main.lhs:authorship-heading", row["evidence"])

    def test_changed_circuit_heading_does_not_inherit_unverified_authors(self):
        self.nofib_roots()
        self.file("gc/circsim/Makefile", "\n")
        self.file("gc/circsim/Main.lhs",
                  "The Circuit Simulator example\nDifferent authors\nJanuary, 1998\n\n> main = return ()\n")
        self.assertEqual(self.build("nofib")[0]["authors"], "not stated in scanned source headers")

    def test_hidden_correspondence_records_both_authors_and_permission(self):
        self.nofib_roots()
        self.file("real/hidden/Makefile", "\n")
        self.file("real/hidden/Main.hs", "main = print 0\n")
        self.file("real/hidden/MAIL",
                  "From:    ramaer@cs.utwente.nl (Mark Ramaer)\n"
                  "Certainly.  However, I should note that the program is written by\n"
                  "Stef Joosten (joosten@cs.utwente.nl) in Miranda(TM) and I have translated\n"
                  "it to Haskell to play with overloading; I also added the memoising.\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Mark Ramaer;Stef Joosten")
        self.assertIn("real/hidden/MAIL:authorship-and-nofib-permission", row["evidence"])
        self.assertIn("real/hidden/MAIL:nofib-permission", row["notices"])

    def test_changed_hidden_correspondence_requires_review(self):
        self.nofib_roots()
        self.file("real/hidden/Makefile", "\n")
        self.file("real/hidden/Main.hs", "main = print 0\n")
        self.file("real/hidden/MAIL", "A different author and permission.\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "not stated in scanned source headers")
        self.assertNotIn("real/hidden/MAIL:nofib-permission", row["notices"])

    def test_prolog_author_heading_is_recorded(self):
        self.nofib_roots()
        self.file("real/prolog/Makefile", "\n")
        self.file("real/prolog/Main.hs",
                  "-- Mark P. Jones November 1990\nmain = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Mark P. Jones")
        self.assertIn("real/prolog/Main.hs:author-heading", row["evidence"])

    def test_changed_prolog_author_heading_requires_review(self):
        self.nofib_roots()
        self.file("real/prolog/Makefile", "\n")
        self.file("real/prolog/Main.hs",
                  "-- Another author November 1990\nmain = print 0\n")
        self.assertNotIn("Mark P. Jones", self.build("nofib")[0]["authors"])

    def test_gamteb_author_heading_is_recorded(self):
        self.nofib_roots()
        self.file("real/gamteb/Makefile", "\n")
        self.file("real/gamteb/Main.hs",
                  "--      Patricia Fasel\n--      Los Alamos National Laboratory\nmain = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Patricia Fasel")
        self.assertIn("real/gamteb/Main.hs:author-heading", row["evidence"])

    def test_changed_gamteb_author_heading_requires_review(self):
        self.nofib_roots()
        self.file("real/gamteb/Makefile", "\n")
        self.file("real/gamteb/Main.hs",
                  "--      Another author\n--      Another laboratory\nmain = print 0\n")
        self.assertNotIn("Patricia Fasel", self.build("nofib")[0]["authors"])

    def test_mkhprog_literate_author_heading_is_recorded(self):
        self.nofib_roots()
        self.file("real/mkhprog/Makefile", "\n")
        self.file("real/mkhprog/Main.lhs",
                  "% Crown Copyright 1992\n\\author{N D North\\\\\n\n> main = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "N. D. North")
        self.assertIn("real/mkhprog/Main.lhs:author-and-crown-heading", row["evidence"])

    def test_changed_mkhprog_author_heading_requires_review(self):
        self.nofib_roots()
        self.file("real/mkhprog/Makefile", "\n")
        self.file("real/mkhprog/Main.lhs",
                  "% Crown Copyright 1992\n\\author{Another author\\\\\n\n> main = print 0\n")
        self.assertNotIn("N. D. North", self.build("nofib")[0]["authors"])

    def test_linear_authorship_and_conversion_roles_are_recorded(self):
        self.nofib_roots()
        self.file("real/linear/Makefile", "\n")
        self.file("real/linear/Main.lhs", "Written by Brian D. Moe (Summer 1990)\nModified by Kamini Shenoi (Summer 1991)\nConverted to Haskell by Ian R McLelland and Cordelia V Hall (Nov 1992)\n\\begin{code}\nmain = print 0\n\\end{code}\n")
        row = self.build("nofib")[0]
        for name in ["Brian D. Moe", "Kamini Shenoi", "Ian R. McLelland", "Cordelia V. Hall"]:
            self.assertIn(name, row["authors"])
        self.assertIn("real/linear/Main.lhs:authorship-and-conversion-roles", row["evidence"])

    def test_changed_linear_conversion_header_requires_review(self):
        self.nofib_roots()
        self.file("real/linear/Makefile", "\n")
        self.file("real/linear/Main.lhs", "Another conversion\n\\begin{code}\nmain = print 0\n\\end{code}\n")
        self.assertNotIn("Cordelia V. Hall", self.build("nofib")[0]["authors"])

    def test_linear_input_roles_are_recorded(self):
        self.nofib_roots()
        self.file("gc/linear/Makefile", "\n")
        self.file("gc/linear/Main.lhs", "\\begin{code}\nmain = print 0\n\\end{code}\n")
        self.file("gc/linear/Input.lhs", "Roger L. Wainwright  6-8-90\nwritten by Dan Vasicek and copied from his directory 6/22/90\n")
        row = self.build("nofib")[0]
        self.assertIn("Roger L. Wainwright", row["authors"])
        self.assertIn("Dan Vasicek", row["authors"])

    def test_changed_linear_input_credit_requires_review(self):
        self.nofib_roots()
        self.file("gc/linear/Makefile", "\n")
        self.file("gc/linear/Main.lhs", "\\begin{code}\nmain = print 0\n\\end{code}\n")
        self.file("gc/linear/Input.lhs", "Another input author\n")
        self.assertNotIn("Dan Vasicek", self.build("nofib")[0]["authors"])

    def test_sphere_source_port_author_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/sphere/Makefile", "\n")
        self.file("spectral/sphere/Main.lhs", "This is a Haskell port of the Id version from the Impala\n16 July, 1998, David J. King\n> module Main where\n> main = print 0\n")
        row = self.build("nofib")[0]
        self.assertIn("David J. King", row["authors"])
        self.assertIn("spectral/sphere/Main.lhs:authorship-and-port-history", row["evidence"])

    def test_changed_sphere_port_attribution_requires_review(self):
        self.nofib_roots()
        self.file("spectral/sphere/Makefile", "\n")
        self.file("spectral/sphere/Main.lhs", "Another author\n> module Main where\n> main = print 0\n")
        self.assertNotIn("David J. King", self.build("nofib")[0]["authors"])

    def test_para_article_authors_are_recorded(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\n")
        self.file("spectral/para/Main.lhs", "% \tA program by Oege de Moor and Jeremy Gibbons\n> module Main where\n> main = print 0\n")
        row = self.build("nofib")[0]
        self.assertIn("Oege de Moor", row["authors"])
        self.assertIn("Jeremy Gibbons", row["authors"])

    def test_changed_para_article_author_requires_review(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\n")
        self.file("spectral/para/Main.lhs", "% A program by Another author\n> module Main where\n> main = print 0\n")
        self.assertNotIn("Oege de Moor", self.build("nofib")[0]["authors"])

    def test_para_individual_data_notice_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\n")
        self.file("spectral/para/Main.lhs", "> module Main where\n> main = print 0\n")
        self.file("spectral/para/runtime_files/input-data", "Far From The Madding Crowd, by Thomas Hardy\n*END*THE SMALL PRINT! FOR PUBLIC DOMAIN ETEXTS*Ver.04.29.93*END*\n")
        self.assertIn("spectral/para/runtime_files/input-data:Project-Gutenberg-1993-notice", self.build("nofib")[0]["notices"])

    def test_incomplete_para_notice_requires_review(self):
        self.nofib_roots()
        self.file("spectral/para/Makefile", "\n")
        self.file("spectral/para/Main.lhs", "> module Main where\n> main = print 0\n")
        self.file("spectral/para/runtime_files/input-data", "Far From The Madding Crowd, by Thomas Hardy\n")
        self.assertNotIn("spectral/para/runtime_files/input-data:Project-Gutenberg-1993-notice", self.build("nofib")[0]["notices"])

    def test_lambda_source_author_header_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/lambda/Makefile", "\n")
        self.file("spectral/lambda/Main.hs", "module Main where\n-- From Mark: marku@cs.waikato.ac.nz [Nov 2001]\nmain = print 0\n")
        row = self.build("nofib")[0]
        self.assertIn("Mark (marku@cs.waikato.ac.nz)", row["authors"])
        self.assertIn("spectral/lambda/Main.hs:author-header", row["evidence"])

    def test_changed_lambda_source_author_requires_review(self):
        self.nofib_roots()
        self.file("spectral/lambda/Makefile", "\n")
        self.file("spectral/lambda/Main.hs", "module Main where\n-- From Another author\nmain = print 0\n")
        self.assertNotIn("Mark (marku@cs.waikato.ac.nz)", self.build("nofib")[0]["authors"])

    def test_fft2_source_author_header_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/fft2/Makefile", "\n")
        self.file("spectral/fft2/Main.lhs", "> module Main where\n> main = print 0\n> -- Rex Page (rpage@trc.amoco.com)\n> -- Amoco Production Research, Sep 1992\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Rex Page")
        self.assertIn("spectral/fft2/Main.lhs:author-header", row["evidence"])

    def test_changed_fft2_author_header_requires_review(self):
        self.nofib_roots()
        self.file("spectral/fft2/Makefile", "\n")
        self.file("spectral/fft2/Main.lhs", "> module Main where\n> main = print 0\n> -- Another author\n")
        self.assertNotIn("Rex Page", self.build("nofib")[0]["authors"])

    def test_gg_manual_author_section_is_recorded(self):
        self.nofib_roots()
        self.file("real/gg/Makefile", "\n")
        self.file("real/gg/Main.hs", "main = print 0\n")
        self.file("real/gg/gg.1", ".SH AUTHOR\nIain Checkland, University of York.\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Iain Checkland")
        self.assertIn("real/gg/gg.1:author-section", row["evidence"])

    def test_changed_gg_manual_author_requires_review(self):
        self.nofib_roots()
        self.file("real/gg/Makefile", "\n")
        self.file("real/gg/Main.hs", "main = print 0\n")
        self.file("real/gg/gg.1", ".SH AUTHOR\nAnother author.\n")
        self.assertNotIn("Iain Checkland", self.build("nofib")[0]["authors"])

    def test_pic_author_heading_is_recorded(self):
        self.nofib_roots()
        self.file("real/pic/Makefile", "\n")
        self.file("real/pic/Main.hs",
                  "--\n--      Patricia Fasel\n--      Los Alamos National Laboratory\nmain = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Patricia Fasel")
        self.assertIn("real/pic/Main.hs:author-heading", row["evidence"])

    def test_changed_pic_author_heading_requires_review(self):
        self.nofib_roots()
        self.file("real/pic/Makefile", "\n")
        self.file("real/pic/Main.hs",
                  "--      Another author\n--      Another laboratory\nmain = print 0\n")
        self.assertNotIn("Patricia Fasel", self.build("nofib")[0]["authors"])

    def test_primetest_declared_author_replaces_rcs_committer(self):
        self.nofib_roots()
        self.file("spectral/primetest/Makefile", "\n")
        self.file("spectral/primetest/Main.lhs",
                  "\\def\\author{David Lester}\n%$Author: simonmar $\n> main = print 0\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "David Lester")
        self.assertIn("spectral/primetest/Main.lhs:author-macro", row["evidence"])

    def test_changed_primetest_author_requires_review(self):
        self.nofib_roots()
        self.file("spectral/primetest/Makefile", "\n")
        self.file("spectral/primetest/Main.lhs",
                  "\\def\\author{Another author}\n> main = print 0\n")
        self.assertNotIn("David Lester", self.build("nofib")[0]["authors"])

    def test_quoted_primetest_macro_is_not_an_author_declaration(self):
        self.nofib_roots()
        self.file("spectral/primetest/Makefile", "\n")
        self.file("spectral/primetest/Main.lhs",
                  '> main = putStrLn "\\\\def\\\\author{David Lester}"\n')
        self.assertNotIn("David Lester", self.build("nofib")[0]["authors"])

    def test_reviewed_bigarray_storage_modes_are_deferred(self):
        self.file("benchmarks/stdlib/dune", "(executable (name big_array_bench))\n")
        self.file("benchmarks/stdlib/big_array_bench.ml",
                  (ROOT / "tests/benchmarks/data/inventory-stdlib/big_array_bench.ml").read_text())
        row = self.build("sandmark")[0]
        self.assertEqual(row["disposition"], "defer")
        self.assertIn("C-layout storage", row["reason"])

    def test_changed_bigarray_source_requires_review(self):
        self.file("benchmarks/stdlib/dune", "(executable (name big_array_bench))\n")
        self.file("benchmarks/stdlib/big_array_bench.ml",
                  (ROOT / "tests/benchmarks/data/inventory-stdlib/big_array_bench.ml").read_text()
                  + "\nlet changed = true\n")
        self.assertEqual(self.build("sandmark")[0]["disposition"], "import")

    def test_bigarray_name_does_not_defer_portable_array_code(self):
        self.file("benchmarks/stdlib/dune", "(executable (name big_array_bench))\n")
        self.file("benchmarks/stdlib/big_array_bench.ml", "let a = Array.make 10 0\n")
        self.assertEqual(self.build("sandmark")[0]["disposition"], "import")

    def test_exact_reals_paper_attribution_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/exact-reals/Makefile", "\n")
        self.file("spectral/exact-reals/Main.hs",
                  '-- Taken from "The worlds shortest correct exact real arithmetic program?"\n'
                  '-- David Lester, Information and Computation 216, pp39-46, 2012, Elsevier\n'
                  'main = print 0\n')
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "David Lester")
        self.assertIn("spectral/exact-reals/Main.hs:paper-attribution", row["evidence"])

    def test_changed_exact_reals_paper_attribution_requires_review(self):
        self.nofib_roots()
        self.file("spectral/exact-reals/Makefile", "\n")
        self.file("spectral/exact-reals/Main.hs",
                  '-- Taken from a different paper\n-- David Lester, another work\nmain = print 0\n')
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "not stated in scanned source headers")

    def test_atom_multiline_attribution_is_recorded(self):
        self.nofib_roots()
        self.file("spectral/atom/Makefile", "\n")
        self.file("spectral/atom/Main.hs",
                  "{- A kernel fragment from a program written by\n\t\tRon Legere\n-}\nmain = print 1\n")
        row = self.build("nofib")[0]
        self.assertEqual(row["authors"], "Ron Legere")
        self.assertIn("spectral/atom/Main.hs:attribution-header", row["evidence"])

    def test_changed_atom_attribution_requires_review(self):
        self.nofib_roots()
        self.file("spectral/atom/Makefile", "\n")
        self.file("spectral/atom/Main.hs",
                  "{- A kernel fragment from a program written by\n\t\tDifferent Person\n-}\nmain = print 1\n")
        self.assertNotIn("Ron Legere", self.build("nofib")[0]["authors"])

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

    def opaque_call_probe(self, text):
        self.file("benchmarks/simple-tests/morestacks.ml", text)
        self.file("benchmarks/simple-tests/dune", "(executable (name morestacks) (modes native byte))\n")
        return self.build("sandmark")[0]

    def test_pinned_opaque_call_probe_has_a_capability_blocker(self):
        original = (ROOT / "tests/benchmarks/data/sandmark-morestacks.ml").read_text()
        row = self.opaque_call_probe(original)
        self.assertEqual(row["disposition"], "defer")
        self.assertIn("optimization barrier", row["reason"])
        self.assertIn("reconsider", row["reason"])

    def test_changed_opaque_call_probe_requires_fresh_review(self):
        original = (ROOT / "tests/benchmarks/data/sandmark-morestacks.ml").read_text()
        row = self.opaque_call_probe(original.replace("n + 5", "n * n + 5"))
        self.assertEqual(row["disposition"], "import")

    def test_algorithmic_opacity_is_not_blanket_deferred(self):
        self.sandmark_program("kernel", "let f n = n * n\nlet result = Sys.opaque_identity f 13\n")
        self.assertEqual(self.build("sandmark")[0]["disposition"], "import")

    def allocation_probe(self, name, text):
        self.file("benchmarks/simple-tests/" + name + ".ml", text)
        self.file("benchmarks/simple-tests/dune",
                  "(executable (name " + name + ") (modes native byte))\n")
        return next(row for row in self.build("sandmark")
                    if row["path"] == "benchmarks/simple-tests/" + name + ".exe")

    def test_reviewed_allocation_probes_record_the_missing_barrier(self):
        for name in ("alloc", "lists", "stacks", "stress"):
            with self.subTest(name=name):
                text = (ROOT / ("tests/benchmarks/data/sandmark-opaque/" + name + ".ml")).read_text()
                row = self.allocation_probe(name, text)
                self.assertEqual(row["disposition"], "defer")
                self.assertIn("optimization barrier", row["reason"])
                self.assertIn("reconsider", row["reason"])

    def test_changed_allocation_probes_require_fresh_review(self):
        for name in ("alloc", "lists", "stacks", "stress"):
            with self.subTest(name=name):
                text = (ROOT / ("tests/benchmarks/data/sandmark-opaque/" + name + ".ml")).read_text()
                row = self.allocation_probe(name, text + "\n(* upstream changed *)\n")
                self.assertEqual(row["disposition"], "import")

    def test_reviewed_source_at_an_unreviewed_path_is_not_automatically_deferred(self):
        for name in ("alloc", "lists", "stacks", "stress"):
            with self.subTest(name=name):
                text = (ROOT / ("tests/benchmarks/data/sandmark-opaque/" + name + ".ml")).read_text()
                self.sandmark_program("algorithm_" + name, text)
                row = next(row for row in self.build("sandmark")
                           if row["path"] == "benchmarks/kernels/algorithm_" + name + ".exe")
                self.assertEqual(row["disposition"], "import")

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

    def test_nofib_profile_arguments_include_graph_dataset(self):
        self.nofib_roots()
        self.file("spectral/dom-lt/Main.hs", "main = return ()\n")
        self.file("spectral/dom-lt/Makefile", "FAST_OPTS = ghc-examples.in 50\nNORM_OPTS = ghc-examples.in 400\n")
        self.file("spectral/dom-lt/ghc-examples.in", "graph data\n")
        self.assertEqual(self.build("nofib")[0]["inputs"], "spectral/dom-lt/ghc-examples.in")

    def test_nofib_profile_paths_support_quotes_flags_and_continuations(self):
        self.nofib_roots()
        self.file("spectral/graphs/Main.hs", "main = return ()\n")
        self.file("spectral/graphs/Makefile",
                  'NORM_OPTS = "data/input graph.bin" \\\n --lookup=names.tbl 400 # decoy.bin\n')
        self.file("spectral/graphs/data/input graph.bin", "graph\n")
        self.file("spectral/graphs/names.tbl", "names\n")
        self.file("spectral/graphs/decoy.bin", "not an argument\n")
        self.assertEqual(self.build("nofib")[0]["inputs"],
                         "spectral/graphs/data/input graph.bin;spectral/graphs/names.tbl")

    def test_nofib_input_stems_retain_circuit_files(self):
        self.nofib_roots()
        self.file("real/scs/Main.hs", 'main = readFile (file ++ ".in")\n')
        self.file("real/scs/Makefile", "NORM_OPTS = runtime_files/inverter 345 2n 4u 1\n")
        self.file("real/scs/runtime_files/inverter.in", "circuit data\n")
        self.assertEqual(self.build("nofib")[0]["inputs"], "real/scs/runtime_files/inverter.in")

    def test_nofib_profile_paths_stay_inside_pinned_tree(self):
        self.nofib_roots()
        self.file("spectral/graphs/Main.hs", "main = return ()\n")
        with tempfile.TemporaryDirectory() as outside:
            dataset = Path(outside) / "external.bin"
            dataset.write_text("external\n")
            self.file("spectral/graphs/Makefile", "NORM_OPTS = " + str(dataset) + " 400\n")
            self.assertEqual(self.build("nofib")[0]["inputs"], "")

    def test_related_names_are_independent_of_discovery_order(self):
        rows = [dict(source=source, path=path, name="fft") for source, path in
                [("smlnj", "programs/fft"), ("sandmark", "benchmarks/fft.exe"), ("mlton", "fft.sml")]]
        reversed_rows = copy.deepcopy(list(reversed(rows)))
        AUDIT.related(rows)
        AUDIT.related(reversed_rows)
        self.assertEqual({r["source"]: r["related"] for r in rows},
                         {r["source"]: r["related"] for r in reversed_rows})
        self.assertEqual(rows[0]["related"], "mlton:fft.sml;sandmark:benchmarks/fft.exe")

    def test_digest_includes_member_identity_and_content(self):
        a = self.file("a.sml", "structure A = struct end\n")
        b = self.file("b.sml", a.read_text())
        self.assertNotEqual(AUDIT.digest(self.root, [a]), AUDIT.digest(self.root, [b]))
        before = AUDIT.digest(self.root, [a])
        a.write_text("structure A = struct val x = 1 end\n")
        self.assertNotEqual(before, AUDIT.digest(self.root, [a]))

    def test_cpp_dependencies_are_transitive_source_members(self):
        self.nofib_roots()
        self.file("spectral/compiler/Makefile", "\n")
        self.file("spectral/compiler/Main.hs", '#include "../shared.h"\nmain = print 1\n')
        self.file("spectral/shared.h", '#include "constants.inc"\n')
        header = self.file("spectral/constants.inc", "value = 1\n")
        before = self.build("nofib")[0]
        self.assertEqual(before["members"],
                         "spectral/compiler/Main.hs;spectral/constants.inc;spectral/shared.h")
        self.assertEqual(before["inputs"], "")
        header.write_text("value = 2\n")
        self.assertNotEqual(before["sha256"], self.build("nofib")[0]["sha256"])

    def test_cpp_dependencies_follow_file_entrypoints(self):
        self.nofib_roots()
        self.file("spectral/compiler/Makefile", "\n")
        self.file("spectral/compiler/one.hs", '#include "values.inc"\nmain = print value\n')
        self.file("spectral/compiler/two.hs", "main = print 2\n")
        self.file("spectral/compiler/values.inc", "value = 1\n")
        rows = {r["path"]: r for r in self.build("nofib")}
        self.assertIn("spectral/compiler/values.inc", rows["spectral/compiler/one.hs"]["members"])
        self.assertNotIn("spectral/compiler/values.inc", rows["spectral/compiler/two.hs"]["members"])

    def test_cpp_headers_cannot_hide_unavailable_primitive_imports(self):
        self.nofib_roots()
        self.file("spectral/compiler/Makefile", "\n")
        self.file("spectral/compiler/Main.hs", '#include "primitive.inc"\nmain = print 1\n')
        self.file("spectral/compiler/primitive.inc", "import GHC.Prim\n")
        self.assertEqual(self.build("nofib")[0]["disposition"], "defer")

    def test_cpp_c_helpers_retain_headers_outside_the_program_directory(self):
        self.nofib_roots()
        self.file("spectral/compiler/Makefile", "\n")
        self.file("spectral/compiler/Main.hs", "main = print 1\n")
        self.file("spectral/compiler/helper.c", '#include "../helper.h"\n')
        self.file("spectral/helper.h", "int helper(void);\n")
        self.assertIn("spectral/helper.h", self.build("nofib")[0]["members"])

    def test_cpp_cycles_terminate_and_cannot_escape_the_upstream(self):
        main = self.file("repo/Main.hs", '#include "a.inc"\n#include "../outside.inc"\n')
        header = self.file("repo/a.inc", '#include "Main.hs"\n')
        self.file("outside.inc", "must not enter the source identity\n")
        self.assertEqual(AUDIT.source_files(self.root / "repo", "Main.hs"), sorted([main, header]))

    def test_cpp_header_is_not_runtime_data_but_cli_source_is(self):
        self.nofib_roots()
        self.file("spectral/compiler/Makefile", "FAST_OPTS = table.hs\n")
        self.file("spectral/compiler/Main.hs", '#include "helpers.hs"\nmain = print 1\n')
        self.file("spectral/compiler/helpers.hs", "value = 1\n")
        self.file("spectral/compiler/table.hs", "rows = []\n")
        self.assertEqual(self.build("nofib")[0]["inputs"], "spectral/compiler/table.hs")

    def hartel_shim(self):
        self.nofib_roots()
        self.file("spectral/hartel/listcompr/Makefile", "\n")
        self.file("spectral/hartel/listcompr/Main.hs",
                  '#include "../Fast2haskell.hs"\nmain = print 1\n')
        shim = self.root / "spectral/hartel/Fast2haskell.hs"
        shim.write_bytes((ROOT / "tests/benchmarks/data/inventory-hartel/Fast2haskell.hs").read_bytes())
        return shim

    def test_reviewed_hartel_shim_has_portable_scalar_operations(self):
        self.hartel_shim()
        self.assertEqual(self.build("nofib")[0]["disposition"], "import")

    def test_changed_hartel_shim_requires_a_new_capability_review(self):
        shim = self.hartel_shim()
        shim.write_bytes(shim.read_bytes() + b"\n-- changed upstream shim\n")
        self.assertEqual(self.build("nofib")[0]["disposition"], "defer")

    def test_reviewed_shim_does_not_hide_direct_primitive_imports(self):
        self.hartel_shim()
        self.file("spectral/hartel/listcompr/Main.hs",
                  '#include "../Fast2haskell.hs"\nimport GHC.Prim\nmain = print 1\n')
        self.assertEqual(self.build("nofib")[0]["disposition"], "defer")

    def test_unreviewed_shim_path_does_not_inherit_the_exception(self):
        shim = self.hartel_shim()
        self.file("spectral/hartel/listcompr/Main.hs", '#include "../other.hs"\nmain = print 1\n')
        shim.rename(shim.with_name("other.hs"))
        self.assertEqual(self.build("nofib")[0]["disposition"], "defer")

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
