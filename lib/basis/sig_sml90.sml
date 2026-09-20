(* What the 1990 library looked like, kept so that old programs still run.

   Before the Basis Library there was the library of the first Definition:
   `std_in` and `open_in` instead of `TextIO`, `explode` giving a list of
   one-character strings instead of a list of characters, and an exception
   for every arithmetic fault instead of `Overflow` and `Div`. This signature
   is that library, and nothing here is meant for a new program.

   The exceptions are raised where the new library raises `Overflow`, `Div`
   or `Domain`, and the arithmetic and text functions are the old spellings
   of what `MATH`, `CHAR` and `STRING` now offer.

   Area: The language

   Status: optional

   See also: `MATH`, `STRING`, `TEXT_IO`, `GENERAL`

   Limitation: `SML90/is-history`. The page that defined this signature is no
   longer among the specification's pages; it is transcribed from MLton's
   library, which follows it, in the order the page had. *)
signature SML90 =
sig
  (* The type of an input stream, as the old library had it. *)
  type instream

  (* The type of an output stream, as the old library had it. *)
  type outstream

  (* Raised where `abs` of the least integer would overflow. *)
  exception Abs

  (* Raised by division that overflows, and by division by zero. *)
  exception Quot

  (* Raised by multiplication that overflows. *)
  exception Prod

  (* Raised by negation that overflows. *)
  exception Neg

  (* Raised by addition that overflows. *)
  exception Sum

  (* Raised by subtraction that overflows. *)
  exception Diff

  (* Raised by `floor` of a number no integer can hold. *)
  exception Floor

  (* Raised by `exp` when the result is too large. *)
  exception Exp

  (* Raised by `sqrt` of a negative number.

     Reading: `SML90.Sqrt/is-its-own-exception`. `Sqrt`, `Ln` and `Ord` are
     exceptions of their own, as MLton and SML/NJ have them. Poly/ML makes
     all three `Overflow`, which loses what went wrong.

     Pinned by: `SML90.sqrt/Sqrt-negative` *)
  exception Sqrt

  (* Raised by `ln` of a number that is not positive.

     Reading: `SML90.Ln/is-its-own-exception`. As `Sqrt`: an exception of its
     own, not `Overflow`.

     Pinned by: `SML90.ln/Ln-zero` *)
  exception Ln

  (* Raised by `ord` of the empty string.

     Reading: `SML90.Ord/is-its-own-exception`. As `Sqrt`: an exception of
     its own, not `Overflow` and not `Subscript`.

     Pinned by: `SML90.ord/Ord-empty` *)
  exception Ord

  (* Raised by the remainder of a division by zero. *)
  exception Mod

  (* Raised when an I/O operation fails, carrying the message alone. *)
  exception Io of string

  (* Raised when the program is interrupted. *)
  exception Interrupt

  (* `sqrt x` is the square root of `x`.

     Raises: `Sqrt` if `x` is negative. *)
  val sqrt : real -> real

  (* `exp x` is `e` to the power `x`.

     Raises: `Exp` if the result is too large. *)
  val exp : real -> real

  (* `ln x` is the natural logarithm of `x`.

     Raises: `Ln` if `x` is not positive. *)
  val ln : real -> real

  (* `sin x` is the sine of `x` radians. *)
  val sin : real -> real

  (* `cos x` is the cosine of `x` radians. *)
  val cos : real -> real

  (* `arctan x` is the angle in radians whose tangent is `x`, between `~pi/2` and `pi/2`. *)
  val arctan : real -> real

  (* `ord s` is the code of the first character of `s`.

     Raises: `Ord` if `s` is empty.

     Example: `ord "a" = 97` *)
  val ord : string -> int

  (* `chr n` is the one-character string whose character has the code `n`.

     Raises: `Chr` if `n` is no character's code.

     Example: `chr 97 = "a"` *)
  val chr : int -> string

  (* `explode s` is the characters of `s`, each as a string of its own.

     The `explode` of `STRING` gives a list of characters; this is the older
     one.

     Example: `explode "ab" = ["a", "b"]` *)
  val explode : string -> string list

  (* `implode l` is the strings of `l`, one after another.

     Example: `implode ["a", "bc"] = "abc"` *)
  val implode : string list -> string

  (* `lookahead f` is the next character of `f` as a string, without removing it, or the empty string at the end.

     Raises: `Io` if the stream cannot be read. *)
  val lookahead : instream -> string

  (* The standard input of the program. *)
  val std_in : instream

  (* The standard output of the program. *)
  val std_out : outstream

  (* `open_in name` is a stream reading the file `name`.

     Raises: `Io` if the file cannot be opened. *)
  val open_in : string -> instream

  (* `open_out name` is a stream writing the file `name`, which it empties or creates.

     Raises: `Io` if the file cannot be opened. *)
  val open_out : string -> outstream

  (* `close_in f` closes the input stream `f`. *)
  val close_in : instream -> unit

  (* `close_out f` closes the output stream `f`. *)
  val close_out : outstream -> unit

  (* `input (f, n)` is at most `n` characters read from `f`, and fewer at the end of the stream.

     Raises: `Io` if the stream cannot be read. *)
  val input : instream * int -> string

  (* `output (f, s)` writes `s` to `f`.

     Raises: `Io` if the stream cannot be written. *)
  val output : outstream * string -> unit

  (* `end_of_stream f` is `true` when nothing is left to read in `f`. *)
  val end_of_stream : instream -> bool
end
