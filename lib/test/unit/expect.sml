(* Checks inside a test: the failures of the test that runs, in reverse,
   and the number of its checks. *)
structure Expect :> EXPECT =
struct
  exception Failure of string

  val failures : string list ref = ref []
  val count = ref 0

  fun record (ok, message) = (count := !count + 1; if ok then () else failures := message :: !failures)

  (* an exception as a message: `Fail`'s own message, which not every
     compiler's exnMessage gives, and otherwise its name and message once *)
  fun describe (Fail m) = "Fail: " ^ m
    | describe e =
        let val n = exnName e and m = exnMessage e
        in if m = n orelse String.isPrefix (n ^ ":") m then m else n ^ ": " ^ m end

  fun check (label, f) =
    record ((f ()) handle e => (failures := (label ^ ": raised " ^ describe e) :: !failures; true), label)

  fun that (label, b) = record (b, label)

  fun equal (same, show) (label, expected, f) =
    (case (SOME (f ()) handle e => (record (false, label ^ ": expected " ^ show expected ^ ", raised " ^ describe e); NONE)) of
       NONE => ()
     | SOME actual =>
         record (same (expected, actual), label ^ ": expected " ^ show expected ^ ", got " ^ show actual))

  fun eq show (label, expected, f) = equal (op =, show) (label, expected, f)

  fun raises (label, isIt, f) =
    record ((ignore (f ()); false) handle e => isIt e, label ^ ": no exception of the kind expected")

  fun fail message = raise Failure message

  datatype outcome = Pass | Fail of string list | Error of string

  fun run f =
    let
      val () = (failures := []; count := 0)
      val outcome =
        (f (); case !failures of [] => Pass | fs => Fail (rev fs))
        handle Failure m => Fail (rev (m :: !failures))
             | e => Error (describe e)
    in
      {outcome = outcome, checks = !count}
    end
end
