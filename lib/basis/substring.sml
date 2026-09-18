(* Substring: a string, a start index and a length. *)
structure Substring =
struct
  type char = char
  type string = string
  datatype substring = SS of string * int * int

  local
    val charAt = _prim "string_sub" : string * int -> char
  in
    fun base (SS t) = t
    fun string (SS (s, i, n)) = substring (s, i, n)
    fun size (SS (_, _, n)) = n
    fun isEmpty (SS (_, _, n)) = n = 0

    (* The checks are written so that they cannot overflow: n > size s - i,
       not i + n > size s. *)
    fun extract (s, i, NONE) =
        let val len = String.size s
        in if i < 0 orelse i > len then raise Subscript else SS (s, i, len - i) end
      | extract (s, i, SOME n) =
        let val len = String.size s
        in if i < 0 orelse n < 0 orelse i > len orelse n > len - i then raise Subscript else SS (s, i, n) end
    fun substring (s, i, n) = extract (s, i, SOME n)
    fun full s = SS (s, 0, String.size s)

    fun getc (SS (s, i, n)) = if n = 0 then NONE else SOME (charAt (s, i), SS (s, i + 1, n - 1))
    fun first (SS (s, i, n)) = if n = 0 then NONE else SOME (charAt (s, i))

    (* "This exception is raised when triml k is evaluated." *)
    fun triml k =
      if k < 0 then raise Subscript
      else fn SS (s, i, n) => if k >= n then SS (s, i + n, 0) else SS (s, i + k, n - k)
    fun trimr k =
      if k < 0 then raise Subscript
      else fn SS (s, i, n) => if k >= n then SS (s, i, 0) else SS (s, i, n - k)

    fun slice (SS (s, i, n), j, NONE) =
        if j < 0 orelse j > n then raise Subscript else SS (s, i + j, n - j)
      | slice (SS (s, i, n), j, SOME m) =
        if j < 0 orelse m < 0 orelse j > n orelse m > n - j then raise Subscript else SS (s, i + j, m)

    fun sub (SS (s, i, n), j) = if j < 0 orelse j >= n then raise Subscript else charAt (s, i + j)

    fun concat l = String.concat (List.map string l)
    fun concatWith sep l = String.concatWith sep (List.map string l)

    fun foldl f init (SS (s, i, n)) =
      let fun go (k, acc) = if k >= n then acc else go (k + 1, f (charAt (s, i + k), acc))
      in go (0, init) end
    fun foldr f init (SS (s, i, n)) =
      let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (charAt (s, i + k), acc))
      in go (n - 1, init) end
    fun app f ss = foldl (fn (c, ()) => f c) () ss
    fun explode ss = foldr (op ::) [] ss

    fun isPrefix p ss = String.isPrefix p (string ss)
    fun isSubstring p ss = String.isSubstring p (string ss)
    fun isSuffix p ss = String.isSuffix p (string ss)
    fun compare (a, b) = String.compare (string a, string b)
    fun collate cmp (a, b) = String.collate cmp (string a, string b)

    fun splitl p (SS (s, i, n)) =
      let fun go k = if k < n andalso p (charAt (s, i + k)) then go (k + 1) else k
          val k = go 0
      in (SS (s, i, k), SS (s, i + k, n - k)) end
    fun splitr p (SS (s, i, n)) =
      let fun go k = if k > 0 andalso p (charAt (s, i + k - 1)) then go (k - 1) else k
          val k = go n
      in (SS (s, i, k), SS (s, i + k, n - k)) end
    fun splitAt (SS (s, i, n), k) =
      if k < 0 orelse k > n then raise Subscript else (SS (s, i, k), SS (s, i + k, n - k))
    fun dropl p ss = #2 (splitl p ss)
    fun dropr p ss = #1 (splitr p ss)
    fun takel p ss = #1 (splitl p ss)
    fun taker p ss = #2 (splitr p ss)

    (* (pref, suff): suff is the longest suffix of ss that starts with t, or
       the empty substring at the end of ss when t does not occur. *)
    fun position t (SS (s, i, n)) =
      let
        val m = String.size t
        fun matches (k, j) = j >= m orelse (charAt (s, i + k + j) = charAt (t, j) andalso matches (k, j + 1))
        fun go k = if k + m > n then n else if matches (k, 0) then k else go (k + 1)
        val k = go 0
      in (SS (s, i, k), SS (s, i + k, n - k)) end

    (* "raises Span if s <> s' or i'+n' < i" *)
    fun span (SS (s, i, _), SS (s', i', n')) =
      if s <> s' orelse i' + n' < i then raise Span else SS (s, i, i' + n' - i)

    (* f is applied from left to right *)
    fun translate f ss = String.concat (List.rev (foldl (fn (c, acc) => f c :: acc) [] ss))

    (* fields: every delimiter ends a field; tokens: the nonempty fields *)
    fun fields p (SS (s, i, n)) =
      let
        fun go (start, k, acc) =
          if k >= n then List.rev (SS (s, i + start, k - start) :: acc)
          else if p (charAt (s, i + k)) then go (k + 1, k + 1, SS (s, i + start, k - start) :: acc)
          else go (start, k + 1, acc)
      in go (0, 0, []) end
    fun tokens p ss = List.filter (fn t => not (isEmpty t)) (fields p ss)
  end
end

(* the top-level environment has the type *)
type substring = Substring.substring
