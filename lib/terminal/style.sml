(* Style: SGR escapes, the depth of colour, and when to style.

   Implements: STYLE *)
structure Style :> STYLE =
struct
  datatype color = Default | Ansi of int | Indexed of int | Rgb of int * int * int
  type style = {fg : color, bg : color, bold : bool, faint : bool, italic : bool,
                underline : bool, reverse : bool, struck : bool}

  val plain : style = {fg = Default, bg = Default, bold = false, faint = false, italic = false,
                       underline = false, reverse = false, struck = false}

  fun colorParameters (base, c) =
    case c of
      Default => []
    | Ansi n => if n < 8 then [Int.toString (base + n)] else [Int.toString (base + 60 + n - 8)]
    | Indexed n => [Int.toString (base + 8), "5", Int.toString n]
    | Rgb (r, g, b) => [Int.toString (base + 8), "2", Int.toString r, Int.toString g, Int.toString b]

  fun sgr ({fg, bg, bold, faint, italic, underline, reverse, struck} : style) =
    let
      fun flag (true, p) = [p]
        | flag (false, _) = []
      val ps = List.concat [flag (bold, "1"), flag (faint, "2"), flag (italic, "3"), flag (underline, "4"),
                            flag (reverse, "7"), flag (struck, "9"), colorParameters (30, fg), colorParameters (40, bg)]
    in
      "\027[" ^ String.concatWith ";" ("0" :: ps) ^ "m"
    end

  fun change (a : style, b : style) = if a = b then "" else sgr b

  fun parameters text =
    let
      fun numbers [] = []
        | numbers (f :: fs) = case Int.fromString f of
                                SOME n => if CharVector.all Char.isDigit f then n :: numbers fs else []
                              | NONE => []
      val ps = numbers (String.fields (fn c => c = #";") text)
      fun go ([], s) = s
        | go (p :: rest, s : style) =
            let
              fun set f = go (rest, f s)
              fun extended (rest, put) =
                case rest of
                  5 :: n :: more => if n >= 0 andalso n < 256 then go (more, put (Indexed n)) else go (more, s)
                | 2 :: r :: g :: b :: more =>
                    if List.all (fn x => x >= 0 andalso x < 256) [r, g, b] then go (more, put (Rgb (r, g, b)))
                    else go (more, s)
                | _ => s
              fun fg c = {fg = c, bg = #bg s, bold = #bold s, faint = #faint s, italic = #italic s,
                          underline = #underline s, reverse = #reverse s, struck = #struck s}
              fun bg c = {fg = #fg s, bg = c, bold = #bold s, faint = #faint s, italic = #italic s,
                          underline = #underline s, reverse = #reverse s, struck = #struck s}
            in
              case p of
                0 => go (rest, plain)
              | 1 => set (fn {fg, bg, faint, italic, underline, reverse, struck, ...} =>
                            {fg = fg, bg = bg, bold = true, faint = faint, italic = italic,
                             underline = underline, reverse = reverse, struck = struck})
              | 2 => set (fn {fg, bg, bold, italic, underline, reverse, struck, ...} =>
                            {fg = fg, bg = bg, bold = bold, faint = true, italic = italic,
                             underline = underline, reverse = reverse, struck = struck})
              | 3 => set (fn {fg, bg, bold, faint, underline, reverse, struck, ...} =>
                            {fg = fg, bg = bg, bold = bold, faint = faint, italic = true,
                             underline = underline, reverse = reverse, struck = struck})
              | 4 => set (fn {fg, bg, bold, faint, italic, reverse, struck, ...} =>
                            {fg = fg, bg = bg, bold = bold, faint = faint, italic = italic,
                             underline = true, reverse = reverse, struck = struck})
              | 7 => set (fn {fg, bg, bold, faint, italic, underline, struck, ...} =>
                            {fg = fg, bg = bg, bold = bold, faint = faint, italic = italic,
                             underline = underline, reverse = true, struck = struck})
              | 9 => set (fn {fg, bg, bold, faint, italic, underline, reverse, ...} =>
                            {fg = fg, bg = bg, bold = bold, faint = faint, italic = italic,
                             underline = underline, reverse = reverse, struck = true})
              | 22 => set (fn {fg, bg, italic, underline, reverse, struck, ...} =>
                             {fg = fg, bg = bg, bold = false, faint = false, italic = italic,
                              underline = underline, reverse = reverse, struck = struck})
              | 23 => set (fn {fg, bg, bold, faint, underline, reverse, struck, ...} =>
                             {fg = fg, bg = bg, bold = bold, faint = faint, italic = false,
                              underline = underline, reverse = reverse, struck = struck})
              | 24 => set (fn {fg, bg, bold, faint, italic, reverse, struck, ...} =>
                             {fg = fg, bg = bg, bold = bold, faint = faint, italic = italic,
                              underline = false, reverse = reverse, struck = struck})
              | 27 => set (fn {fg, bg, bold, faint, italic, underline, struck, ...} =>
                             {fg = fg, bg = bg, bold = bold, faint = faint, italic = italic,
                              underline = underline, reverse = false, struck = struck})
              | 29 => set (fn {fg, bg, bold, faint, italic, underline, reverse, ...} =>
                             {fg = fg, bg = bg, bold = bold, faint = faint, italic = italic,
                              underline = underline, reverse = reverse, struck = false})
              | 38 => extended (rest, fg)
              | 48 => extended (rest, bg)
              | 39 => go (rest, fg Default)
              | 49 => go (rest, bg Default)
              | _ =>
                  if p >= 30 andalso p <= 37 then go (rest, fg (Ansi (p - 30)))
                  else if p >= 90 andalso p <= 97 then go (rest, fg (Ansi (p - 90 + 8)))
                  else if p >= 40 andalso p <= 47 then go (rest, bg (Ansi (p - 40)))
                  else if p >= 100 andalso p <= 107 then go (rest, bg (Ansi (p - 100 + 8)))
                  else go (rest, s)
            end
    in
      go (ps, plain)
    end

  datatype depth = Mono | Colors16 | Colors256 | TrueColor

  fun env name = case OS.Process.getEnv name of SOME v => v | NONE => ""

  fun depth () =
    if env "NO_COLOR" <> "" then Mono
    else if env "COLORTERM" = "truecolor" orelse env "COLORTERM" = "24bit" then TrueColor
    else if String.isSuffix "256color" (env "TERM") then Colors256
    else Colors16

  (* xterm's levels of the 6x6x6 cube, and its 16 colours *)
  val levels = Vector.fromList [0, 95, 135, 175, 215, 255]
  val sixteen = Vector.fromList [(0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0), (0, 0, 238), (205, 0, 205),
                                 (0, 205, 205), (229, 229, 229), (127, 127, 127), (255, 0, 0), (0, 255, 0),
                                 (255, 255, 0), (92, 92, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]

  fun rgbOf n =
    if n < 16 then Vector.sub (sixteen, n)
    else if n < 232 then
      let val k = n - 16
      in (Vector.sub (levels, k div 36), Vector.sub (levels, k div 6 mod 6), Vector.sub (levels, k mod 6)) end
    else let val v = 8 + 10 * (n - 232) in (v, v, v) end

  fun distance ((r, g, b), (r', g', b')) =
    let val (dr, dg, db) = (r - r', g - g', b - b') in dr * dr + dg * dg + db * db end

  (* the nearest of the indices from..to *)
  fun nearest (rgb, from, to) =
    let
      fun go (i, best, d) =
        if i > to then best
        else let val d' = distance (rgb, rgbOf i) in if d' < d then go (i + 1, i, d') else go (i + 1, best, d) end
    in
      go (from + 1, from, distance (rgb, rgbOf from))
    end

  fun colorAt (d, c) =
    case (d, c) of
      (Mono, _) => Default
    | (_, Default) => Default
    | (TrueColor, _) => c
    | (Colors256, Rgb rgb) => Indexed (nearest (rgb, 16, 255))
    | (Colors256, _) => c
    | (Colors16, Rgb rgb) => Ansi (nearest (rgb, 0, 15))
    | (Colors16, Indexed n) => Ansi (if n < 16 then n else nearest (rgbOf n, 0, 15))
    | (Colors16, Ansi _) => c

  fun downgrade d ({fg, bg, bold, faint, italic, underline, reverse, struck} : style) =
    {fg = colorAt (d, fg), bg = colorAt (d, bg), bold = bold, faint = faint, italic = italic,
     underline = underline, reverse = reverse, struck = struck}

  datatype choice = Always | Never | Auto

  fun truthy v = v <> "" andalso v <> "0" andalso v <> "false"

  fun onWindows () =
    List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
    handle _ => false

  fun enabled (choice, isTerminal) =
    case choice of
      Always => true
    | Never => false
    | Auto =>
        let val dumb = env "TERM" = "dumb" orelse (env "TERM" = "" andalso not (onWindows ()))
        in
          if env "NO_COLOR" <> "" then isTerminal andalso not dumb
          else if truthy (env "FORCE_COLOR") orelse truthy (env "CLICOLOR_FORCE") then true
          else if env "CLICOLOR" = "0" then false
          else if dumb then false
          else isTerminal
        end
end
