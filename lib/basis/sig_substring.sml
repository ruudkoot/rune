(* A stretch of a string, without a copy of it: a base string and a start and
   a length inside it.

   Taking a substring apart is free where taking a string apart is not, so a
   program that scans text works on substrings and makes a string only of what
   it keeps. The three numbers are what `base` gives back; `full s` is the
   whole of `s`, `string ss` copies the stretch out. The functions that split
   come in pairs, one for each end: `l` takes from the left and `r` from the
   right.

   The signature is that of `Substring`, over `String`, and of the optional
   `WideSubstring`.

   Area: Text and characters

   See also: `STRING`, `CHAR`, `STRING_CVT`, `TEXT`, `MONO_VECTOR_SLICE`

   Erratum: `SUBSTRING/span-exception`. The specification does not say in the
   signature that `span` raises an exception, although its description does;
   the exception is `General.Span`. *)
signature SUBSTRING =
sig
  (* ---- Types ---- *)

  (* The type of substrings: a base string, a start in it and a length.

     Implementation: `Substring.substring/slice`. It is
     `CharVectorSlice.slice`, the slice of a vector of characters, so the two
     structures describe one type. *)
  type substring

  (* The type of the characters: `Char.char` for `Substring`. *)
  eqtype char

  (* The type of the strings these are substrings of. *)
  eqtype string

  (* ---- Taking a substring apart ---- *)

  (* `sub (ss, i)` is the character of `ss` at position `i`, counting from the start of the substring.

     Raises: `Subscript` if `i < 0` or `i >= size ss`. *)
  val sub : substring * int -> char

  (* `size ss` is the number of characters of `ss`. *)
  val size : substring -> int

  (* `base ss` is the triple of the string that `ss` is a stretch of, where it starts in that string, and how long it is.

     Law: `base (substring (s, i, n)) = (s, i, n)` *)
  val base : substring -> string * int * int

  (* ---- Making a substring ---- *)

  (* `extract (s, i, NONE)` is the stretch of `s` from position `i` to its end, and `extract (s, i, SOME n)` the `n` characters from `i`.

     Raises: `Subscript` if `i < 0`, if `i > String.size s`, or if `n` is
     given and `i + n > String.size s`.

     Implementation: `Substring.extract/no-overflow`. The bounds are tested
     so that they cannot overflow: an `i` and an `n` whose sum is no `int`
     raise `Subscript`, not `Overflow`. *)
  val extract : string * int * int option -> substring

  (* `substring (s, i, n)` is the `n` characters of `s` from position `i`.

     Law: `substring (s, i, n) = extract (s, i, SOME n)`

     Raises: `Subscript` if `i < 0`, `n < 0` or `i + n > String.size s`. *)
  val substring : string * int * int -> substring

  (* `full s` is the whole of `s` as a substring. *)
  val full : string -> substring

  (* `string ss` is the characters of `ss` as a string of their own.

     This is where the copy happens.

     Law: `string (full s) = s` *)
  val string : substring -> string

  (* `isEmpty ss` is `true` when `ss` has no characters.

     Law: `isEmpty ss = (size ss = 0)` *)
  val isEmpty : substring -> bool

  (* `getc ss` is `NONE` for the empty substring and `SOME (c, rest)` for the first character and what follows it.

     It has the shape of a `StringCvt.reader`, so a substring is a stream
     that a `scan` function can read from. *)
  val getc : substring -> (char * substring) option

  (* `first ss` is `SOME` of the first character of `ss`, or `NONE` when it is empty. *)
  val first : substring -> char option

  (* ---- Trimming and slicing ---- *)

  (* `triml k ss` is `ss` without its first `k` characters, or empty when it has at most `k`.

     Raises: `Subscript` if `k < 0`.

     Reading: `Substring.triml/Subscript-negative-k`. The specification says
     that the exception is raised "when `triml k` is evaluated", before the
     substring is given, so a partial application with a negative `k` raises
     at once. *)
  val triml : int -> substring -> substring

  (* `trimr k ss` is `ss` without its last `k` characters, or empty when it has at most `k`.

     Raises: `Subscript` if `k < 0`, when `trimr k` is evaluated. *)
  val trimr : int -> substring -> substring

  (* `slice (ss, i, NONE)` is the stretch of `ss` from position `i` on, and `slice (ss, i, SOME n)` the `n` characters from `i`.

     The positions are those of `ss`, not of its base string, and the result
     is a substring of the same base.

     Raises: `Subscript` if `i < 0`, if `i > size ss`, or if `n` is given and
     `i + n > size ss`. *)
  val slice : substring * int * int option -> substring

  (* ---- Putting substrings together ---- *)

  (* `concat l` is the string of the substrings of `l`, one after another.

     Raises: `Size` if the result would be longer than `String.maxSize`. *)
  val concat : substring list -> string

  (* `concatWith sep l` is the string of the substrings of `l` with `sep` between them.

     Raises: `Size` if the result would be longer than `String.maxSize`. *)
  val concatWith : string -> substring list -> string

  (* `explode ss` is the list of the characters of `ss`, in order. *)
  val explode : substring -> char list

  (* ---- Searching ---- *)

  (* `isPrefix s ss` is `true` when `ss` begins with the string `s`. *)
  val isPrefix : string -> substring -> bool

  (* `isSubstring s ss` is `true` when `s` occurs anywhere in `ss`. *)
  val isSubstring : string -> substring -> bool

  (* `isSuffix s ss` is `true` when `ss` ends with the string `s`. *)
  val isSuffix : string -> substring -> bool

  (* ---- Comparing ---- *)

  (* `compare (ss, tt)` orders two substrings by their characters, lexicographically.

     What they are substrings of does not matter: only the characters they
     hold.

     Law: `compare (ss, tt) = String.compare (string ss, string tt)` *)
  val compare : substring * substring -> order

  (* `collate cmp (ss, tt)` compares two substrings lexicographically with `cmp` for the characters. *)
  val collate : (char * char -> order) -> substring * substring -> order

  (* ---- Splitting ---- *)

  (* `splitl p ss` is the pair of the longest prefix of `ss` whose characters satisfy `p` and the rest.

     Law: `splitl p ss = (takel p ss, dropl p ss)` *)
  val splitl : (char -> bool) -> substring -> substring * substring

  (* `splitr p ss` is the pair of what comes before the longest suffix whose characters satisfy `p`, and that suffix. *)
  val splitr : (char -> bool) -> substring -> substring * substring

  (* `splitAt (ss, i)` is the pair of the first `i` characters of `ss` and the rest.

     Raises: `Subscript` if `i < 0` or `i > size ss`. *)
  val splitAt : substring * int -> substring * substring

  (* `dropl p ss` is `ss` without the characters at its front that satisfy `p`. *)
  val dropl : (char -> bool) -> substring -> substring

  (* `dropr p ss` is `ss` without the characters at its end that satisfy `p`. *)
  val dropr : (char -> bool) -> substring -> substring

  (* `takel p ss` is the longest prefix of `ss` whose characters satisfy `p`. *)
  val takel : (char -> bool) -> substring -> substring

  (* `taker p ss` is the longest suffix of `ss` whose characters satisfy `p`. *)
  val taker : (char -> bool) -> substring -> substring

  (* `position s ss` is the pair of what comes before the first occurrence of `s` in `ss`, and the rest from that occurrence on.

     When `s` does not occur, the first component is all of `ss` and the
     second is empty at its end, so the two always fit back together. The
     empty string occurs at once, which makes the first component empty.

     Law: `let val (pref, suff) = position s ss in concat [pref, suff] =
     string ss end`

     Erratum: `Substring.position/none-ends-after-the-substring`. The
     specification describes the second component as "the longest suffix of
     `ss` that has `s` as a prefix", and then writes the condition on the
     index in a way that forgets that the occurrence has to lie inside `ss`:
     an `s` that begins in `ss` and runs past its end is not an occurrence. *)
  val position : string -> substring -> substring * substring

  (* `span (ss, tt)` is the stretch from the start of `ss` to the end of `tt`.

     Both must be substrings of one string, and `tt` must not end before `ss`
     begins; this is how the pieces that `splitl` and `position` gave are put
     back together.

     Raises: `Span` if they are substrings of different strings, or if `tt`
     ends before `ss` starts.

     Reading: `Substring.span/equal-strings-built-separately`. "Unless `s <>
     s'`" is read as a comparison of the base strings by value: two equal
     strings that were built separately count as one base. *)
  val span : substring * substring -> substring

  (* ---- Transforming ---- *)

  (* `translate f ss` applies `f` to each character of `ss`, from left to right, and appends the strings it gives. *)
  val translate : (char -> string) -> substring -> string

  (* `tokens p ss` is the non-empty pieces of `ss` between the characters that satisfy `p`.

     A run of delimiters counts as one, and the pieces are substrings of the
     same base string, so nothing is copied.

     Law: `tokens p ss = List.filter (fn t => not (isEmpty t)) (fields p ss)` *)
  val tokens : (char -> bool) -> substring -> substring list

  (* `fields p ss` is the pieces of `ss` that the characters satisfying `p` separate.

     Every delimiter ends a field, so `n` delimiters give `n + 1` fields,
     empty ones included. *)
  val fields : (char -> bool) -> substring -> substring list

  (* ---- Traversing ---- *)

  (* `app f ss` applies `f` to every character of `ss`, from left to right, for its effect. *)
  val app : (char -> unit) -> substring -> unit

  (* `foldl f init ss` combines the characters of `ss` from the left, as `List.foldl` does. *)
  val foldl : (char * 'a -> 'a) -> 'a -> substring -> 'a

  (* `foldr f init ss` combines the characters of `ss` from the right, as `List.foldr` does. *)
  val foldr : (char * 'a -> 'a) -> 'a -> substring -> 'a
end
