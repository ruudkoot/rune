(* StringCvt over wide text: the helpers that build and take apart strings
   of WideChar.char, with the formats and readers of StringCvt. *)
structure RuneWideStringCvt =
struct
  type char = WideChar.char
  type string = WideString.string
  datatype radix = datatype StringCvt.radix
  datatype realfmt = datatype StringCvt.realfmt
  type ('a, 'b) reader = 'b -> ('a * 'b) option

  (* the state of scanString: the index of the next character *)
  type cs = int

  local
    (* n copies of c, for n > 0 *)
    fun copies (c, n) = WideString.implode (List.tabulate (n, fn _ => c))
  in
    fun padLeft c i s =
      if Int.>= (WideString.size s, i) then s
      else if Int.> (i, WideString.maxSize) then raise Size
      else WideString.^ (copies (c, Int.- (i, WideString.size s)), s)
    fun padRight c i s =
      if Int.>= (WideString.size s, i) then s
      else if Int.> (i, WideString.maxSize) then raise Size
      else WideString.^ (s, copies (c, Int.- (i, WideString.size s)))

    fun splitl p (getc : (char, 'a) reader) src =
      let
        fun go (src, acc) =
          case getc src of
            SOME (c, rest) => if p c then go (rest, c :: acc) else (WideString.implode (List.rev acc), src)
          | NONE => (WideString.implode (List.rev acc), src)
      in go (src, []) end

    fun takel p getc src = #1 (splitl p getc src)

    fun dropl p (getc : (char, 'a) reader) src =
      case getc src of
        SOME (c, rest) => if p c then dropl p getc rest else src
      | NONE => src

    fun skipWS getc src = dropl WideChar.isSpace getc src

    fun scanString (scan : (char, cs) reader -> ('a, cs) reader) s =
      let
        val n = WideString.size s
        fun getc i = if Int.< (i, n) then SOME (WideString.sub (s, i), Int.+ (i, 1)) else NONE
      in
        case scan getc 0 of
          SOME (v, _) => SOME v
        | NONE => NONE
      end
  end
end

(* WideStringCvt: the helpers of StringCvt over wide text, which build and
   take apart strings of `WideChar.char`.

   Implements: STRING_CVT where type char = WideChar.char where type string =
   WideString.string where type radix = StringCvt.radix where type realfmt =
   StringCvt.realfmt

   Status: extension

   Deviation: `WideStringCvt/not-in-the-specification`. The specification
   has no such structure: its `STRING_CVT` is written over `char` and
   `string` (the deviation `STRING_CVT/generic`), so a scanner of wide
   characters has neither `skipWS` nor `scanString` to build on. This one is
   `StringCvt` over the wide characters, with the same `radix`, `realfmt`
   and `reader`; white space is what `WideChar.isSpace` accepts.

   Pinned by: `WideStringCvt:STRING_CVT/generic` *)
structure WideStringCvt :> STRING_CVT
  where type char = WideChar.char
  where type string = WideString.string
  where type radix = StringCvt.radix
  where type realfmt = StringCvt.realfmt = RuneWideStringCvt
