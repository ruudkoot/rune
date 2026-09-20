(* The text of a character or string constant: a printable character of ASCII
   stands for itself, and anything else is an escape that Char.fromString and
   WideChar.fromString read back (\uXXXX, and \UXXXXXXXX above 0xFFFF). The
   compiler writes a constant of a type registered with `_overload ... via f`
   in this form and hands it to f (MatchComp). *)
structure Scon =
struct
  local
    val digits = "0123456789ABCDEF"
    fun hex (n, width) =
      let
        fun go (0, _, acc) = acc
          | go (k, i, acc) = go (k - 1, i div 16, String.str (String.sub (digits, i mod 16)) ^ acc)
      in go (width, n, "") end
  in
    fun escape n =
      if n = 92 then "\\\\"
      else if n = 34 then "\\\""
      else if n >= 32 andalso n <= 126 then String.str (Char.chr n)
      else if n <= 65535 then "\\u" ^ hex (n, 4)
      else "\\U" ^ hex (n, 8)
  end
  fun text points = String.concat (List.map escape points)
end
