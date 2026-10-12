(* Checks inside a test (docs/plans/unit-testing.md, D3): a test is the
   unit of verdict, and the checks in it are soft. A check that fails is
   recorded with its label and the test goes on; the test fails if any of
   its checks failed, and `fail` ends it at once. A test that raises an
   exception of its own fails with the exception's name and message.

   The checks have the shapes of the Basis Library suite's harness
   (tests/basis/harness.sml): a label, then what is expected, then a
   function that computes what is, so that an exception raised while
   computing it fails that check alone.

   Area: Unit testing *)
signature EXPECT =
sig
  (* Raised by `fail`: the test ends, failed, with the message. *)
  exception Failure of string

  (* `check (label, f)` passes if `f ()` is `true`; it fails if it is
     `false` or raises.

     Example: `#checks (run (fn () => check ("one", fn () => 1 + 1 = 2))) = 1` *)
  val check : string * (unit -> bool) -> unit

  (* `that (label, b)` passes if `b` is `true`.

     Example: `#outcome (run (fn () => that ("false", false))) = Fail ["false"]` *)
  val that : string * bool -> unit

  (* `eq show (label, expected, f)` passes if `f ()` equals `expected`,
     and otherwise says both, printed by `show`.

     Example: `#outcome (run (fn () => eq Int.toString ("sum", 4, fn () => 2 + 3))) = Fail ["sum: expected 4, got 5"]` *)
  val eq : (''a -> string) -> string * ''a * (unit -> ''a) -> unit

  (* `equal (same, show) (label, expected, f)` passes if `same (expected,
     f ())`, for a type whose equality is not `=`.

     Example: `#outcome (run (fn () => equal (Real.==, Real.toString) ("half", 0.5, fn () => 1.0 / 2.0))) = Pass` *)
  val equal : ('a * 'a -> bool) * ('a -> string) -> string * 'a * (unit -> 'a) -> unit

  (* `raises (label, isIt, f)` passes if `f ()` raises an exception for
     which `isIt` is `true`.

     Example: `#outcome (run (fn () => raises ("hd", fn Empty => true | _ => false, fn () => hd []))) = Pass` *)
  val raises : string * (exn -> bool) * (unit -> 'a) -> unit

  (* `fail message` ends the test, failed.

     Raises: `Failure` always. *)
  val fail : string -> 'a

  (* How a test ended: every check passed; some failed, or `fail` was
     called, with the messages in the order they came; or the test raised
     an exception of its own. *)
  datatype outcome = Pass | Fail of string list | Error of string

  (* `run f` runs the body of a test and counts its checks.

     Example: `run (fn () => ()) = {outcome = Pass, checks = 0}` *)
  val run : (unit -> unit) -> {outcome : outcome, checks : int}
end
