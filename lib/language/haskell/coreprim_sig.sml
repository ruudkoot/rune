(* The primitives of Core (the haskell98 roadmap, D26): what Core can do
   that is not a function of Core, each with its type. An argument a
   primitive reads is evaluated, `!T`; one it may leave suspended, a
   function or a value it stores, is lazy. A primitive that does I/O takes
   the state token and gives it back, so that its order is its data's.

   They are Rune's primitives where Mid has one of the same name, and do
   what it does: `int_add` raises `Overflow` past `Int`'s range, as
   `Int.+` does, and a division by zero raises `Div`. Core to Mid lowers
   each; the Core interpreter runs each (CoreInterp).

   Area: Languages *)
signature CORE_PRIM =
sig
  (* A primitive: its name, its type in Core, and what it does. *)
  type prim = {name : string, ty : Core.ty, doc : string}

  (* `prims` is every primitive, in the order of this list:

     - on `Int`: `int_add`, `int_sub`, `int_mul`, `int_quot`, `int_rem`,
       `int_div`, `int_mod`, `int_neg`, and the comparisons `int_eq`,
       `int_ne`, `int_lt`, `int_le`, `int_gt`, `int_ge`;
     - on `Integer`: the same, `integer_add` to `integer_ge`, and
       `integer_from_int`, `integer_to_int`;
     - on `Char`: `char_ord`, `char_chr`, and `char_eq` to `char_ge`;
     - on `Double`: `double_add`, `double_sub`, `double_mul`, `double_div`,
       `double_neg`, `double_eq` to `double_ge`, `double_from_int` and
       `double_to_str`;
     - on `Str`: `str_size`, `str_byte`, `str_concat`, `str_from_char`;
     - I/O: `print_str`, `print_err`, `exit`, `ref_new`, `ref_get`,
       `ref_set`, `real_world`;
     - exceptions: `raise`, `raise_io`, `exn_error`, `exn_io`, `exn_pattern`,
       `exn_kind`, `exn_name`, `exn_message` and `catch`. *)
  val prims : prim list

  (* `find name` is the primitive called `name`, if there is one. *)
  val find : string -> prim option

  (* `exnKinds` is the kinds of exception, by the number `exn_kind` gives.

     They are `ErrorCall`, `IOError`, `PatternMatchFail`, `NonTermination`
     (a suspension forced again under its own evaluation), `Div`, `Overflow`,
     `Subscript` and `Chr`. *)
  val exnKinds : string list
end
