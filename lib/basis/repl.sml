(* Repl: the REPL's commands as functions, through the hooks the REPL fills
   when it starts (src/repl/commands.sml); Rune's own. *)
structure RuneRepl =
struct
  fun none _ = raise Fail "Repl: this program has no REPL around it (rune-repl has)"
  val commandHook : (string -> unit) ref = ref none
  val typeOfHook : (string -> string) ref = ref none
  val infoHook : (string -> string) ref = ref none
  val docHook : (string -> string) ref = ref none
  val searchHook : (string -> string) ref = ref none
  val setHook : (string * string -> unit) ref = ref none
  val settingsHook : (unit -> (string * string) list) ref = ref none

  fun command line = !commandHook line
  fun typeOf exp = !typeOfHook exp
  fun info name = !infoHook name
  fun doc name = !docHook name
  fun search text = !searchHook text
  fun set setting = !setHook setting
  fun settings () = !settingsHook ()
end

(* Repl: what a program can ask of the REPL it runs in.

   Implements: REPL

   Status: extension *)
structure Repl = RuneRepl
