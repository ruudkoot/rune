(* Golden files: the comparison, and the accept mode that writes them. *)
structure Golden :> GOLDEN =
struct
  val accept = ref false

  fun lines s = String.fields (fn c => c = #"\n") s

  fun difference (expected, actual) =
    let
      fun go (_, [], []) = NONE
        | go (n, e :: es, a :: as') = if e = a then go (n + 1, es, as') else SOME (n, e, a)
        | go (n, e :: _, []) = SOME (n, e, "<end of text>")
        | go (n, [], a :: _) = SOME (n, "<end of file>", a)
    in
      if expected = actual then NONE else go (1, lines expected, lines actual)
    end

  fun read path =
    let val s = TextIO.openIn path
    in SOME (TextIO.inputAll s before TextIO.closeIn s) end
    handle IO.Io _ => NONE

  fun write (path, text) =
    let val s = TextIO.openOut path in TextIO.output (s, text); TextIO.closeOut s end

  fun check (label, {expected, actual}) =
    if !accept then
      ((if read expected = SOME actual then () else write (expected, actual)); Expect.that (label, true))
    else
      case read expected of
        NONE => Expect.that (label ^ ": no file " ^ expected, false)
      | SOME old =>
          case difference (old, actual) of
            NONE => Expect.that (label, true)
          | SOME (n, e, a) =>
              Expect.that (label ^ ": " ^ expected ^ " differs at line " ^ Int.toString n ^ ": expected "
                           ^ String.toString e ^ ", got " ^ String.toString a, false)
end
