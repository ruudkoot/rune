(* The units whose files are named before `--save IMAGE` loaded and run,
   the world then saved to IMAGE, and the units named after it loaded and
   run in the world restored from it (runevm --restore IMAGE): an image
   carries the units loaded and what they export (docs/units.md, Loading).
   The world that saves stops there. *)
fun split (earlier, "--save" :: image :: later) = (List.rev earlier, image, later)
  | split (earlier, x :: rest) = split (x :: earlier, rest)
  | split (earlier, []) = (List.rev earlier, "", [])
val (first, image, rest) = split ([], CommandLine.arguments ())
val () = List.app (fn file => Runtime.load file ()) first
val () =
  case Runtime.save image of
    Runtime.Saved => ()
  | Runtime.Restored => List.app (fn file => Runtime.load file ()) rest
