(* Implements: C_PARSE *)
structure CParse : C_PARSE =
struct
  datatype recordKind = Struct | Union
  type attribute = CLex.token list
  datatype ctype = Builtin of string | Named of string
    | Pointer of {target : ctype, qualifiers : string list}
    | Array of {element : ctype, bound : CLex.token list}
    | Function of {result : ctype, parameters : parameter list, variadic : bool, prototype : bool}
    | Record of {kind : recordKind, tag : string option, fields : field list option, pack : int option}
    | Enum of {tag : string option, values : (string * CLex.token list) list option}
    | Attributed of ctype * attribute list
  and parameter = Parameter of {name : string option, ctype : ctype}
  and field = Field of {name : string option, ctype : ctype, bits : CLex.token list, location : CLex.location}
  datatype declaration = Declaration of {name : string option, ctype : ctype, storage : string list,
    initializer : CLex.token list, body : CLex.token list, location : CLex.location}
    | StaticAssert of {condition : CLex.token list, message : CLex.token list, location : CLex.location}
  exception Error of CLex.location * string
  fun parse {tokens, predefinedTypes, typeOnly} =
    let
      val input = ref tokens
      val typedefs = ref predefinedTypes
      val packing = ref (NONE : int option)
      val packs = ref ([] : (string option * int option) list)
      val pragmas = ref ([] : attribute list)
      val last = ref ({file = "<declarations>", line = 1, column = 1} : CLex.location)
      val lastToken = ref (NONE : CLex.token option)
      fun position token = #1 (CLex.diagnostic (token, ""))
      fun fail message = raise Error (case !lastToken of NONE => (!last, message)
        | SOME token => CLex.diagnostic (token, message))
      val pragmaHandler = ref (fn () => fail "pragma before parser initialization")
      val inPragma = ref false
      fun skip () = case !input of t :: rest => if #kind t = CLex.Newline then (input := rest; skip ()) else () | [] => ()
      fun peek () = (skip (); case !input of t :: _ =>
          if #text t = "#" andalso not (!inPragma) then
            (inPragma := true; ((!pragmaHandler) () handle e => (inPragma := false; raise e));
             inPragma := false; peek ()) else SOME t
        | [] => NONE)
      fun spelling () = case peek () of SOME t => #text t | NONE => ""
      fun pop () = case peek () of SOME t => (input := tl (!input); last := position t; lastToken := SOME t; t) | NONE => fail "unexpected end of declaration"
      fun accept s = if spelling () = s then (ignore (pop ()); true) else false
      fun expect s = if accept s then () else fail ("expected '" ^ s ^ "', found '" ^ spelling () ^ "'")
      fun contains xs s = List.exists (fn x => x = s) xs
      fun identifier () = case peek () of SOME t => #kind t = CLex.Identifier | NONE => false
      fun grouped openSymbol closeSymbol =
        let val first = pop ()
            val () = if #text first = openSymbol then () else fail ("expected '" ^ openSymbol ^ "'")
            fun loop (depth, acc) =
              let val t = pop ()
              in if #text t = closeSymbol then if depth = 0 then rev (t :: acc) else loop (depth - 1, t :: acc)
                 else if #text t = openSymbol then loop (depth + 1, t :: acc) else loop (depth, t :: acc) end
        in loop (0, [first]) end
      (* Collect to a top-level delimiter, preserving nested expression syntax. *)
      fun expression stops =
        let fun loop (stack, acc) =
              let val s = spelling ()
              in if s = "" then fail "unterminated constant or initializer"
                else if null stack andalso contains stops s then rev acc
                else let val t = pop ()
                         val stack = case s of "(" => ")" :: stack | "[" => "]" :: stack | "{" => "}" :: stack
                           | ")" => close s stack | "]" => close s stack | "}" => close s stack | _ => stack
                     in loop (stack, t :: acc) end end
            and close s (expected :: rest) = if s = expected then rest else fail "unbalanced expression delimiters"
              | close _ [] = fail "unmatched expression delimiter"
        in loop ([], []) end
      val convention = ["__cdecl", "__stdcall", "__fastcall", "__thiscall", "__vectorcall", "__clrcall", "__pascal", "_cdecl", "_stdcall"]
      val qualifiers = ["const", "volatile", "restrict", "__restrict", "__restrict__", "_Atomic", "__ptr32", "__ptr64", "__unaligned", "__w64"]
      val storages = ["typedef", "extern", "static", "auto", "register", "inline", "__inline", "__inline__", "__forceinline", "_Thread_local", "__thread", "_Noreturn"]
      val builtins = ["void", "_Bool", "bool", "char", "short", "int", "long", "signed", "unsigned", "float", "double", "__int8", "__int16", "__int32", "__int64", "__int128", "_Float128", "__builtin_va_list"]
      val attributeNames = ["__attribute__", "__attribute", "__declspec", "_Alignas", "alignas", "__asm", "__asm__", "asm"]
      fun attributes () =
        let fun go acc =
              if contains convention (spelling ()) orelse spelling () = "__extension__" then go ([pop ()] :: acc)
              else if contains attributeNames (spelling ()) then
                let val name = pop () val body = grouped "(" ")" in go ((name :: body) :: acc) end
              else rev acc
        in go [] end
      fun attributed (base, []) = base | attributed (base, attrs) = Attributed (base, attrs)
      fun specifiers () =
        let
          fun aggregate kind =
            let val prefix = attributes ()
                val tag = if identifier () then SOME (#text (pop ())) else NONE
                val suffix = attributes ()
                val fields = if accept "{" then SOME (members []) else NONE
                val () = if isSome tag orelse isSome fields then () else fail "aggregate requires tag or definition"
            in attributed (Record {kind = kind, tag = tag, fields = fields, pack = !packing}, prefix @ suffix) end
          and members acc =
            if accept "}" then rev acc
            else let val declarations = declaration true
                     fun field (Declaration {name, ctype, initializer, location, ...}) =
                       SOME (Field {name = name, ctype = ctype, bits = initializer, location = location})
                       | field (StaticAssert _) = NONE
                 in members (rev (List.mapPartial field declarations) @ acc) end
          fun enumeration () =
            let val tag = if identifier () then SOME (#text (pop ())) else NONE
                fun values acc =
                  if accept "}" then rev acc else
                  let val name = if identifier () then #text (pop ()) else fail "expected enum member"
                      val value = if accept "=" then expression [",", "}"] else []
                      val more = accept ","
                  in if more then values ((name, value) :: acc)
                     else (expect "}"; rev ((name, value) :: acc)) end
                val values = if accept "{" then SOME (values []) else NONE
                val () = if isSome tag orelse isSome values then () else fail "enum requires tag or definition"
            in Enum {tag = tag, values = values} end
          fun loop (words, base, storage, attrs) =
            let val extra = attributes ()
                val attrs = attrs @ extra
                val s = spelling ()
            in if contains storages s then (ignore (pop ()); loop (words, base, s :: storage, attrs))
               else if contains qualifiers s then
                 let val q = pop ()
                 in if s = "_Atomic" andalso spelling () = "(" then
                      (expect "("; let val (b, _, a) = specifiers () val (_, build) = declarator true
                       in expect ")"; loop (words, SOME (build b), storage, attrs @ ([q] :: a)) end)
                    else loop (words, base, storage, attrs @ [[q]]) end
               else if contains builtins s then (ignore (pop ()); loop (s :: words, base, storage, attrs))
               else if s = "struct" orelse s = "union" orelse s = "enum" then
                 (if isSome base orelse not (null words) then fail "multiple declaration base types" else ();
                  ignore (pop ()); loop (words, SOME (if s = "enum" then enumeration () else aggregate (if s = "struct" then Struct else Union)), storage, attrs))
               else if null words andalso not (isSome base) andalso contains (!typedefs) s then
                 (ignore (pop ()); loop (words, SOME (Named s), storage, attrs))
               else
                 let val base = case (base, words) of (SOME b, []) => b | (NONE, _ :: _) => Builtin (String.concatWith " " (rev words))
                       | (NONE, []) => fail ("expected C type specifier, found '" ^ s ^ "'")
                       | _ => fail "multiple declaration base types"
                 in (attributed (base, attrs), rev storage, attrs) end
            end
        in loop ([], NONE, [], []) end
      and declarator abstract =
        let
          val prefixAttributes = attributes ()
          fun pointers () =
            if accept "*" then
              let fun quals acc = if contains qualifiers (spelling ()) then quals (#text (pop ()) :: acc) else rev acc
                  val qs = quals []
                  val attrs = attributes ()
                  val more = pointers ()
              in fn base => more (attributed (Pointer {target = base, qualifiers = qs}, attrs)) end
            else fn base => base
          val ptr = pointers ()
          val (name, build) =
            if identifier () then (SOME (#text (pop ())), fn base => base)
            else if accept "(" then
              (* An abstract declarator may start with a prototype; put the
                 parenthesis back for the suffix parser in that case. *)
              if abstract andalso (spelling () = ")" orelse contains builtins (spelling ()) orelse contains (!typedefs) (spelling ())) then
                let val t : CLex.token = {kind = CLex.Punctuation, text = "(", space = false, location = !last, origins = []}
                in input := t :: !input; (NONE, fn base => base) end
              else let val inner = declarator abstract in expect ")"; inner end
            else if abstract then (NONE, fn base => base) else fail "expected declarator name"
          fun suffix build =
            if accept "[" then
              let val bound = expression ["]"] val () = expect "]"
              in suffix (fn base => build (Array {element = base, bound = bound})) end
            else if accept "(" then
              let val (parameters, variadic, prototype) = parameters ()
              in suffix (fn base => build (Function {result = base, parameters = parameters, variadic = variadic, prototype = prototype})) end
            else let val attrs = attributes () in fn base => attributed (build base, attrs) end
          val complete = suffix build
        in (name, fn base => complete (ptr (attributed (base, prefixAttributes)))) end
      and parameters () =
        if accept ")" then ([], false, false)
        else
          let fun loop acc =
                if accept "..." then (expect ")"; (rev acc, true, true))
                else let val (base, _, _) = specifiers ()
                         val (name, build) = declarator true
                         val ctype = build base
                         val param = Parameter {name = name, ctype = ctype}
                     in if accept "," then loop (param :: acc)
                        else (expect ")";
                          case (acc, name, ctype) of ([], NONE, Builtin "void") => ([], false, true)
                           | _ => (rev (param :: acc), false, true)) end
          in loop [] end
      and declaration member =
        if spelling () = "_Static_assert" orelse spelling () = "static_assert" then
          let val location = position (pop ())
              val () = expect "("
              val condition = expression [",", ")"]
              val message = if accept "," then expression [")"] else []
              val () = (expect ")"; expect ";")
          in [StaticAssert {condition = condition, message = message, location = location}] end
        else let val location = case peek () of SOME t => position t | NONE => !last
            val (base, storage, _) = specifiers ()
            fun one acc =
              let val (name, build) = if member andalso spelling () = ":" then (NONE, fn b => b)
                                     else declarator member
                  val ctype = build base
                  val initializer = if member andalso accept ":" then expression [",", ";"]
                    else if accept "=" then if member then fail "initializer on C aggregate member"
                      else expression [",", ";"] else []
                  val body = if not member andalso spelling () = "{" then grouped "{" "}" else []
                  val d = Declaration {name = name, ctype = ctype, storage = storage, initializer = initializer, body = body, location = location}
                  val () = if contains storage "typedef" then case name of SOME n => typedefs := n :: !typedefs
                    | NONE => fail "typedef without name" else ()
              in if not (null body) then rev (d :: acc)
                 else if accept "," then one (d :: acc) else (expect ";"; rev (d :: acc)) end
        in if accept ";" then if contains storage "typedef" then fail "typedef without name"
          else [Declaration {name = NONE, ctype = base, storage = storage, initializer = [], body = [], location = location}]
           else one [] end
      fun pragma () =
        let val () = expect "#"
            val () = expect "pragma"
            fun line acc = case !input of [] => rev acc | t :: rest =>
              (input := rest; if #kind t = CLex.Newline then rev acc else line (t :: acc))
            val tokens = line []
            val () = pragmas := tokens :: !pragmas
            val words = List.map #text tokens
            fun number s = case Int.fromString s of SOME n => if contains [1,2,4,8,16] n then SOME n else fail "unsupported pragma pack alignment"
              | NONE => fail "invalid pragma pack alignment"
            fun popPack name =
              let fun find [] = fail "unmatched pragma pack pop"
                    | find ((label, value) :: rest) = if not (isSome name) orelse label = name then (packing := value; packs := rest) else find rest
              in find (!packs) end
            val () = case words of
                ["pack", "(", ")"] => packing := NONE
              | ["pack", "(", n, ")"] => if n = "pop" then popPack NONE
                  else if n = "push" then packs := (NONE, !packing) :: !packs else packing := number n
              | ["pack", "(", "push", ",", n, ")"] =>
                  (packs := (NONE, !packing) :: !packs; packing := number n)
              | ["pack", "(", "push", ",", label, ",", n, ")"] =>
                  (packs := (SOME label, !packing) :: !packs; packing := number n)
              | ["pack", "(", "pop", ",", label, ")"] => popPack (SOME label)
              | "pack" :: _ => fail "unsupported pragma pack form"
              | _ => ()
        in () end
      fun loop acc = if not (isSome (peek ())) then
          if null (!packs) then {declarations = rev acc, pragmas = rev (!pragmas)} else fail "unbalanced pragma pack push"
        else if spelling () = "#" then (pragma (); loop acc)
        else if accept ";" then loop acc
        else loop (rev (declaration false) @ acc)
      val () = pragmaHandler := pragma
    in if typeOnly then
         let val (base,storage,_) = specifiers ()
             val (name,build) = declarator true
             val () = if null storage andalso not(isSome name) andalso not(isSome(peek()))
                      then () else fail "expected one abstract C type name"
         in {declarations=[Declaration{name=NONE,ctype=build base,storage=[],initializer=[],body=[],location= !last}],pragmas=[]} end
       else loop [] end
  fun translationUnit {tokens,predefinedTypes}=parse{tokens=tokens,predefinedTypes=predefinedTypes,typeOnly=false}
  fun typeName {tokens,predefinedTypes}=
    case #declarations(parse{tokens=tokens,predefinedTypes=predefinedTypes,typeOnly=true}) of
      [Declaration{ctype,...}]=>ctype | _=>raise Fail "C type parser result"
end
