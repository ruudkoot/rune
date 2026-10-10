(* The palette (docs/plans/repl.md, D1 to D3; docs/diagnostics.md): the roles
   that the compiler, runedoc and the REPL give their text, the style of each
   in each theme, a user's restyling by RUNE_COLORS, whether a stream gets
   colour at all, and a style written as SGR escapes for a terminal, as CSS
   for a page, or as the rules of an editor's theme. A style is SGR
   parameters: 1 bold, 2 dim, 3 italic, 4 underline, 7 reverse, 9 struck
   through, 31 to 36 the colours, 91 to 96 their bright forms. The default
   theme keeps to bright red and magenta with weights, the only colours of
   the 16 that read on dark and light backgrounds alike in the palettes
   tests/color measures; the themes dark and light have more. Every role
   also carries a word or a mark, so that colour is never the only cue. *)
structure Color =
struct
  datatype theme = Auto | Dark | Light | Mono | NoTheme
  datatype choice = Always | Never | WhenTerminal

  (* role, its style in the themes auto, dark and light *)
  val table : (string * string * string * string) list = [
    ("text", "", "", ""),
    ("strong", "1", "1", "1"),
    ("faint", "2", "2", "2"),
    ("code", "1", "1", "1"),
    ("link", "4", "4", "4"),
    ("error", "1;91", "1;91", "1;31"),
    ("warning", "1;35", "1;95", "1;35"),
    ("note", "1", "1;96", "1;34"),
    ("help", "1", "1;92", "1;34"),
    ("success", "1", "92", "1;34"),
    ("selection", "7", "7", "7"),
    ("diag.location", "1", "1", "1"),
    ("diag.message", "1", "1", "1"),
    ("diag.gutter", "2", "36", "2"),
    ("diag.quote", "", "", ""),
    ("diag.secondary", "1", "1;96", "1;34"),
    ("diag.fixit.insert", "1", "92", "34"),
    ("diag.fixit.delete", "91", "91", "31"),
    ("diag.type.a", "1;4", "1;92", "1;34"),
    ("diag.type.b", "1;35", "1;95", "1;35"),
    ("repl.prompt", "1", "1;92", "1;34"),
    ("repl.prompt2", "2", "92", "34"),
    ("repl.input", "", "", ""),
    ("repl.name", "1", "1", "1"),
    ("repl.type", "", "96", "34"),
    ("repl.exception", "1;91", "1;91", "1;31"),
    ("repl.interrupt", "1;35", "1;95", "1;35"),
    ("repl.ui", "2", "2", "2"),
    ("repl.timing", "2", "2", "2"),
    ("repl.hint", "2", "2", "2"),
    ("repl.menu", "", "", ""),
    ("repl.menu.selected", "7", "7", "7"),
    ("repl.menu.detail", "2", "2", "2"),
    ("repl.search", "1", "1", "1"),
    ("repl.search.match", "4", "4", "4"),
    ("repl.bracket", "1;4", "1;4", "1;4"),
    ("repl.bracket.bad", "4;91", "4;91", "4;31"),
    ("repl.partial-line", "2", "2", "2"),
    ("syn.keyword", "1", "1;95", "1;34"),
    ("syn.ident", "", "", ""),
    ("syn.operator", "", "", ""),
    ("syn.punct", "", "", ""),
    ("syn.constructor", "", "33", "35"),
    ("syn.number", "", "33", "35"),
    ("syn.type", "", "96", "34"),
    ("syn.tyvar", "", "96", "34"),
    ("syn.module", "", "96", "34"),
    ("syn.string", "95", "92", "31"),
    ("syn.comment", "2", "2", "2"),
    ("syn.error", "4;91", "4;91", "4;31"),
    ("doc.heading", "1", "1", "1"),
    ("doc.code", "1", "1", "1"),
    ("doc.link", "4", "4", "4"),
    ("doc.label", "1", "1", "1"),
    ("doc.status", "2", "2", "2"),
    ("doc.deprecated", "2;9", "2;9", "2;9")]

  val roles = map #1 table

  fun isDigits s = s <> "" andalso CharVector.all (fn c => Char.isDigit c orelse c = #";") s

  fun env name = case OS.Process.getEnv name of SOME v => v | NONE => ""

  fun themeNamed "auto" = SOME Auto
    | themeNamed "dark" = SOME Dark
    | themeNamed "light" = SOME Light
    | themeNamed "mono" = SOME Mono
    | themeNamed "none" = SOME NoTheme
    | themeNamed _ = NONE

  (* RUNE_COLORS: a theme's name or not, then role=style pairs, all
     separated by colons; a pair whose style is not digits and semicolons is
     ignored, so the variable can write no other escape *)
  fun overrides () =
    let
      val fields = String.fields (fn c => c = #":") (env "RUNE_COLORS")
      fun pair f =
        case String.fields (fn c => c = #"=") f of
          [r, st] => if isDigits st orelse st = "" then SOME (r, st) else NONE
        | _ => NONE
    in
      (List.mapPartial themeNamed fields, List.mapPartial pair fields)
    end

  (* the theme: RUNE_COLORS's, else dark or light by COLORFGBG's
     background (a terminal's "fg;bg"), else auto *)
  fun chosenTheme () =
    case #1 (overrides ()) of
      t :: _ => t
    | [] =>
        case List.rev (String.fields (fn c => c = #";") (env "COLORFGBG")) of
          bg :: _ :: _ =>
            (case Int.fromString bg of
               SOME n => if n = 7 orelse n = 15 then Light else if n >= 0 andalso n <= 8 then Dark else Auto
             | NONE => Auto)
        | _ => Auto

  (* the attributes of a style alone: what mono keeps *)
  fun attributesOf st =
    let
      fun go [] = []
        | go (p :: rest) =
            if p = "38" orelse p = "48" orelse p = "58" then
              (case rest of
                 "5" :: _ :: more => go more
               | "2" :: _ :: _ :: _ :: more => go more
               | _ => [])
            else if List.exists (fn a => a = p) ["1", "2", "3", "4", "7", "9"] then p :: go rest
            else go rest
    in
      String.concatWith ";" (go (String.fields (fn c => c = #";") st))
    end

  (* a role's style in a theme as the table has it, whatever RUNE_COLORS says *)
  fun baseStyle (theme, role) =
    case List.find (fn (r, _, _, _) => r = role) table of
      SOME (_, a, d, l) => (case theme of Dark => d | Light => l | _ => a)
    | NONE => ""

  fun style (theme, role) =
    let
      val own = case List.find (fn (r, _) => r = role) (#2 (overrides ())) of
                  SOME (_, st) => st
                | NONE => baseStyle (theme, role)
    in
      case theme of NoTheme => "" | Mono => attributesOf own | _ => own
    end

  fun sgr (theme, role) = case style (theme, role) of "" => "" | st => "\027[" ^ st ^ "m"

  (* text in a role, the style reset after it *)
  fun paintIn theme role text =
    case (text, style (theme, role)) of
      ("", _) => ""
    | (_, "") => text
    | (_, st) => "\027[" ^ st ^ "m" ^ text ^ "\027[0m"

  fun truthy v = v <> "" andalso v <> "0" andalso v <> "false"

  fun onWindows () =
    List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
    handle _ => false

  (* the theme a stream gets, or NONE for no styles at all (D3) *)
  fun decide (choice, fd) =
    let
      val tty = (Posix.ProcEnv.isatty fd) handle _ => false
      (* a terminal without escapes: Emacs's M-x compile, cron, a console of
         Windows that refused VT, for which the VM set TERM=dumb *)
      val dumb = env "TERM" = "dumb" orelse (env "TERM" = "" andalso not (onWindows ()))
    in
      case choice of
        Never => NONE
      | Always => SOME (chosenTheme ())
      | WhenTerminal =>
          if env "NO_COLOR" <> "" then (if tty andalso not dumb then SOME Mono else NONE)
          else if truthy (env "FORCE_COLOR") orelse truthy (env "CLICOLOR_FORCE") then SOME (chosenTheme ())
          else if env "CLICOLOR" = "0" then NONE
          else if dumb then NONE
          else if not tty then NONE
          else SOME (chosenTheme ())
    end

  fun choiceNamed "always" = SOME Always
    | choiceNamed "never" = SOME Never
    | choiceNamed "auto" = SOME WhenTerminal
    | choiceNamed _ = NONE

  (* ---- pages and editors: the 16 colours of a reference terminal ---- *)

  (* Windows Terminal's Campbell on its dark background, and VS Code's light
     terminal on white: the colours 30 to 37, then 90 to 97 *)
  val darkColours = Vector.fromList ["0c0c0c", "c50f1f", "13a10e", "c19c00", "0037da", "881798", "3a96dd", "cccccc",
                                     "767676", "e74856", "16c60c", "f9f1a5", "3b78ff", "b4009e", "61d6d6", "f2f2f2"]
  val lightColours = Vector.fromList ["000000", "cd3131", "00bc00", "949800", "0451a5", "bc05bc", "0598bc", "555555",
                                      "666666", "cd3131", "14ce14", "b5ba00", "0451a5", "bc05bc", "0598bc", "a5a5a5"]

  (* a style's colour (hex) and attributes in a reference palette *)
  fun parts (colours, st) =
    let
      val ps = List.mapPartial Int.fromString (String.fields (fn c => c = #";") st)
      val colour = List.foldl (fn (p, acc) =>
                                 if p >= 30 andalso p <= 37 then SOME (Vector.sub (colours, p - 30))
                                 else if p >= 90 andalso p <= 97 then SOME (Vector.sub (colours, p - 82))
                                 else acc) NONE ps
      fun has n = List.exists (fn p => p = n) ps
    in
      {colour = colour, bold = has 1, dim = has 2, italic = has 3, underline = has 4,
       reverse = has 7, struck = has 9}
    end

  fun cssRules (colours, theme, background, foreground) =
    String.concat (map (fn role =>
      let
        val {colour, bold, dim, italic, underline, reverse, struck} = parts (colours, baseStyle (theme, role))
        val fg = getOpt (colour, "inherit")
        val (fg, bg) = if reverse then (background, if fg = "inherit" then foreground else fg) else (fg, "transparent")
        val name = String.translate (fn #"." => "-" | c => String.str c) role
        val deco = String.concatWith " " ((if underline then ["underline"] else []) @ (if struck then ["line-through"] else []))
      in
        "  --rune-" ^ name ^ "-color: " ^ (if String.isPrefix "inherit" fg then fg else "#" ^ fg) ^ ";\n" ^
        "  --rune-" ^ name ^ "-background: " ^ (if bg = "transparent" then bg else "#" ^ bg) ^ ";\n" ^
        "  --rune-" ^ name ^ "-weight: " ^ (if bold then "bold" else "normal") ^ ";\n" ^
        "  --rune-" ^ name ^ "-style: " ^ (if italic then "italic" else "normal") ^ ";\n" ^
        "  --rune-" ^ name ^ "-decoration: " ^ (if deco = "" then "none" else deco) ^ ";\n" ^
        "  --rune-" ^ name ^ "-opacity: " ^ (if dim then "0.7" else "1") ^ ";\n"
      end) roles)

  (* palette.css: a custom property of each role in the light theme, the
     dark theme's under prefers-color-scheme, and a class of each role *)
  fun css () =
    let
      fun cls role =
        let val n = String.translate (fn #"." => "-" | c => String.str c) role
        in
          ".rune-" ^ n ^ " { color: var(--rune-" ^ n ^ "-color); background: var(--rune-" ^ n ^ "-background); " ^
          "font-weight: var(--rune-" ^ n ^ "-weight); font-style: var(--rune-" ^ n ^ "-style); " ^
          "text-decoration: var(--rune-" ^ n ^ "-decoration); opacity: var(--rune-" ^ n ^ "-opacity); }\n"
        end
    in
      "/* The palette of docs/diagnostics.md, written by runedoc --palette: a role's\n" ^
      "   style as custom properties, the light theme's by default and the dark\n" ^
      "   theme's where the reader prefers dark, and a class of each role. */\n" ^
      ":root {\n" ^ cssRules (lightColours, Light, "ffffff", "333333") ^ "}\n" ^
      "@media (prefers-color-scheme: dark) {\n:root {\n" ^ cssRules (darkColours, Dark, "0c0c0c", "cccccc") ^ "}\n}\n" ^
      String.concat (map cls roles)
    end

  (* palette.json: the rules of a Monaco theme, dark and light, for the
     tokens rune-ide's highlighter names *)
  fun editorTheme () =
    let
      val tokens = [("keyword", "syn.keyword"), ("string", "syn.string"), ("number", "syn.number"),
                    ("comment", "syn.comment"), ("type.identifier", "syn.type"), ("operator", "syn.operator")]
      fun rules (colours, theme) =
        Json.Array (List.mapPartial (fn (token, role) =>
          let
            val {colour, bold, italic, underline, ...} = parts (colours, baseStyle (theme, role))
            val fontStyle = String.concatWith " " ((if bold then ["bold"] else []) @ (if italic then ["italic"] else [])
                                                   @ (if underline then ["underline"] else []))
            val fields = [("token", Json.String token)]
                         @ (case colour of SOME c => [("foreground", Json.String c)] | NONE => [])
                         @ (if fontStyle = "" then [] else [("fontStyle", Json.String fontStyle)])
          in
            SOME (Json.Object fields)
          end) tokens)
    in
      Json.encodeIndented 2 (Json.Object [("dark", Json.Object [("base", Json.String "vs-dark"),
                                                                ("rules", rules (darkColours, Dark))]),
                                         ("light", Json.Object [("base", Json.String "vs"),
                                                                ("rules", rules (lightColours, Light))])]) ^ "\n"
    end
end
