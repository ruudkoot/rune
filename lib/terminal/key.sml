(* Key: the decoder of the bytes a terminal sends.

   Implements: KEY *)
structure Key :> KEY =
struct
  datatype name =
      Up | Down | Left | Right | Home | End | Insert | Delete | PageUp | PageDown
    | Enter | Tab | Backspace | Escape | F of int
  type mods = {shift : bool, alt : bool, ctrl : bool}
  datatype event =
      Char of int * mods
    | Named of name * mods
    | Paste of string
    | CursorAt of int * int
    | Reply of string
    | Focus of bool
    | Unknown of string

  val none = {shift = false, alt = false, ctrl = false}
  val ctrl = {shift = false, alt = false, ctrl = true}
  fun withAlt ({shift, ctrl, ...} : mods) = {shift = shift, alt = true, ctrl = ctrl}

  (* the bytes not yet decoded, and the text of a paste begun *)
  type decoder = {buf : string, paste : string option}
  val empty = {buf = "", paste = NONE}
  fun pending ({buf, paste} : decoder) = buf <> "" orelse isSome paste

  val pasteEnd = "\027[201~"

  fun byte (s, i) = Char.ord (String.sub (s, i))

  (* xterm's modifier parameter: 1 + shift 1, alt 2, ctrl 4, meta 8 *)
  fun modsOf m =
    if m <= 1 then none
    else
      let val b = m - 1
      in {shift = b mod 2 = 1, alt = (b div 2) mod 2 = 1 orelse (b div 8) mod 2 = 1, ctrl = (b div 4) mod 2 = 1} end

  (* a control character, or DEL *)
  fun control c =
    case c of
      0 => Char (Char.ord #"@", ctrl)
    | 8 => Named (Backspace, ctrl)
    | 9 => Named (Tab, none)
    | 10 => Char (Char.ord #"j", ctrl)
    | 13 => Named (Enter, none)
    | 127 => Named (Backspace, none)
    | _ => if c < 27 then Char (0x60 + c, ctrl) else Char (Char.ord #"\\" + c - 28, ctrl)

  fun addAlt (Char (c, m)) = Char (c, withAlt m)
    | addAlt (Named (n, m)) = Named (n, withAlt m)
    | addAlt e = e

  (* the bytes a UTF-8 character that begins with lead needs, or 1 *)
  fun utf8Length lead =
    if lead >= 0xC2 andalso lead <= 0xDF then 2
    else if lead >= 0xE0 andalso lead <= 0xEF then 3
    else if lead >= 0xF0 andalso lead <= 0xF4 then 4
    else 1

  (* Whether the bytes of s from i are the beginning of a UTF-8 character
     not yet complete. *)
  fun incomplete (s, i) =
    let
      val need = utf8Length (byte (s, i))
      fun cont j = j >= size s orelse (byte (s, j) >= 0x80 andalso byte (s, j) <= 0xBF andalso cont (j + 1))
    in
      need > 1 andalso size s - i < need andalso cont (i + 1)
    end

  (* the numbers of a CSI's parameters: each up to a colon (kitty's
     subfields), 0 where empty *)
  fun numbers p =
    map (fn f => case Int.fromString (hd (String.fields (fn c => c = #":") f)) of SOME n => n | NONE => 0)
        (String.fields (fn c => c = #";") p)

  fun tilde n =
    case n of
      1 => SOME Home | 7 => SOME Home | 2 => SOME Insert | 3 => SOME Delete | 4 => SOME End | 8 => SOME End
    | 5 => SOME PageUp | 6 => SOME PageDown
    | _ =>
        if n >= 11 andalso n <= 15 then SOME (F (n - 10))
        else if n >= 17 andalso n <= 21 then SOME (F (n - 11))
        else if n >= 23 andalso n <= 26 then SOME (F (n - 12))
        else if n >= 28 andalso n <= 29 then SOME (F (n - 13))
        else if n >= 31 andalso n <= 34 then SOME (F (n - 14))
        else NONE

  (* a key of the kitty protocol or of modifyOtherKeys: a code point *)
  fun coded (code, m) =
    let val {alt, ctrl, ...} = modsOf m
        val mods = {shift = false, alt = alt, ctrl = ctrl}
    in
      case code of
        13 => Named (Enter, modsOf m)
      | 9 => Named (Tab, modsOf m)
      | 127 => Named (Backspace, modsOf m)
      | 8 => Named (Backspace, modsOf m)
      | 27 => Named (Escape, modsOf m)
      | _ => Char (code, mods)
    end

  (* A CSI sequence whole: its parameters, intermediates and final byte. *)
  fun csi (whole, params, inter, final) =
    if params <> "" andalso Char.contains "?<=>" (String.sub (params, 0)) then Reply whole
    else if inter <> "" then Unknown whole
    else
      let
        val ns = if params = "" then [] else numbers params
        fun modAt i = if List.length ns > i then List.nth (ns, i) else 1
        fun named n = Named (n, modsOf (modAt 1))
      in
        case final of
          #"A" => named Up
        | #"B" => named Down
        | #"C" => named Right
        | #"D" => named Left
        | #"H" => named Home
        | #"F" => named End
        | #"P" => named (F 1)
        | #"Q" => named (F 2)
        | #"S" => named (F 4)
        | #"R" => (case ns of [r, c] => CursorAt (r, c) | _ => named (F 3))
        | #"Z" => Named (Tab, {shift = true, alt = false, ctrl = false})
        | #"I" => if ns = [] then Focus true else Unknown whole
        | #"O" => if ns = [] then Focus false else Unknown whole
        | #"u" => (case ns of
                     [code] => coded (code, 1)
                   | code :: m :: _ => coded (code, m)
                   | [] => Unknown whole)
        | #"~" => (case ns of
                     27 :: m :: code :: _ => coded (code, m)
                   | n :: _ => (case tilde n of SOME k => named k | NONE => Unknown whole)
                   | [] => Unknown whole)
        | _ => Unknown whole
      end

  fun ss3 (whole, c) =
    case c of
      #"A" => Named (Up, none) | #"B" => Named (Down, none) | #"C" => Named (Right, none) | #"D" => Named (Left, none)
    | #"H" => Named (Home, none) | #"F" => Named (End, none) | #"M" => Named (Enter, none)
    | #"P" => Named (F 1, none) | #"Q" => Named (F 2, none) | #"R" => Named (F 3, none) | #"S" => Named (F 4, none)
    | _ => Unknown whole

  (* where s has t from i, or NONE *)
  fun find (s, t, i) =
    if i + size t > size s then NONE
    else if String.sub (s, i) = String.sub (t, 0) andalso String.substring (s, i, size t) = t then SOME i
    else find (s, t, i + 1)

  (* the longest end of s that begins t: what may be the start of the
     paste's end marker *)
  fun overlap (s, t) =
    let
      fun go k = if k = 0 then 0
                 else if String.isPrefix (String.extract (s, size s - k, NONE)) t then k
                 else go (k - 1)
    in
      go (Int.min (size s, size t - 1))
    end

  datatype step = Event of event * int   (* an event and the bytes it took *)
                | Wait                   (* the bytes are a key not yet complete *)
                | Begin of int           (* a paste begins, after so many bytes *)

  (* one key from s at i *)
  fun step (s, i) =
    let val c = byte (s, i)
    in
      if c = 27 then
        if i + 1 >= size s then Wait
        else
          case String.sub (s, i + 1) of
            #"[" =>
              let
                fun scan (j, stage) =
                  if j >= size s then Wait
                  else
                    let val b = byte (s, j)
                    in
                      if stage = 0 andalso b >= 0x30 andalso b <= 0x3F then scan (j + 1, 0)
                      else if b >= 0x20 andalso b <= 0x2F then scan (j + 1, 1)
                      else if b >= 0x40 andalso b <= 0x7E then
                        let
                          val whole = String.substring (s, i, j - i + 1)
                          val body = String.substring (s, i + 2, j - i - 2)
                          fun split k = if k < size body andalso Char.ord (String.sub (body, k)) <= 0x3F then split (k + 1) else k
                          val p = split 0
                        in
                          if whole = "\027[200~" then Begin (j - i + 1)
                          else Event (csi (whole, String.substring (body, 0, p), String.extract (body, p, NONE), Char.chr b),
                                      j - i + 1)
                        end
                      else (* not a CSI: what came before this byte is unknown *)
                        Event (Unknown (String.substring (s, i, j - i)), j - i)
                    end
              in
                scan (i + 2, 0)
              end
          | #"O" =>
              if i + 2 >= size s then Wait
              else Event (ss3 (String.substring (s, i, 3), String.sub (s, i + 2)), 3)
          | #"\027" => Event (Named (Escape, none), 1)
          | _ =>
              (case step (s, i + 1) of
                 Event (e, k) => Event (addAlt e, k + 1)
               | Wait => Wait
               | Begin k => Begin k)
      else if c < 32 orelse c = 127 then Event (control c, 1)
      else if c < 128 then Event (Char (c, none), 1)
      else if incomplete (s, i) then Wait
      else let val (cp, k) = Utf8.next (s, i) in Event (Char (cp, none), k) end
    end

  (* by index, so that a long run of text costs its length *)
  fun feed ({buf, paste} : decoder, more) =
    let
      val s = buf ^ more
      fun go (i, paste, acc) =
        case paste of
          SOME text =>
            (case find (s, pasteEnd, i) of
               SOME j => go (j + size pasteEnd, NONE, Paste (text ^ String.substring (s, i, j - i)) :: acc)
             | NONE =>
                 let
                   val rest = String.extract (s, i, NONE)
                   val keep = overlap (rest, pasteEnd)
                 in
                   (rev acc, {buf = String.extract (rest, size rest - keep, NONE),
                              paste = SOME (text ^ String.substring (rest, 0, size rest - keep))})
                 end)
        | NONE =>
            if i >= size s then (rev acc, empty)
            else
              case step (s, i) of
                Event (e, k) => go (i + k, NONE, e :: acc)
              | Begin k => go (i + k, SOME "", acc)
              | Wait => (rev acc, {buf = String.extract (s, i, NONE), paste = NONE})
    in
      go (0, paste, [])
    end

  fun flush ({buf, paste} : decoder) =
    case paste of
      SOME text => ([Paste (text ^ buf)], empty)
    | NONE =>
        if buf = "" then ([], empty)
        else if buf = "\027" then ([Named (Escape, none)], empty)
        else if buf = "\027[" then ([Char (Char.ord #"[", withAlt none)], empty)
        else if buf = "\027O" then ([Char (Char.ord #"O", withAlt none)], empty)
        else if String.isPrefix "\027[" buf then ([Unknown buf], empty)
        else if String.isPrefix "\027" buf then ([Char (0xFFFD, withAlt none)], empty)
        else ([Char (0xFFFD, none)], empty)

  fun prefix ({shift, alt, ctrl} : mods) =
    (if ctrl then "C-" else "") ^ (if alt then "M-" else "") ^ (if shift then "S-" else "")

  fun nameOf n =
    case n of
      Up => "Up" | Down => "Down" | Left => "Left" | Right => "Right" | Home => "Home" | End => "End"
    | Insert => "Insert" | Delete => "Delete" | PageUp => "PageUp" | PageDown => "PageDown"
    | Enter => "Enter" | Tab => "Tab" | Backspace => "Backspace" | Escape => "Escape"
    | F k => "F" ^ Int.toString k

  fun toString e =
    case e of
      Char (32, m) => prefix m ^ "SPC"
    | Char (c, m) => prefix m ^ (Utf8.encode c handle Chr => "U+" ^ Int.fmt StringCvt.HEX c)
    | Named (n, {shift, alt, ctrl}) =>
        (if ctrl then "C-" else "") ^ (if alt then "M-" else "") ^ (if shift then "S-" else "") ^ nameOf n
    | Paste s => "Paste " ^ String.toString s
    | CursorAt (r, c) => "CursorAt " ^ Int.toString r ^ "," ^ Int.toString c
    | Reply s => "Reply " ^ String.toString s
    | Focus b => "Focus " ^ Bool.toString b
    | Unknown s => "Unknown " ^ String.toString s
end
