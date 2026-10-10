(* libraries: terminal *)
(* A program that reads lines with lib/terminal's editor: Emacs's keys,
   history (kept in the file the first argument names, if any), completion
   of the words it has seen, and inputs of many lines -- an input is
   complete when it ends with ";" -- each echoed with its length. Where
   the terminal cannot be edited on (a pipe, TERM=dumb) it reads plain
   lines. Build and run with:
     bin/rune --library terminal examples/readline.sml -o readline.rbc && bin/runevm readline.rbc *)
val history =
  History.load {file = case CommandLine.arguments () of [f] => SOME f | _ => NONE, limit = 1000}

val words = ref ["print", "println", "printLength", "readLine", "real", "reverse"]

(* the word before byte i, and the words seen that begin with it *)
fun complete (text, i) =
  let
    fun start j = if j > 0 andalso Char.isAlphaNum (String.sub (text, j - 1)) then start (j - 1) else j
    val s = start i
    val w = String.substring (text, s, i - s)
  in
    {start = s, candidates = if w = "" then [] else List.filter (String.isPrefix w) (!words)}
  end

val config =
  {prompt = "> ", continuation = ". ", isComplete = fn t => t = "" orelse String.isSuffix ";" t,
   complete = complete, hint = #hint LineEdit.defaults, highlight = #highlight LineEdit.defaults,
   styles = #styles LineEdit.defaults, bindings = #bindings LineEdit.defaults,
   escapeTimeout = #escapeTimeout LineEdit.defaults, policy = Terminal.policy (), basic = false}

fun loop () =
  case LineEdit.readLine (config, SOME history) of
    LineEdit.Line "" => loop ()
  | LineEdit.Line t =>
      (print ("read " ^ Int.toString (size t) ^ " bytes: " ^ String.toString t ^ "\n");
       words := !words @ List.filter (fn w => size w > 2) (String.tokens (not o Char.isAlphaNum) t);
       loop ())
  | LineEdit.Interrupted => (print "cancelled\n"; loop ())
  | LineEdit.End => print "bye\n"

val () = loop ()
