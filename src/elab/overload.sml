(* The types at which the overloaded operators and constants of the initial
   basis (Definition, Appendix E) are defined.

   An overloaded operator or constant has a class of kinds ("int", "word",
   "real", "char", "string"); a type constructor takes part in overloading
   when it is registered here, by stamp, with its kind, the implementation of
   each operator at that type and the form of its constants. The five builtin
   types are registered below; the declaration
     _overload <kind> <longstrid> [<bits> | via <longvid>]
   of a basis library file registers the type <longstrid>.<kind>
   (Elaborate). *)
structure Overload =
struct
  (* An operator is a VM primitive, or a top-level variable (by stamp). *)
  datatype impl = Prim of string | Global of int

  (* A constant of the type is a constant of the builtin type of the kind,
     restricted to a number of bits (two's complement for "int"), or the
     application of a top-level function string -> ty (by stamp) to its
     decimal digits (with ~ for a negative number). *)
  datatype literal = Bits of int | Via of int

  type entry = {kind : string, ops : impl StringMap.map, literal : literal}

  val table : entry IntMap.map ref = ref IntMap.empty

  fun register (tycon : Types.tycon, kind : string, ops : (string * impl) list, literal : literal) : unit =
    table := IntMap.insert (!table, #stamp tycon,
                            {kind = kind,
                             ops = List.foldl (fn ((name, impl), m) => StringMap.insert (m, name, impl))
                                              StringMap.empty ops,
                             literal = literal})

  fun find (tycon : Types.tycon) : entry option = IntMap.find (!table, #stamp tycon)

  (* The kind of a type constructor, if it is an overloading type. *)
  fun kindOf tycon = case find tycon of SOME {kind, ...} => SOME kind | NONE => NONE

  (* The implementation of an operator at a type constructor. *)
  fun implOf (tycon, name : string) : impl option =
    case find tycon of SOME {ops, ...} => StringMap.find (ops, name) | NONE => NONE

  fun literalOf tycon = case find tycon of SOME {literal, ...} => SOME literal | NONE => NONE

  (* The operators of a kind: those a registered type must implement. *)
  val comparisons = ["<", "<=", ">", ">="]
  fun operators "int" = ["+", "-", "*", "div", "mod", "~", "abs"] @ comparisons
    | operators "word" = ["+", "-", "*", "div", "mod", "~"] @ comparisons
    | operators "real" = ["+", "-", "*", "/", "~", "abs"] @ comparisons
    | operators _ = comparisons

  fun prims (prefix, names) =
    List.map (fn (name, suffix) => (name, Prim (prefix ^ "_" ^ suffix))) names
  val cmp = [("<", "lt"), ("<=", "le"), (">", "gt"), (">=", "ge")]

  val () =
    (register (Types.intTycon, "int",
               prims ("int", [("+", "add"), ("-", "sub"), ("*", "mul"), ("div", "div"), ("mod", "mod"),
                              ("~", "neg"), ("abs", "abs")] @ cmp), Bits 64);
     register (Types.wordTycon, "word",
               prims ("word", [("+", "add"), ("-", "sub"), ("*", "mul"), ("div", "div"), ("mod", "mod"),
                               ("~", "neg")] @ cmp), Bits 64);
     register (Types.realTycon, "real",
               prims ("real", [("+", "add"), ("-", "sub"), ("*", "mul"), ("/", "div"), ("~", "neg"),
                               ("abs", "abs")] @ cmp), Bits 64);
        register (Types.charTycon, "char", prims ("char", cmp), Bits 8);
     register (Types.stringTycon, "string", prims ("string", cmp), Bits 8))
end
