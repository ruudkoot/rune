(* Which tests to run (docs/plans/unit-testing.md, D4): a small language of
   filters over a test's path and tags.

   A word is a pattern on the path: with `*` (any run of characters) or `?`
   (one character) it must match the whole path, and without them it need
   only occur in it, as `run-tests.sh`'s filter does. `tag:T` selects the
   tests tagged `T`, and `way:W` those of the way `W`. `!` negates, `&`
   and `|` combine, `!` binding tightest and `|` loosest, and parentheses
   group. The empty filter selects every test.

   Area: Unit testing *)
signature TEST_FILTER =
sig
  (* A filter. *)
  type filter

  (* Raised by `parse` for text that is not a filter, with what is wrong. *)
  exception Parse of string

  (* The filter that selects every test.

     Example: `matches all {path = "any/thing", tags = []} = true` *)
  val all : filter

  (* `parse s` is the filter `s` says.

     Raises: `Parse` if `s` is not a filter, as `"a &"`.

     Example: `matches (parse "lib/* & !tag:slow") {path = "lib/json", tags = []} = true`

     Example: `matches (parse "json | way:stack") {path = "lang/x[stack]", tags = ["way:stack"]} = true` *)
  val parse : string -> filter

  (* `matches f {path, tags}` says whether `f` selects the test of `path`
     and `tags`.

     Example: `matches (parse "word") {path = "lib/basis/word64", tags = []} = true` *)
  val matches : filter -> {path : string, tags : string list} -> bool
end
