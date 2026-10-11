(* The units whose files are named, loaded one after another by
   Runtime.load and each run as it is loaded: the dynamic path of
   tests/units/run.sh and scripts/check-units.sh (docs/units.md, Loading).
   It prints nothing itself, so that what the loaded program prints is all
   there is. *)
val () = List.app (fn file => Runtime.load file ()) (CommandLine.arguments ())
