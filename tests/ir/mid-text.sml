(* dump: --dump-after=mid *)
(* Constants as Mid's text writes them, and reads them back (the runner
   checks every test with --mid-roundtrip): strings and characters with
   SML's escapes -- the character 28 is written \^\ -- a negative number, a
   word, a real, and a record of one field, {int}. *)
val s = "a\"b\\c\028d\127e\n"
val c = #"\028"
val n = ~5
val w = 0w7
val r = 1.5E~3
val one = {a = 1}
