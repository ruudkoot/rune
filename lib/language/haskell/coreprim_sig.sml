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
       `double_to_str`; then the elementary functions `double_sqrt`,
       `double_exp`, `double_log`, `double_sin`, `double_cos`, `double_tan`,
       `double_atan`, `double_sinh`, `double_cosh`, `double_tanh` and
       `double_atan2`; the conversions to `Int` `double_truncate`,
       `double_round` (to even at a half), `double_ceiling`, `double_floor`;
       the classes `double_is_nan`, `double_is_infinite`,
       `double_is_negative_zero`, `double_is_denormalized`;
       `double_decode` and `double_encode`, a mantissa of 53 bits; and
       `double_pow`;
     - on `Float`, a `Double` that binary32 represents, every result of
       arithmetic rounded to binary32 by Mid's `real_to_single` (D23):
       `float_add`, `float_sub`, `float_mul`, `float_div`, `float_neg`,
       `float_eq` to `float_ge`, `float_from_int`, `float_from_double`,
       `float_to_double`, `float_to_str`, and the functions of `Double`
       from the elementary ones on, `float_sqrt` to `float_encode`, a
       mantissa of 24 bits;
     - on `Str`: `str_size`, `str_byte`, `str_concat`, `str_from_char`,
       `str_extract`, `str_eq`;
     - on `Arr a`, an array of cells each holding a value, unforced, as
       `Ref a` does one: `arr_new`, `arr_set`, `arr_read`, `arr_get`,
       `arr_size`;
     - I/O: `print_str`, `print_err`, `exit`; the handles of files, 0 to 2
       standard input, output and error, `h_open`, `h_close`, `h_read`,
       `h_write`, `h_flush`, `h_error`; `interleave`, which defers an
       action until its value is forced (D25's one interleaving
       primitive); `ref_new`, `ref_get`, `ref_set`, `real_world`;
     - exceptions: `raise`, `raise_io`, `exn_error`, `exn_io`, `exn_io_full`,
       `exn_io_code`, `exn_io_file`, `exn_io_handle`, `exn_pattern`,
       `exn_kind`, `exn_name`, `exn_message` and `catch`;
     - then each family's, in the order of `families`. *)
  val prims : prim list

  (* `find name` is the primitive called `name`, if there is one. *)
  val find : string -> prim option

  (* `families` is the families of primitives (CORE_PRIM_FAMILY), each of a
     file of its own.

     `prims` lists their primitives after its own: the IO library's
     handles and the system's errors (CorePrimIo). *)
  val families : CorePrimFamily.family list

  (* `familyOf name` is the family of the primitive called `name` and the
     primitive, where a family has it. *)
  val familyOf : string -> (CorePrimFamily.family * CorePrimFamily.prim) option

  (* `exnKinds` is the kinds of exception, by the number `exn_kind` gives.

     They are `ErrorCall`, `IOError`, `PatternMatchFail`, `NonTermination`
     (a suspension forced again under its own evaluation), `Div`, `Overflow`,
     `Subscript`, `Chr` and `Domain` (a NaN made an `Int`). *)
  val exnKinds : string list
end
