(* Integer folding of the expressions retained in enum declarations.

   Area: Languages *)
signature C_ENUM_CONST =
sig
  (* Enumerator definitions, separate from target layout and binding policy. *)
  type environment
  (* An unresolved, cyclic or unsupported integer expression. *)
  exception Error of CLex.location * string
  (* `collect declarations` collects global and aggregate enumerators.
     Repeated views of one declaration retain one definition.

     Raises: `Error` for contradictory duplicate enumerators. *)
  val collect : CParse.declaration list -> environment
  (* `evaluate {environment, width, name}` folds one enumerator and its
     dependencies using explicit intmax/uintmax arithmetic.

     Casts and layout-dependent expressions remain the responsibility of
     the target layout consumer. Unsupported expressions fail explicitly.

     Raises: `Error` for missing names, cycles or invalid arithmetic. *)
  val evaluate : {environment : environment, width : int, name : string} -> CConst.value
end
