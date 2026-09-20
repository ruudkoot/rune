(* The types, exceptions and values of the top-level environment that belong
   to no other structure.

   Everything `General` specifies is also available without a structure in
   front, and `General` is the one structure whose members the language itself
   uses: `raise Bind` is what a `val` binding does when its pattern does not
   match, `Div` is what division by zero raises. The exceptions here are those
   the specification calls the standard ones; an implementation may raise them
   from anywhere its description says it may.

   Area: The language

   See also: `OPTION`, `LIST`, `STRING` *)
signature GENERAL =
sig
  (* ---- Types ---- *)

  (* The type with one value, the empty tuple `()`, which is what a function
     that is called for its effect returns. *)
  eqtype unit

  (* The type of exception values, the top-level `exn`.

     An exception declaration adds a constructor to it, so the type is open:
     it grows as a program declares exceptions, and a value of it cannot be
     taken apart except by a pattern that names a constructor. It does not
     admit equality.

     Erratum: `GENERAL/exn-spec`. The specification writes `type exn = exn`,
     which is read as: the type of this structure is the top-level one. *)
  type exn = exn

  (* ---- The standard exceptions ---- *)

  (* Raised when the pattern of a `val` binding does not match the value. *)
  exception Bind

  (* Raised when no rule of a `case`, a `fn` or a `handle` matches. *)
  exception Match

  (* Raised by `Char.chr`, `Char.succ` and `Char.pred` for a code that is no
     character. *)
  exception Chr

  (* Raised by `div`, `mod`, `quot` and `rem` when the divisor is zero. *)
  exception Div

  (* Raised by a function that is given an argument outside its domain, such
     as `Real.floor` of a NaN or `IntInf.log2` of a number that is not
     positive.

     Erratum: `GENERAL/domain-math`. The specification says that the functions
     of `MATH` raise it. They do not: a mathematical function answers with a
     NaN or an infinity instead, and it is `REAL` and `INT_INF` that raise
     `Domain`.

     Pinned by: `General.Domain/Real.floor-nan` *)
  exception Domain

  (* Raised where a program has nothing better to raise; its argument says
     what went wrong. *)
  exception Fail of string

  (* Raised by an arithmetic operation whose result is not representable, such
     as `Int.+` beyond `Int.maxInt`.

     Implementation: `General.Overflow/bounded-int`. Whether an operation can
     overflow depends on the precision of the type: nothing overflows at
     `IntInf.int`, which has none. *)
  exception Overflow

  (* Raised by an operation that would make a string, a vector or an array
     longer than the implementation allows, such as `Array.array` of a length
     above `Array.maxLen`.

     Implementation: `General.Size/maxLen`. What is too large depends on the
     type: `String.maxSize` and `Array.maxLen` say where the bound is.

     Where `Array.maxLen + 1` is no `int` nothing can ask for an array that is
     too long, and the suite's check raises `Size` itself there; here it is an
     `int`, and `Array.array` raises it. *)
  exception Size

  (* Raised by `Substring.span` when its two arguments are not substrings of
     one string, or lie the wrong way round. *)
  exception Span

  (* Raised by an operation that is given an index or a length outside what
     the sequence has, such as `String.sub` or `List.nth`. *)
  exception Subscript

  (* ---- Naming an exception ---- *)

  (* `exnName ex` is the name of the constructor of `ex`, without a structure
     in front and without its argument.

     Example: `exnName (Fail "why") = "Fail"`, and `exnName Subscript =
     "Subscript"`.

     Reading: `General.exnName/alias-either-name`. For an exception declared
     to be another one (`exception E2 = E1`) either name is an answer: the two
     constructors are the same exception, and which name the implementation
     kept is its own business. *)
  val exnName : exn -> string

  (* `exnMessage ex` is a message that describes `ex`, for a program that
     reports an exception it cannot handle.

     Reading: `General.exnMessage/returns-*`. "The precise format of the
     message may vary between implementations and locales", so only this is
     required of it: it returns rather than raising, and it contains
     `exnName ex`.

     Erratum: `GENERAL/exnMessage-example`. The specification's example
     `exnMessage Div = "Div"` contradicts that freedom; it is an example of
     one possible format, not a rule.

     Implementation: `General.exnMessage/format`. `"Fail: "` and the argument
     for a `Fail`, and `exnName ex` for everything else.

     Example: `exnMessage (Fail "why") = "Fail: why"` *)
  val exnMessage : exn -> string

  (* ---- Comparison ---- *)

  (* What a comparison answers: the result of `Int.compare`, `String.compare`
     and every other `compare` and `collate` of the library. It is the
     top-level `order`. *)
  datatype order = LESS | EQUAL | GREATER

  (* ---- Operators ---- *)

  (* `!r` is the value that the reference `r` holds. *)
  val ! : 'a ref -> 'a

  (* `r := v` makes the reference `r` hold `v`.

     It is infix with precedence 3. *)
  val := : 'a ref * 'a -> unit

  (* `(f o g) x` is `f (g x)`: the composition of two functions.

     It is infix with precedence 3.

     Example: `(Int.toString o (fn x => x + 1)) 1 = "2"` *)
  val o : ('b -> 'c) * ('a -> 'b) -> 'a -> 'c

  (* `e before e'` is `e`, after `e'` has been evaluated for its effect.

     It is infix with precedence 0, the loosest there is, so that
     `x before print "done"` needs no parentheses.

     Law: `e before e' = (fn (a, ()) => a) (e, e')`

     Example: `(1 before ()) = 1` *)
  val before : 'a * unit -> 'a

  (* `ignore e` is `()`: it throws the value of `e` away.

     A statement whose value is not `unit` is a warning in some compilers and
     a mistake in most programs; `ignore` says that this one is meant. *)
  val ignore : 'a -> unit
end
