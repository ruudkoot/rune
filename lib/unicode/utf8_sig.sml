(* UTF-8: code points written as bytes and read back, strictly.

   A string holds bytes, and text in it is UTF-8 by convention. Reading is
   strict in the sense of the Unicode Standard (its section 3.9): an
   overlong form, a surrogate, a code point past 0x10FFFF, a sequence cut
   short and a continuation byte with no lead are ill-formed, and `decode`
   gives `NONE` for them. Where a program must read whatever bytes it gets
   -- what a terminal sends, a file of unknown origin -- `next` and the
   functions over whole strings never fail: they read each ill-formed part
   as one replacement character, U+FFFD, as long as the maximal subpart the
   standard recommends, so that the same bytes give the same characters in
   every program that follows it.

   Area: Unicode *)
signature UTF8 =
sig
  (* The replacement character, U+FFFD, which the readers that never fail
     give for each ill-formed part.

     Example: `replacement = 0xFFFD` *)
  val replacement : int

  (* `isScalar c` is whether `c` is a Unicode scalar value, a code point
     that UTF-8 can write: from 0 to 0x10FFFF, and not a surrogate (0xD800
     to 0xDFFF).

     Example: `isScalar 0x10FFFF andalso not (isScalar 0xD800)` *)
  val isScalar : int -> bool

  (* `encode c` is the bytes of the code point `c`: one for ASCII, up to
     four.

     Raises: `Chr` if `c` is not a scalar value.

     Example: `encode 0x20AC = "\226\130\172"` *)
  val encode : int -> string

  (* `decode (s, i)` is the code point whose bytes begin at byte `i` of
     `s`, and how many bytes it has; `NONE` when the bytes there are
     ill-formed, or `i` is the end of `s`.

     Raises: `Subscript` if `i < 0` or `i > size s`.

     Example: `decode ("\226\130\172", 0) = SOME (0x20AC, 3)`

     Example: `decode ("\192\128", 0) = NONE`, an overlong form of 0 *)
  val decode : string * int -> (int * int) option

  (* `next (s, i)` is the code point at byte `i` of `s` and its length, or
     `replacement` where the bytes there are ill-formed.

     A well-formed code point is what `decode` gives; an ill-formed part is
     as long as its maximal subpart.

     Raises: `Subscript` unless `0 <= i` and `i < size s`.

     Example: `next ("\240\128\128", 0) = (0xFFFD, 1)` *)
  val next : string * int -> int * int

  (* `isValid s` is whether all of `s` is well-formed UTF-8.

     Example: `isValid "caf\195\169" andalso not (isValid "\237\160\128")` *)
  val isValid : string -> bool

  (* `explode s` is the code points of `s`, read by `next`.

     Law: `implode (explode s) = s` when `isValid s`

     Example: `explode "a\195\169\255" = [0x61, 0xE9, 0xFFFD]` *)
  val explode : string -> int list

  (* `implode cs` is the bytes of the code points `cs`, one after another.

     Raises: `Chr` if one of `cs` is not a scalar value.

     Law: `explode (implode cs) = cs` when `List.all isScalar cs` *)
  val implode : int list -> string

  (* `foldl f init s` is `f` applied to the code points of `s` from the
     left, read by `next`, starting from `init`.

     Example: `foldl (fn (c, n) => c + n) 0 "\195\169" = 0xE9` *)
  val foldl : (int * 'a -> 'a) -> 'a -> string -> 'a

  (* `size s` is the number of code points of `s`, read by `next`.

     Example: `size "caf\195\169" = 4` *)
  val size : string -> int
end
