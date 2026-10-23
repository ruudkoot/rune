(* Implements: FOREIGN_POLICY *)
structure ForeignPolicy : FOREIGN_POLICY =
struct
  datatype encoding = Bytes | Utf8 | Wtf8 | Utf16
  datatype direction = In | Out | InOut
  datatype ownership = Borrowed of string | Owned of string
  datatype extent = ParameterLength of string | FixedLength of IntInf.int
  datatype smlType = Scalar of string | Resource of string | Option of smlType
    | Vector of smlType | Array of smlType | Tuple of smlType list | Record of (string * smlType) list
  datatype tree = Unit | Value of string | Product of tree list | Fields of (string * tree) list
  type valuePolicy = {name : string option, direction : direction option, ownership : ownership option,
    nullable : bool option, encoding : encoding option, terminator : bool option, extent : extent option, callback : string option,
    projection : smlType option, output : string option, consumes : bool, source : ForeignModel.source}
  type errorPolicy = {predicate : string, capture : string, getter : string option}
  type functionPolicy = {foreign : string, namespace : string, name : string, raw : string option, parameters : valuePolicy list,
    result : valuePolicy, errors : errorPolicy, variadic : string, unsafeRaw : bool, adapter : string option, shim : string option,
    input : tree option, returns : tree option, source : ForeignModel.source}
  datatype failure = ConstantFailure of IntInf.int
    | ArgumentFailure of {parameter : string, cases : (string * IntInf.int) list, otherwise : IntInf.int}
  type callbackPolicy = {foreign : string, lifetime : string, owner : string option, thread : string,
    failure : failure, source : ForeignModel.source}
  type policy = {version : int, family : string, structureName : string, headers : string list,
    libraries : string list, resources : string list, functions : functionPolicy list, callbacks : callbackPolicy list,
    source : ForeignModel.source}
  exception Error = ForeignJson.Error
  val reserved = String.tokens Char.isSpace
    "abstype and andalso as case datatype do else end eqtype exception fn fun functor handle if in include infix infixr let local nonfix of op open orelse raise rec sharing sig signature struct structure then type val where while with withtype true false nil ref SOME NONE LESS EQUAL GREATER Match Bind Div Overflow Size Subscript Fail"
  fun alpha c = (c >= #"a" andalso c <= #"z") orelse (c >= #"A" andalso c <= #"Z")
  fun alnum c = alpha c orelse (c >= #"0" andalso c <= #"9")
  fun identifier s = size s > 0 andalso alpha (String.sub (s, 0)) andalso
    CharVector.all (fn c => alnum c orelse c = #"_" orelse c = #"'") s andalso
    not (List.exists (fn word => word = s) reserved)
  fun rawName s = if identifier s then s else
    "c_" ^ String.translate (fn c => if alnum c orelse c = #"_" then str c
      else "x" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c)) ^ "_") s
  fun decode input =
    let
      val doc = ForeignJson.decode input
      fun error path message = ForeignJson.error doc path message
      fun object path keys value = ForeignJson.object doc path keys value
      fun field path fields name = ForeignJson.member doc path fields name
      fun string path value = ForeignJson.string doc path value
      fun array path value = ForeignJson.array doc path value
      fun bool path value = ForeignJson.boolean doc path value
      fun optional path fields name convert = Option.map (convert (path @ [name])) (ForeignJson.optional fields name)
      fun name path value = let val s = string path value in if identifier s then s else error path ("invalid SML name: " ^ s) end
      fun qualified path value =
        let val s = string path value
        in if List.all identifier (String.fields (fn c => c = #".") s) then s else error path ("invalid SML path: " ^ s) end
      fun oneOf path choices value = let val s = string path value
        in if List.exists (fn choice => s = choice) choices then s else error path ("unsupported value: " ^ s) end
      fun integer path (Json.Number s) =
            (case IntInf.fromString (if String.isPrefix "-" s then "~" ^ String.extract (s, 1, NONE) else s) of SOME n => if CharVector.all (fn c => Char.isDigit c orelse c = #"-") s then n
              else error path "expected an integer" | NONE => error path "expected an integer")
        | integer path _ = error path "expected an integer"
      fun indexed f path values = ListPair.map (fn (i, value) => f (path @ [Int.toString i]) value)
        (List.tabulate (length values, fn i => i), values)
      fun strings path value = indexed string path (array path value)
      val scalars = ["unit", "bool", "int", "int8", "word8", "int16", "word16", "int32", "word32", "int64", "word64", "real", "string", "bytes"]
      fun projection path (Json.String s) = if List.exists (fn t => t = s) scalars then Scalar s else error path ("unknown SML scalar: " ^ s)
        | projection path value =
          (case object path ["resource", "option", "vector", "array", "tuple", "record"] value of
             [("resource", v)] => Resource (name (path @ ["resource"]) v)
           | [("option", v)] => Option (projection (path @ ["option"]) v)
           | [("vector", v)] => Vector (projection (path @ ["vector"]) v)
           | [("array", v)] => Array (projection (path @ ["array"]) v)
           | [("tuple", v)] => Tuple (indexed projection (path @ ["tuple"]) (array (path @ ["tuple"]) v))
           | [("record", Json.Object fields)] =>
               let val names = List.map #1 fields
                   val _ = object (path @ ["record"]) names (Json.Object fields)
               in Record (List.map (fn (n, v) => (name (path @ ["record", n]) (Json.String n), projection (path @ ["record", n]) v)) fields) end
           | _ => error path "expected exactly one structured projection constructor")
      fun ownership path value = case object path ["borrowed", "owned"] value of
          [("borrowed", v)] => Borrowed (string (path @ ["borrowed"]) v)
        | [("owned", v)] => Owned (string (path @ ["owned"]) v)
        | _ => error path "expected one ownership rule"
      fun tree path (Json.String s) = Value s
        | tree path value =
          (case object path ["unit", "tuple", "record"] value of
             [("unit", Json.Bool true)] => Unit
           | [("tuple", value)] => Product (indexed tree (path @ ["tuple"]) (array (path @ ["tuple"]) value))
           | [("record", Json.Object fields)] =>
               let val _ = object (path @ ["record"]) (List.map #1 fields) (Json.Object fields)
               in Fields (List.map (fn (label, value) => (name (path @ ["record", label]) (Json.String label),
                    tree (path @ ["record", label]) value)) fields) end
           | _ => error path "expected one projection grouping constructor")
      fun extent path value = case value of Json.String s => ParameterLength s
        | _ => let val n = integer path value in if n >= 0 then FixedLength n else error path "negative buffer length" end
      fun valuePolicy path value : valuePolicy =
        let val fs = object path ["name", "direction", "ownership", "nullable", "encoding", "terminator", "length", "callback", "type", "output", "consumes"] value
            fun direction path value = case oneOf path ["in", "out", "inout"] value of "in" => In | "out" => Out | _ => InOut
            fun encoding path value = case oneOf path ["bytes", "utf8", "wtf8", "utf16"] value of
                "bytes" => Bytes | "utf8" => Utf8 | "wtf8" => Wtf8 | _ => Utf16
        in {name = optional path fs "name" string, direction = optional path fs "direction" direction,
          ownership = optional path fs "ownership" ownership, nullable = optional path fs "nullable" bool,
          encoding = optional path fs "encoding" encoding, terminator = optional path fs "terminator" bool, extent = optional path fs "length" extent,
          callback = optional path fs "callback" string, projection = optional path fs "type" projection,
          output = optional path fs "output" name,
          consumes = getOpt (optional path fs "consumes" bool, false), source = ForeignJson.location doc path} end
      fun errors path value : errorPolicy =
        let val fs = object path ["predicate", "capture", "getter"] value
        in {predicate = oneOf (path @ ["predicate"]) ["none", "null", "false", "negative", "zero", "nonzero", "minus-one"] (field path fs "predicate"),
          capture = oneOf (path @ ["capture"]) ["none", "errno", "win32", "text"] (field path fs "capture"),
          getter = optional path fs "getter" string} end
      fun function path value : functionPolicy =
        let val fs = object path ["foreign", "namespace", "name", "raw", "parameters", "result", "errors", "variadic", "unsafeRaw", "adapter", "shim", "input", "returns"] value
        in {foreign = string (path @ ["foreign"]) (field path fs "foreign"),
          namespace = getOpt(optional path fs "namespace" (fn whereAt=>oneOf whereAt ["function","macro"]),"function"),
          name = qualified (path @ ["name"]) (field path fs "name"), raw = optional path fs "raw" name,
          parameters = indexed valuePolicy (path @ ["parameters"]) (array (path @ ["parameters"]) (field path fs "parameters")),
          result = valuePolicy (path @ ["result"]) (field path fs "result"),
          errors = errors (path @ ["errors"]) (field path fs "errors"),
          variadic = oneOf (path @ ["variadic"]) ["reject", "raw"] (field path fs "variadic"),
          unsafeRaw = bool (path @ ["unsafeRaw"]) (field path fs "unsafeRaw"),
          adapter = optional path fs "adapter" string, shim = optional path fs "shim" string, input = optional path fs "input" tree,
          returns = optional path fs "returns" tree, source = ForeignJson.location doc path} end
      fun failure path (value as Json.Number _) = ConstantFailure (integer path value)
        | failure path value =
          let val fs = object path ["parameter", "cases", "otherwise"] value
              val cases = case field path fs "cases" of Json.Object fields => fields | _ => error (path @ ["cases"]) "expected failure cases"
              val _ = object (path @ ["cases"]) (List.map #1 cases) (Json.Object cases)
          in ArgumentFailure {parameter = string (path @ ["parameter"]) (field path fs "parameter"),
            cases = List.map (fn (name, value) => (name, integer (path @ ["cases", name]) value)) cases,
            otherwise = integer (path @ ["otherwise"]) (field path fs "otherwise")} end
      fun callback path value : callbackPolicy =
        let val fs = object path ["foreign", "lifetime", "owner", "thread", "failure"] value
        in {foreign = string (path @ ["foreign"]) (field path fs "foreign"),
          lifetime = oneOf (path @ ["lifetime"]) ["call", "registered"] (field path fs "lifetime"),
          owner = optional path fs "owner" string,
          thread = oneOf (path @ ["thread"]) ["owner-vm-thread"] (field path fs "thread"),
          failure = failure (path @ ["failure"]) (field path fs "failure"), source = ForeignJson.location doc path} end
      val fs = object [] ["version", "family", "structure", "headers", "libraries", "resources", "functions", "callbacks"] (ForeignJson.value doc)
      val version = integer ["version"] (field [] fs "version")
      val () = if version = 1 then () else error ["version"] "unsupported sidecar version"
    in {version = 1, family = oneOf ["family"] ["c"] (field [] fs "family"),
      structureName = name ["structure"] (field [] fs "structure"), headers = strings ["headers"] (field [] fs "headers"),
      libraries = strings ["libraries"] (field [] fs "libraries"),
      resources = getOpt(optional [] fs "resources" (fn path => fn value => indexed name path (array path value)),[]),
      functions = indexed function ["functions"] (array ["functions"] (field [] fs "functions")),
      callbacks = indexed callback ["callbacks"] (array ["callbacks"] (field [] fs "callbacks")),
      source = ForeignJson.location doc []} end
end
