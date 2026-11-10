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

  (* the elementary functions, conversions to Int and classes of a
     floating type whose primitives start with p, each of Mid's real
     primitive, its result rounded as `round` says *)
  fun floating (p, t, round) =
    List.map (fn (n, d) => (p ^ "_" ^ n, unary (t, t), d ^ round))
             [("sqrt", "the square root"), ("exp", "e to the power"), ("log", "the natural logarithm"),
              ("sin", "the sine"), ("cos", "the cosine"), ("tan", "the tangent"), ("atan", "the arc tangent"),
              ("sinh", "the hyperbolic sine"), ("cosh", "the hyperbolic cosine"), ("tanh", "the hyperbolic tangent")]
    @ [(p ^ "_atan2", binary (t, t), "the arc tangent of the first over the second, in the quadrant of both" ^ round)]
    @ List.map (fn (n, d) => (p ^ "_" ^ n, unary (t, "Int"), d ^ "; Overflow past Int's range, Domain for a NaN"))
               [("truncate", "the integer toward zero"), ("round", "the nearest integer, an even one at a half"),
                ("ceiling", "the least integer not below"), ("floor", "the greatest integer not above")]
    @ List.map (fn (n, d) => (p ^ "_" ^ n, unary (t, "Bool"), d))
               [("is_nan", "whether it is a NaN"), ("is_infinite", "whether it is an infinity"),
                ("is_negative_zero", "whether it is -0"), ("is_denormalized", "whether it is subnormal")]
    @ [(p ^ "_decode", unary (t, "(utuple !Int !Int)"),
        "m and e of m * 2^e, m with as many bits as the type's mantissa, or 0 and 0 for a zero; Overflow or Domain for an infinity or a NaN"),
       (p ^ "_encode", binary' ("Int", "Int", t), "m * 2^e of m and e, by the Double nearest m" ^ round)]

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
    @ floating ("double", "Double", "")
    @ [("double_pow", binary ("Double", "Double"), "the first to the power of the second, as C's pow")]
    @ List.map (fn (n, d) => ("float_" ^ n, binary ("Float", "Float"), d ^ ", rounded to binary32"))
               [("add", "the sum"), ("sub", "the difference"), ("mul", "the product"), ("div", "the quotient")]
    @ [("float_neg", unary ("Float", "Float"), "the negation")]
    @ comparisons ("float", "Float")
    @ [("float_from_int", unary ("Int", "Float"), "the Double nearest an Int, rounded to binary32"),
       ("float_from_double", unary ("Double", "Float"), "the Double rounded to binary32"),
       ("float_to_double", unary ("Float", "Double"), "the same value, a Double"),
       ("float_to_str", unary ("Float", "Str"), "the text of the value as a Double, as double_to_str gives it")]
    @ floating ("float", "Float", ", rounded to binary32")
    @ [("str_size", unary ("Str", "Int"), "the number of bytes"),
       ("str_byte", binary' ("Str", "Int", "Int"), "the byte at an index, from 0; Subscript outside"),
       ("str_concat", binary ("Str", "Str"), "the bytes of one, then the other's"),
       ("str_from_char", unary ("Char", "Str"), "the bytes of a character in UTF-8"),
       ("str_extract", "(-> !Str !Int !Int Str)", "the bytes from an index, as many as the length; Subscript outside"),
       ("str_eq", binary ("Str", "Bool"), "whether the bytes are the same")]
    @ [("arr_new", "(forall (a) (-> !Int a " ^ io "!(Arr a)" ^ "))", "a new array of so many cells, each holding the value, unforced"),
       ("arr_set", "(forall (a) (-> !(Arr a) !Int a World World))", "puts a value in a cell, unforced; Subscript outside"),
       ("arr_read", "(forall (a) (-> !(Arr a) !Int " ^ io "a" ^ "))", "what a cell holds; Subscript outside"),
       ("arr_get", "(forall (a) (-> !(Arr a) !Int a))", "what a cell of an array no one writes again holds; Subscript outside"),
       ("arr_size", "(forall (a) (-> !(Arr a) Int))", "the number of cells")]
    @ [("print_str", "(-> !Str World World)", "writes the bytes to standard output"),
       ("print_err", "(-> !Str World World)", "writes the bytes to standard error"),
       ("exit", "(-> !Int World World)", "ends the program with a status, standard output written"),
       ("h_open", "(-> !Str !Int World (utuple World !Int))",
        "opens a file, to read (mode 0), to write from empty (1) or to append (2): its handle, or ~1, h_error saying why"),
       ("h_close", "(-> !Int World World)", "closes a handle; nothing for 0 to 2, standard input, output and error"),
       ("h_read", "(-> !Int !Int World (utuple World !Str))",
        "at most so many bytes, waiting for one, and \"\" at the end; an IOError where the read fails"),
       ("h_write", "(-> !Int !Str World (utuple World !Bool))", "writes the bytes: False where it fails, h_error saying why"),
       ("h_flush", "(-> !Int World World)", "writes what a handle holds"),
       ("h_error", "(-> World (utuple World !Str))", "the text of the error of the last h_open or h_write that failed"),
       ("interleave", "(forall (a) (-> " ^ io "a" ^ " " ^ io "a" ^ "))",
        "an action that gives at once a suspension of what the action given gives, which runs it when forced, with a state of its own"),
       ("ref_new", "(forall (a) (-> a " ^ io "!(Ref a)" ^ "))", "a new cell, holding a value it does not force"),
       ("ref_get", "(forall (a) (-> !(Ref a) " ^ io "a" ^ "))", "what a cell holds"),
       ("ref_set", "(forall (a) (-> !(Ref a) a World World))", "puts a value in a cell, unforced"),
       ("real_world", "World", "a state token, for an action run where none is passed")]
    @ [("raise", "(forall (a) (-> !Exn a))", "raises an exception"),
       ("raise_io", "(forall (a) (-> !Exn " ^ io "a" ^ "))", "an action that raises an exception, ioError's"),
       ("exn_error", unary ("Str", "Exn"), "the exception error raises, ErrorCall"),
       ("exn_io", unary ("Str", "Exn"), "an IOError, the one exception catch sees in Haskell 98: a user's, of no file and no handle"),
       ("exn_io_full", "(-> !Int !Str !Str !Int Exn)",
        "an IOError of a kind's code (0 a user's, 1 already exists, 2 does not exist, 3 in use, 4 full, 5 end of file, 6 illegal, 7 permission, 8 other), a text, a file (\"\" for none) and a handle (~1)"),
       ("exn_io_code", unary ("Exn", "Int"), "an IOError's code; 0 for any other exception"),
       ("exn_io_file", unary ("Exn", "Str"), "an IOError's file; \"\" for any other exception"),
       ("exn_io_handle", unary ("Exn", "Int"), "an IOError's handle; ~1 for any other exception"),
       ("exn_pattern", unary ("Str", "Exn"), "the exception of a failed match, PatternMatchFail"),
       ("exn_kind", unary ("Exn", "Int"), "the number of an exception's kind, in exnKinds"),
       ("exn_name", unary ("Exn", "Str"), "the name of an exception's kind"),
       ("exn_message", unary ("Exn", "Str"), "the message an exception holds"),
       ("catch", "(forall (a) (-> " ^ io "a" ^ " (-> !Exn " ^ io "a" ^ ") " ^ io "a" ^ "))",
        "runs an action, and the handler on what it raises: every exception, which the Prelude narrows")]

  (* the families of primitives, each of a file of its own *)
  val families : CorePrimFamily.family list = [CorePrimIo.family, CorePrimSys.family]

  val prims =
    List.map (fn (name, ty, doc) => {name = name, ty = CoreText.parseType ty, doc = doc})
             (table @ List.concat (List.map (fn {prims, ...} => List.map (fn {name, ty, doc, ...} => (name, ty, doc)) prims) families))

  fun familyOf name =
    List.foldl (fn (f as {prims, ...} : CorePrimFamily.family, NONE) =>
                     Option.map (fn p => (f, p)) (List.find (fn {name = n, ...} : CorePrimFamily.prim => n = name) prims)
                 | (_, found) => found)
               NONE families

  fun find name = List.find (fn {name = n, ...} => n = name) prims

  val exnKinds = ["ErrorCall", "IOError", "PatternMatchFail", "NonTermination", "Div", "Overflow", "Subscript", "Chr", "Domain"]
end
