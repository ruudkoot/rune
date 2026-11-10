(* The primitives of Core, their types written as Core text
   (coreprim_sig.sml). *)
structure CorePrim : CORE_PRIM =
struct
  type prim = {name : string, ty : Core.ty, doc : string}

  (* two arguments of a type, giving another *)
  fun binary (t, r) = "(-> !" ^ t ^ " !" ^ t ^ " " ^ r ^ ")"
  fun unary (t, r) = "(-> !" ^ t ^ " " ^ r ^ ")"
  fun binary' (a, b, r) = "(-> !" ^ a ^ " !" ^ b ^ " " ^ r ^ ")"

  (* the arithmetic and comparisons of a type whose primitives start with p *)
  fun numeric (p, t) =
    List.map (fn (n, d) => (p ^ "_" ^ n, binary (t, t), d))
             [("add", "the sum"), ("sub", "the difference"), ("mul", "the product"),
              ("quot", "the quotient, rounded toward zero; Div for a divisor of 0"),
              ("rem", "the remainder of quot"),
              ("div", "the quotient, rounded down; Div for a divisor of 0"),
              ("mod", "the remainder of div")]
    @ [(p ^ "_neg", unary (t, t), "the negation")]
    @ comparisons (p, t)
  and comparisons (p, t) =
    List.map (fn n => (p ^ "_" ^ n, binary (t, "Bool"), "a comparison")) ["eq", "ne", "lt", "le", "gt", "ge"]

  (* an IO action giving a T: World -> (utuple World T) *)
  fun io t = "(-> World (utuple World " ^ t ^ "))"

  val table =
    numeric ("int", "Int")
    @ numeric ("integer", "Integer")
    @ [("integer_from_int", unary ("Int", "Integer"), "the Integer of an Int"),
       ("integer_to_int", unary ("Integer", "Int"), "the Int of an Integer; Overflow past Int's range")]
    @ [("char_ord", unary ("Char", "Int"), "the code point"),
       ("char_chr", unary ("Int", "Char"), "the character of a code point; Chr outside 0 to 1114111")]
    @ comparisons ("char", "Char")
    @ List.map (fn (n, d) => ("double_" ^ n, binary ("Double", "Double"), d))
               [("add", "the sum"), ("sub", "the difference"), ("mul", "the product"), ("div", "the quotient")]
    @ [("double_neg", unary ("Double", "Double"), "the negation")]
    @ comparisons ("double", "Double")
    @ [("double_from_int", unary ("Int", "Double"), "the Double nearest an Int"),
       ("double_to_str", unary ("Double", "Str"), "the text Mid's real_to_string gives: 12 digits, ~ for a minus, .0 where there is no point")]
    @ [("str_size", unary ("Str", "Int"), "the number of bytes"),
       ("str_byte", binary' ("Str", "Int", "Int"), "the byte at an index, from 0; Subscript outside"),
       ("str_concat", binary ("Str", "Str"), "the bytes of one, then the other's"),
       ("str_from_char", unary ("Char", "Str"), "the bytes of a character in UTF-8")]
    @ [("print_str", "(-> !Str World World)", "writes the bytes to standard output"),
       ("print_err", "(-> !Str World World)", "writes the bytes to standard error"),
       ("exit", "(-> !Int World World)", "ends the program with a status, standard output written"),
       ("ref_new", "(forall (a) (-> a " ^ io "!(Ref a)" ^ "))", "a new cell, holding a value it does not force"),
       ("ref_get", "(forall (a) (-> !(Ref a) " ^ io "a" ^ "))", "what a cell holds"),
       ("ref_set", "(forall (a) (-> !(Ref a) a World World))", "puts a value in a cell, unforced"),
       ("real_world", "World", "a state token, for an action run where none is passed")]
    @ [("raise", "(forall (a) (-> !Exn a))", "raises an exception"),
       ("raise_io", "(forall (a) (-> !Exn " ^ io "a" ^ "))", "an action that raises an exception, ioError's"),
       ("exn_error", unary ("Str", "Exn"), "the exception error raises, ErrorCall"),
       ("exn_io", unary ("Str", "Exn"), "an IOError, the one exception catch sees in Haskell 98"),
       ("exn_pattern", unary ("Str", "Exn"), "the exception of a failed match, PatternMatchFail"),
       ("exn_kind", unary ("Exn", "Int"), "the number of an exception's kind, in exnKinds"),
       ("exn_name", unary ("Exn", "Str"), "the name of an exception's kind"),
       ("exn_message", unary ("Exn", "Str"), "the message an exception holds"),
       ("catch", "(forall (a) (-> " ^ io "a" ^ " (-> !Exn " ^ io "a" ^ ") " ^ io "a" ^ "))",
        "runs an action, and the handler on what it raises: every exception, which the Prelude narrows")]

  val prims = List.map (fn (name, ty, doc) => {name = name, ty = CoreText.parseType ty, doc = doc}) table

  fun find name = List.find (fn {name = n, ...} => n = name) prims

  val exnKinds = ["ErrorCall", "IOError", "PatternMatchFail", "NonTermination", "Div", "Overflow", "Subscript", "Chr"]
end
