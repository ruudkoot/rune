(* Optional values: a value that may be missing, and what a partial function
   returns instead of raising an exception.

   `NONE` says that there is no value and `SOME v` that there is `v`. The
   functions here spare a program most case analyses on options: a default for
   the missing value (`getOpt`), functions carried over to options (`map`,
   `mapPartial`, `compose`), a predicate turned into a partial function
   (`filter`). The datatype, the exception and `getOpt`, `isSome` and `valOf`
   are also in the top-level environment.

   Area: Lists and options

   See also: `LIST`, `LIST_PAIR` *)
signature OPTION =
sig
  (* The type of optional values, the one of the top-level environment.

     It admits equality when `'a` does.

     Erratum: `OPTION/option-spec`. `NONE` and `SOME` may be specified, unlike
     the constructors of `bool` and `list`, so the datatype stands here as the
     specification writes it. *)
  datatype 'a option
    = NONE         (* no value *)
    | SOME of 'a   (* the value it carries *)

  (* Raised by `valOf` when there is no value. It is the top-level `Option`. *)
  exception Option

  (* `getOpt (opt, a)` is the value that `opt` carries, or the default `a` if
     it carries none.

     Example: `getOpt (NONE, 0) = 0` *)
  val getOpt : 'a option * 'a -> 'a

  (* `isSome opt` is `true` when `opt` carries a value. *)
  val isSome : 'a option -> bool

  (* `valOf opt` is the value that `opt` carries.

     Raises: `Option` if `opt` is `NONE`. *)
  val valOf : 'a option -> 'a

  (* `filter p a` is `SOME a` when `a` satisfies `p`, and `NONE` otherwise.

     Example: `filter (fn x => x > 0) 0 = NONE` *)
  val filter : ('a -> bool) -> 'a -> 'a option

  (* `join opt` takes one layer of option away: `SOME (SOME v)` becomes `SOME
     v`, everything else `NONE`.

     Example: `join (SOME (SOME 1)) = SOME 1` *)
  val join : 'a option option -> 'a option

  (* `app f opt` applies `f` to the value that `opt` carries, if there is one,
     for its effect. *)
  val app : ('a -> unit) -> 'a option -> unit

  (* `map f opt` is `SOME (f v)` when `opt` is `SOME v`, and `NONE` when it is
     `NONE`.

     Example: `map (fn x => x + 1) (SOME 1) = SOME 2` *)
  val map : ('a -> 'b) -> 'a option -> 'b option

  (* `mapPartial f opt` is `f v` when `opt` is `SOME v`, and `NONE` when it is
     `NONE`.

     It chains two computations that may fail: the second runs only if the
     first gave a value.

     Law: `mapPartial f opt = join (map f opt)`

     Example: `mapPartial Int.fromString (SOME "x") = NONE` *)
  val mapPartial : ('a -> 'b option) -> 'a option -> 'b option

  (* `compose (f, g) a` is `SOME (f v)` when `g a` is `SOME v`, and `NONE` when
     `g a` is `NONE`.

     Law: `compose (f, g) a = map f (g a)`

     Example: `compose (fn x => x + 1, Int.fromString) "41" = SOME 42` *)
  val compose : ('a -> 'b) * ('c -> 'a option) -> 'c -> 'b option

  (* `composePartial (f, g) a` is `f v` when `g a` is `SOME v`, and `NONE` when
     `g a` is `NONE`.

     Law: `composePartial (f, g) a = mapPartial f (g a)` *)
  val composePartial : ('a -> 'b option) * ('c -> 'a option) -> 'c -> 'b option
end
