(* The layout algorithm of Haskell 98, the function `L` of the Report's
   section 9.3, run on demand: the parser pulls one token at a time, so
   that when it takes an implicit close, the side condition
   `parse-error(t)` of the equation for `t`, the stack of layout contexts
   is that of the point it has reached and nothing past that token has
   been laid out (the haskell98 roadmap's D27).

   The equations and where they are kept:

   - `<n>` with `m = n`, `n < m`, and otherwise: a token first on its line;
   - `{n}` with `n > m`, `n > 0`, and otherwise: a token after `let`,
     `where`, `do` or `of` that is not `{`, and the first of a module that
     is neither `{` nor `module`; an empty block makes the next token's
     `{n}` an `<n>`;
   - `}` with an explicit context on top, `{`, and the end of the input:
     `advance`;
   - `t` with an implicit context on top and `parse-error(t)`:
     `closeImplicit`, which the parser calls.

   It makes two readings of the roadmap's evidence (`results/E9/readings.md`):
   R2, an explicit `}` may close an implicit block, as section 2.7 reads,
   where 9.3's Note 3 alone would refuse it; and R3, a block opens only
   at a column strictly greater than the enclosing one, so that a `do`
   at the column of its context is empty.

   There is one stream at a time: `start` begins it, and the parser reads
   and moves it.

   Area: Languages *)
signature HS_LAYOUT =
sig
  (* `start (file, tokens)` begins the stream of the tokens of the file
     `file`, laid out, and reads its first token. *)
  val start : string * HsToken.item vector -> unit

  (* The token the stream is at, written or layout's. *)
  val current : HsToken.token ref

  (* `here ()` is the span of the current token; a token of layout's
     covers no byte, and stands where the next written token begins. *)
  val here : unit -> HsSource.span

  (* `currentStart ()` is where the current token begins: `#start (here ())`. *)
  val currentStart : unit -> int

  (* `trivia ()` is the trivia before the current token; none for
     layout's. *)
  val trivia : unit -> HsToken.trivium list

  (* `lastStop ()` is where the last written token that `advance` passed
     ends: 0 before the first. *)
  val lastStop : unit -> int

  (* `advance ()` passes the current token and reads the next.

     Raises: `HsSource.Error` for a `}` that no `{` opened, and for the
     end of the input inside braces. *)
  val advance : unit -> unit

  (* `closeImplicit ()` is the equation of `t` with `parse-error(t)`: the
     parser can go no further with the current token in its block.

     Where that block is implicit it is closed and the result is `true`;
     where it is explicit, or there is none, nothing changes and the
     result is `false`. *)
  val closeImplicit : unit -> bool

  (* `peek k` is the `k`th written token after the current one, from 0,
     as the lexer read it: layout does not see that far. *)
  val peek : int -> HsToken.token

  (* Where the stream is, to go back to. *)
  type mark

  (* `save ()` is where the stream is now. *)
  val save : unit -> mark

  (* `restore m` puts the stream back where it was at `m`. *)
  val restore : mark -> unit

  (* `fail msg` raises an error at the current token.

     Raises: `HsSource.Error` always. *)
  val fail : string -> 'a
end
