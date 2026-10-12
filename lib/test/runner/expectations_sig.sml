(* What a suite expects of its tests in some ways (docs/plans/unit-testing.md,
   D16; docs/testing.md, Expectations): one format, and one meaning for
   each category, for every list of deviations and skips.

   A file has a line for each expectation, and `#` begins a comment:

       WAY-GLOB | PATH-GLOB[::LABEL-GLOB] | CATEGORY | reason

   The globs have `*` (any run of characters), `?` (one character) and
   `[...]` (one of the characters, or ranges such as `0-9`, that it holds;
   `[!...]` one that it does not), as the shell has them, and must match the
   whole way, path or label. A line of three fields,
   `PATH-GLOB | CATEGORY | reason`, is of every way. A category's meaning is one of
   four:

   - strict: the test must fail where the line says (`RUNE-DEV`, `HOST-BUG`,
     `WIDTH`, `SPEC-AMBIGUOUS`, `WINDOWS`, `EMULATED`, `FAILS`). A test that
     passes there fails, and a line that matches no failure in a way that
     ran is stale;
   - lenient: the test may pass or fail (`HOST-FLAKY`, `FLAKY`);
   - skip: the test is not run, for the reason given (`HOST-ABSENT`,
     `XC1-NA`, `XC2-NA`, `UNTESTED`, `UNSUPPORTED`). A line that names no
     test is stale;
   - quarantine: the test runs and is reported, and its failure fails
     nothing until the date the reason begins with (`QUARANTINE`, with
     `until YYYY-MM-DD:`); after it the line is stale.

   Area: Running tests *)
signature EXPECTATIONS =
sig
  (* What a category means. *)
  datatype meaning = Strict | Lenient | Skip | Quarantine

  (* A line: where it is, its globs, its category and its reason. *)
  type line = {file : string, number : int, way : string, path : string, label : string option,
               category : string, reason : string}

  (* Raised by `parse` for a line that is not an expectation, with its file
     and number. *)
  exception Parse of string

  (* `meaning c` is what the category `c` means, or `NONE` for no category.

     Example: `meaning "HOST-BUG" = SOME Strict` *)
  val meaning : string -> meaning option

  (* `parse (file, text)` is the lines of `text`, the contents of `file`.

     Raises: `Parse` for a line with too few fields or a category that is
     not one, or a quarantine without its date.

     Example: `length (parse ("f", "# a comment\n* | a/* | FLAKY | why\n")) = 1` *)
  val parse : string * string -> line list

  (* `read file` is the lines of `file`, or none when there is no file. *)
  val read : string -> line list

  (* `glob (g, s)` says whether the glob `g` matches the whole of `s`.

     Example: `glob ("lang/*/rt.?", "lang/native/rt.a")`

     Example: `glob ("*.scan/DEC-[avfr]*", "Int.scan/DEC-v1") andalso not (glob ("[!o]x", "ox"))` *)
  val glob : string * string -> bool

  (* `find (ls, {way, path, label})` is the first line of `ls` that matches
     the test, if any.

     A line with a label matches only that test's label; one without
     matches the test, whatever its label. *)
  val find : line list * {way : string, path : string, label : string option} -> line option

  (* `skipped (ls, {way, path})` is the line that skips the test of `path`
     in `way`, if one does. *)
  val skipped : line list * {way : string, path : string} -> line option

  (* What a test that ran comes to, given the lines.

     `Pass` and `Fail` where no line speaks; `Expected` for a strict line's
     failure, and `Unexpected` for its pass; `Flaky` for a lenient line;
     `Quarantined` for a quarantined failure before its date, and `Expired`
     for one after it. *)
  datatype outcome = Pass | Fail | Expected of line | Unexpected of line | Flaky of line
                   | Quarantined of line | Expired of line

  (* `judge (ls, {way, path, label, passed, today})` is what the test comes
     to; `today` is the date as `YYYY-MM-DD`. *)
  val judge : line list * {way : string, path : string, label : string option, passed : bool, today : string}
              -> outcome

  (* `failing oc` says whether `oc` fails the run.

     Example: `failing Fail andalso not (failing Pass)` *)
  val failing : outcome -> bool

  (* `stale (ls, {ways, paths, used, today})` is the lines of `ls` that are
     stale after a run.

     Those are a strict line that names a way in `ways` and is not in
     `used` (the lines of the failures it expected), a skip line whose path
     matches none of `paths`, and a quarantine past its date. *)
  val stale : line list * {ways : string list, paths : string list, used : line list, today : string} -> line list

  (* `describe l` is `l` as its file and number say it, for a report. *)
  val describe : line -> string
end
