(* The types at which the overloaded operators and constants of the initial
   basis (Definition, Appendix E) are defined.

   An overloaded operator has a class of kinds ("int", "word", "real",
   "char", "string"); a type constructor takes part in overloading when it is
   registered here, by stamp, with its kind and with the primitive that
   implements each operator at that type. The five builtin types are
   registered below. *)
structure Overload =
struct
  type entry = {kind : string, ops : string StringMap.map}

  val table : entry IntMap.map ref = ref IntMap.empty

  fun register (tycon : Types.tycon, kind : string, ops : (string * string) list) : unit =
    table := IntMap.insert (!table, #stamp tycon,
                            {kind = kind,
                             ops = List.foldl (fn ((name, prim), m) => StringMap.insert (m, name, prim))
                                              StringMap.empty ops})

  (* The kind of a type constructor, if it is an overloading type. *)
  fun kindOf (tycon : Types.tycon) : string option =
    case IntMap.find (!table, #stamp tycon) of
      SOME {kind, ...} => SOME kind
    | NONE => NONE

  (* The primitive for an operator at a type constructor. *)
  fun primOf (tycon : Types.tycon, name : string) : string option =
    case IntMap.find (!table, #stamp tycon) of
      SOME {ops, ...} => StringMap.find (ops, name)
    | NONE => NONE

  fun comparisons prefix =
    [("<", prefix ^ "_lt"), ("<=", prefix ^ "_le"), (">", prefix ^ "_gt"), (">=", prefix ^ "_ge")]

  val () =
    (register (Types.intTycon, "int",
               [("+", "int_add"), ("-", "int_sub"), ("*", "int_mul"), ("div", "int_div"),
                ("mod", "int_mod"), ("~", "int_neg"), ("abs", "int_abs")] @ comparisons "int");
     register (Types.wordTycon, "word",
               [("+", "word_add"), ("-", "word_sub"), ("*", "word_mul"), ("div", "word_div"),
                ("mod", "word_mod")] @ comparisons "word");
     register (Types.realTycon, "real",
               [("+", "real_add"), ("-", "real_sub"), ("*", "real_mul"), ("/", "real_div"),
                ("~", "real_neg"), ("abs", "real_abs")] @ comparisons "real");
     register (Types.charTycon, "char", comparisons "char");
     register (Types.stringTycon, "string", comparisons "string"))
end
