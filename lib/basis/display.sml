(* Display: an output in several forms, through hooks the REPL's engine
   fills (src/repl/protocol.sml), which hand it to the front; Rune's own. *)
structure RuneDisplay =
struct
  type bundle = (string * string) list

  (* the text of an output where only text is shown *)
  fun text (b : bundle) : string =
    case List.find (fn (m, _) => m = "text/plain") b of
      SOME (_, t) => t
    | NONE => (case b of (_, t) :: _ => t | [] => "")

  fun printed (b : bundle) = let val t = text b in print (if String.isSuffix "\n" t orelse t = "" then t else t ^ "\n") end

  (* what shows an output: its id where it has one, whether it replaces the
     one of that id, and its forms *)
  val showHook : (string option * bool * bundle -> unit) ref = ref (fn (_, _, b) => printed b)
  val clearHook : (bool -> unit) ref = ref (fn _ => ())

  fun display b = !showHook (NONE, false, b)
  fun displayAs (id, b) = !showHook (SOME id, false, b)
  fun update (id, b) = !showHook (SOME id, true, b)
  fun clear wait = !clearHook wait
end

(* Display: what a program shows beside what it prints.

   Implements: DISPLAY

   Status: extension *)
structure Display = RuneDisplay
