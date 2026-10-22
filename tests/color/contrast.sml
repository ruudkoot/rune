(* The palette's contrast (docs/diagnostics.md), formerly contrast.py.
   Compile with src/util/color.sml: use the actual palette values rather
   than extracting strings from its source. The terminal palettes, floors
   and Machado et al. (2009) matrices are the former test's oracle. *)
structure Contrast =
struct
  val palettes =
    [("xterm", true,
      "000000 cd0000 00cd00 cdcd00 0000ee cd00cd 00cdcd e5e5e5 7f7f7f ff0000 00ff00 ffff00 5c5cff ff00ff 00ffff ffffff",
      [("dark", "000000"), ("light", "ffffff")]),
     ("vte-gnome", false,
      "171421 c01c28 26a269 a2734c 12488b a347ba 2aa1b3 d0cfcc 5e5c64 f66151 33da7a e9ad0c 2a7bde c061cb 33c7de ffffff",
      [("dark", "171421"), ("light", "ffffff")]),
     ("windows-terminal-campbell", true,
      "0c0c0c c50f1f 13a10e c19c00 0037da 881798 3a96dd cccccc 767676 e74856 16c60c f9f1a5 3b78ff b4009e 61d6d6 f2f2f2",
      [("dark", "0c0c0c"), ("light", "ffffff")]),
     ("legacy-console", true,
      "000000 800000 008000 808000 000080 800080 008080 c0c0c0 808080 ff0000 00ff00 ffff00 0000ff ff00ff 00ffff ffffff",
      [("dark", "000000")]),
     ("vscode-dark", true,
      "000000 cd3131 0dbc79 e5e510 2472c8 bc3fbc 11a8cd e5e5e5 666666 f14c4c 23d18b f5f543 3b8eea d670d6 29b8db e5e5e5",
      [("dark", "1e1e1e")]),
     ("vscode-light", true,
      "000000 cd3131 107c10 949800 0451a5 bc05bc 0598bc 555555 666666 f14c4c 14ce14 b5ba00 3b8eea d670d6 29b8db a5a5a5",
      [("light", "ffffff")])]

  (* Severity 1.0, applied to linear RGB. *)
  val visions =
    [("normal", NONE),
     ("protanopia", SOME ((0.152286, 1.052583, ~0.204868), (0.114503, 0.786281, 0.099216),
                          (~0.003882, ~0.048116, 1.051998))),
     ("deuteranopia", SOME ((0.367322, 0.860646, ~0.227968), (0.280085, 0.672501, 0.047413),
                            (~0.011820, 0.042940, 0.968881))),
     ("tritanopia", SOME ((1.255528, ~0.076749, ~0.178779), (~0.078411, 0.930809, 0.147602),
                          (0.004733, 0.691367, 0.303900)))]

  fun hex s = case StringCvt.scanString (Int.scan StringCvt.HEX) s of SOME n => n | NONE => raise Fail ("bad colour: " ^ s)
  fun linear n = let val c = Real.fromInt n / 255.0
                 in if c <= 0.04045 then c / 12.92 else Math.pow ((c + 0.055) / 1.055, 2.4) end
  fun rgb s = (hex (String.substring (s, 0, 2)), hex (String.substring (s, 2, 2)), hex (String.substring (s, 4, 2)))
  fun linearRGB (r, g, b) = (linear r, linear g, linear b)
  fun seen (rgb, NONE) = rgb
    | seen ((r, g, b), SOME (x, y, z)) =
        let fun row (a, c, d) = Real.min (1.0, Real.max (0.0, a * r + c * g + d * b))
        in (row x, row y, row z) end
  fun luminance (r, g, b) = 0.2126 * r + 0.7152 * g + 0.0722 * b
  fun ratio (a, b) =
    let val la = luminance a and lb = luminance b
    in (Real.max (la, lb) + 0.05) / (Real.min (la, lb) + 0.05) end

  fun colour256 (n, colours) =
    if n < 16 then List.nth (colours, n)
    else if n < 232 then
      let val levels = Vector.fromList [0, 95, 135, 175, 215, 255]
          val i = n - 16
      in (Vector.sub (levels, i div 36), Vector.sub (levels, i div 6 mod 6), Vector.sub (levels, i mod 6)) end
    else let val v = 8 + 10 * (n - 232) in (v, v, v) end

  fun foreground (style, colours, bright) =
    let
      val ps = List.map (fn s => case Int.fromString s of SOME n => n | NONE => raise Fail ("bad style: " ^ style))
                        (String.tokens (fn c => c = #";") style)
      val bold = List.exists (fn n => n = 1) ps
      fun extended (38 :: 5 :: n :: _) = SOME (colour256 (n, colours))
        | extended (_ :: rest) = extended rest
        | extended [] = NONE
      fun ansi (p, found) =
        if p >= 30 andalso p <= 37 then SOME (List.nth (colours, p - 30 + (if bold andalso bright then 8 else 0)))
        else if p >= 90 andalso p <= 97 then SOME (List.nth (colours, p - 82)) else found
    in case extended ps of SOME c => SOME c | NONE => List.foldl ansi NONE ps end

  fun style theme (role, auto, dark, light) =
    case theme of
      "wide" => (case List.find (fn (r, _) => r = role) Color.wide of SOME (_, s) => s | NONE => auto)
    | "dark" => dark | "light" => light | _ => auto
  fun left n s = StringCvt.padRight #" " n s
  fun right n s = StringCvt.padLeft #" " n s

  fun main () =
    let
      val verbose = List.exists (fn a => a = "--verbose") (CommandLine.arguments ())
      val failures = ref 0 and total = ref 0
      val worst = ref ([] : (real * string) list)
      fun lower ((r, l), (s, m)) = r < s orelse (Real.== (r, s) andalso l < m)
      fun insert x [] = [x]
        | insert x (y :: ys) = if lower (x, y) then x :: y :: ys else y :: insert x ys
      fun measure theme (name, bright, palette, backgrounds) =
        let
          val colours = List.map rgb (String.tokens Char.isSpace palette)
          fun background kind =
            case List.find (fn (k, _) => k = kind) backgrounds of
              NONE => ()
            | SOME (_, bg) =>
                List.app (fn row as (role, _, _, _) =>
                  case foreground (style theme row, colours, bright) of
                    NONE => ()
                  | SOME fg => List.app (fn (vision, matrix) =>
                      let
                        val r = ratio (seen (linearRGB fg, matrix), seen (linearRGB (rgb bg), matrix))
                        val line = left 6 theme ^ " " ^ left 26 name ^ " " ^ left 5 kind ^ " " ^ left 20 role
                                   ^ " " ^ left 12 vision ^ " " ^ right 5 (Real.fmt (StringCvt.FIX (SOME 2)) r)
                        val floor = if vision = "normal" then 3.0 else 2.5
                        (* D24's measured exception: bold magenta in VS
                           Code's light palette is only 2.94:1 on white. *)
                        val floor = if name = "vscode-light" andalso fg = rgb "d670d6" then Real.min (floor, 2.9) else floor
                        val () = total := !total + 1
                        val all = insert (r, line) (!worst)
                        val () = worst := List.take (all, Int.min (5, length all))
                      in
                        if r < floor then (failures := !failures + 1; print ("FAIL " ^ line ^ "\n"))
                        else if verbose then print ("     " ^ line ^ "\n") else ()
                      end) visions) Color.table
        in List.app background (case theme of "dark" => ["dark"] | "light" => ["light"] | _ => ["dark", "light"]) end
      val () = if length Color.table >= 20 andalso length Color.wide >= 5 then () else raise Fail "incomplete colour tables"
      val () = List.app (fn theme => List.app (measure theme) palettes) ["auto", "wide", "dark", "light"]
      val () = print "the lowest ratios:\n"
      val () = List.app (fn (_, line) => print ("  " ^ line ^ "\n")) (!worst)
      val () = print ((if !failures = 0 then "PASS" else "FAIL") ^ " colour: " ^ Int.toString (!failures)
                      ^ " of " ^ Int.toString (!total) ^ " ratios below 3.0 (2.5 with a deficiency)\n")
    in OS.Process.exit (if !failures = 0 then OS.Process.success else OS.Process.failure) end
end

val () = Contrast.main ()
