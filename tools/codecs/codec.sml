(* The language the compiler's codecs are described in (the build-system
   roadmap's D21, M5; docs/units.md, Codecs): a type is its constructors,
   each its fields, and each field has its marks -- the layer of a unit's
   basis it is written to (D1: static, ABI, the sidecar) and the codec it is
   written by -- and each constructor says which of its fields its
   fingerprint holds, by what canonical bytes, and which a sameness of two
   bindings compares. A field no traversal names is refused unless it is
   said, with a reason, to be left out of it, so that a field added to a
   type is marked for every traversal before anything is generated; and the
   generated code takes every value apart with patterns that name every
   field, so that a field added to the type and not to its description is
   a compile error. CodecEmit writes the traversals; CodecCompiler is the
   compiler's description. *)
structure Codec =
struct
  exception Refused of string
  fun refuse msg = raise Refused msg

  (* a description is written as a value piped through its marks *)
  infix 1 |>
  fun x |> f = f x

  (* where a field's bytes go: the layer being written (a basis's static
     layer, or the ABI layer where the ABI layer writes a whole entry), the
     ABI layer always, or the sidecar, which no hash reads *)
  datatype layer = Static | Abi | Side

  (* how a field is written *)
  datatype codec =
      Leaf of string                    (* a codec its family writes by hand, by name *)
    | Type of string                    (* a described type of the same family *)
    | List of codec
    | Option of codec
    | Tuple of codec list
    | Map of codec                      (* a StringMap.map, its entries in the order of their names *)
    | Shared of string * codec          (* written once and then by its number: the table's name *)

  type field = {name : string, layer : layer, codec : codec}

  (* an item of a fingerprint: a field by its codec's canonical bytes, or a
     text over fields ({f}, {f.g}), which the generator fills in; Full: not
     in the static layer's fingerprint (D1) *)
  datatype guard = Both | Full
  datatype fp = FpField of guard * string | FpText of guard * string
  (* an item of a sameness: a field by its codec's sameness, or by a
     function of it compared with = *)
  datatype same = SameField of string | SameVia of string * string

  (* how a constructor holds its fields: C {f, ...}; C (f1, ..., fn) or C f;
     C *)
  datatype shape = Record | Args | Nullary

  type part = {con : string,                          (* the constructor in a pattern; "" for a record type *)
               build : string,                        (* how a value is made of the fields *)
               shape : shape,
               fields : field list,                   (* in the order of their bytes *)
               fpTag : int option,                    (* the byte a fingerprint begins with *)
               fp : fp list, fpOut : (string * string) list,
               same : same list, sameOut : (string * string) list,
               writeAs : string option,               (* written as this field, which is of the type: no reader makes it *)
               note : string option}                  (* a codec of the family told of the whole value first *)

  type ty = {name : string,                            (* the description's name *)
             sml : string,                             (* the SML type *)
             view : string option,                     (* a function whose result the patterns take apart *)
             tagLayer : layer,                         (* where a sum's byte goes *)
             parts : part list,                        (* a sum's constructors in the order of their bytes; a record's one *)
             sum : bool,
             fp : bool, same : bool}                   (* whether it has a fingerprint, a sameness *)

  (* ---- writing a description ---- *)

  fun field (name, codec) : field = {name = name, layer = Static, codec = codec}
  fun abi (name, codec) : field = {name = name, layer = Abi, codec = codec}
  fun side (name, codec) : field = {name = name, layer = Side, codec = codec}

  fun part (con, build, shape, fields) : part =
    {con = con, build = build, shape = shape, fields = fields, fpTag = NONE, fp = [], fpOut = [], same = [],
     sameOut = [], writeAs = NONE, note = NONE}
  fun record (con, fields) = part (con, con, Record, fields)
  fun args (con, fields) = part (con, con, Args, fields)
  fun nullary con = part (con, con, Nullary, [])

  fun fingerprint (tag, items, out) ({con, build, shape, fields, same, sameOut, writeAs, note, ...} : part) : part =
    {con = con, build = build, shape = shape, fields = fields, fpTag = tag, fp = items, fpOut = out, same = same,
     sameOut = sameOut, writeAs = writeAs, note = note}
  fun sameness (items, out) ({con, build, shape, fields, fpTag, fp, fpOut, writeAs, note, ...} : part) : part =
    {con = con, build = build, shape = shape, fields = fields, fpTag = fpTag, fp = fp, fpOut = fpOut, same = items,
     sameOut = out, writeAs = writeAs, note = note}
  fun writtenAs f ({con, build, shape, fields, fpTag, fp, fpOut, same, sameOut, note, ...} : part) : part =
    {con = con, build = build, shape = shape, fields = fields, fpTag = fpTag, fp = fp, fpOut = fpOut, same = same,
     sameOut = sameOut, writeAs = SOME f, note = note}
  fun noted n ({con, build, shape, fields, fpTag, fp, fpOut, same, sameOut, writeAs, ...} : part) : part =
    {con = con, build = build, shape = shape, fields = fields, fpTag = fpTag, fp = fp, fpOut = fpOut, same = same,
     sameOut = sameOut, writeAs = writeAs, note = SOME n}
  fun built b ({con, shape, fields, fpTag, fp, fpOut, same, sameOut, writeAs, note, ...} : part) : part =
    {con = con, build = b, shape = shape, fields = fields, fpTag = fpTag, fp = fp, fpOut = fpOut, same = same,
     sameOut = sameOut, writeAs = writeAs, note = note}
  (* the part with its fields changed by f (a description made from another) *)
  fun withFields f ({con, build, shape, fields, fpTag, fp, fpOut, same, sameOut, writeAs, note} : part) : part =
    {con = con, build = build, shape = shape, fields = f fields, fpTag = fpTag, fp = fp, fpOut = fpOut, same = same,
     sameOut = sameOut, writeAs = writeAs, note = note}

  fun sum (name, sml, parts) : ty =
    {name = name, sml = sml, view = NONE, tagLayer = Static, parts = parts, sum = true, fp = true, same = true}
  fun recordType (name, sml, p) : ty =
    {name = name, sml = sml, view = NONE, tagLayer = Static, parts = [p], sum = false, fp = true, same = true}
  fun viewed v ({name, sml, tagLayer, parts, sum, fp, same, ...} : ty) : ty =
    {name = name, sml = sml, view = SOME v, tagLayer = tagLayer, parts = parts, sum = sum, fp = fp, same = same}
  fun tagIn l ({name, sml, view, parts, sum, fp, same, ...} : ty) : ty =
    {name = name, sml = sml, view = view, tagLayer = l, parts = parts, sum = sum, fp = fp, same = same}
  (* a type with no fingerprint, or no sameness, of its own *)
  fun noFp ({name, sml, view, tagLayer, parts, sum, same, ...} : ty) : ty =
    {name = name, sml = sml, view = view, tagLayer = tagLayer, parts = parts, sum = sum, fp = false, same = same}
  fun noSame ({name, sml, view, tagLayer, parts, sum, fp, ...} : ty) : ty =
    {name = name, sml = sml, view = view, tagLayer = tagLayer, parts = parts, sum = sum, fp = fp, same = false}
  fun renamed (name, sml) ({view, tagLayer, parts, sum, fp, same, ...} : ty) : ty =
    {name = name, sml = sml, view = view, tagLayer = tagLayer, parts = parts, sum = sum, fp = fp, same = same}
  fun withParts f ({name, sml, view, tagLayer, parts, sum, fp, same} : ty) : ty =
    {name = name, sml = sml, view = view, tagLayer = tagLayer, parts = f parts, sum = sum, fp = fp, same = same}

  (* ---- the families: how a set of types is written ---- *)

  (* A codec a family writes by hand: texts of SML over {e} (the writer's
     argument), {w} (the stream of the field's layer), {x} (the value),
     {d} and {r} (the reader's argument and stream), {y} (the other value
     of a sameness), {k} (a key's writer); the layers it may be written to,
     and what a reader takes where the sidecar is absent; other values than
     {x}, a list, for the fingerprint oracle, and whether its fingerprint is
     in the static layer's (an anchor is not: fpAnchored) *)
  type leaf = {write : string, read : string, same : string, fp : string, key : string, layers : layer list,
               default : string, other : string, static : bool}

  type family = {name : string,
                 wparam : string, warg : string, wstream : layer -> string,
                 rparam : string, rarg : string, rstream : layer -> string,
                 fpparam : string, fparg : string,
                 static : string,               (* true where the static layer's fingerprint is being made *)
                 side : string,                 (* the sidecar's reader, an option *)
                 once : string, ronce : string, (* a shared value: {t} its table, {key}, {body} *)
                 bad : string,                  (* the exception a reader raises *)
                 binder : string option,        (* the leaf whose values a function binds *)
                 leaves : (string * leaf) list,
                 notes : (string * string) list}

  (* what is generated of a type in a family, and where: each traversal's
     function, "" for none, and its region *)
  datatype traversal = Write | Read | Same | Fp | Key | Binds | Perturb
  type instance = {family : string, ty : string,
                   names : (traversal * string) list,
                   share : {tag : int, id : string, table : string, count : string, rtable : string, rcount : string} option,
                   bad : string}

  (* a part of a file the generator writes: its traversals of instances, in
     order, the first introduced by start ("fun" or "and"), the rest by "and" *)
  type region = {file : string, name : string, start : string, items : (string * string * traversal) list}

  type description = {types : ty list, families : family list, instances : instance list, regions : region list}

  fun traversalName t =
    case t of Write => "writer" | Read => "reader" | Same => "sameness" | Fp => "fingerprint" | Key => "key" | Binds => "binders"
            | Perturb => "changes"
end
