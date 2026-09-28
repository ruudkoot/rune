(* Observers: what a generated function sees of its argument (QuickCheck's
   CoArbitrary, reduced to a hash). Two arguments with the same observation
   get the same result from a generated function.

   Area: Property testing *)
signature CO =
sig
  (* An observer of values of type `'a`: a 64-bit word for each. *)
  type 'a co = 'a -> Word64.word

  (* `int` observes an integer: different integers are told apart. *)
  val int : int co

  (* `word` observes a word. *)
  val word : word co

  (* `word64` observes a 64-bit word. *)
  val word64 : Word64.word co

  (* `char` observes a character.

     Example: `char #"a" <> char #"b"` *)
  val char : char co

  (* `bool` observes a boolean. *)
  val bool : bool co

  (* `unit` observes `()`. *)
  val unit : unit co

  (* `order` observes an order. *)
  val order : order co

  (* `string` observes a string, by a hash of its characters. *)
  val string : string co

  (* `real` observes a real by its bits: `0.0` and `~0.0` are told apart,
     and so are NaNs of different bits. *)
  val real : real co

  (* `option c` observes an option, and what it holds by `c`. *)
  val option : 'a co -> 'a option co

  (* `list c` observes a list: its length and every element by `c`. *)
  val list : 'a co -> 'a list co

  (* `pair (c, d)` observes a pair by its components. *)
  val pair : 'a co * 'b co -> ('a * 'b) co

  (* `triple (c, d, e)` observes a triple by its components. *)
  val triple : 'a co * 'b co * 'c co -> ('a * 'b * 'c) co
end
