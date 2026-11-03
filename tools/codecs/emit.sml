(* The traversals a description gives (Codec), as SML: of each type in a
   family, its writer, its reader, its sameness, its fingerprint, the key of
   a value written once, and the names it binds. Each takes a value apart
   with a pattern that names every field, "_" for one it does not read. *)
structure CodecEmit =
struct
  open Codec

  (* ---- texts ---- *)

  (* template with each {key} of pairs given its value; a { } of no key is
     the template's own *)
  fun subst (template : string, pairs : (string * string) list) : string =
    let
      val n = String.size template
      fun close i = if i >= n then NONE else if String.sub (template, i) = #"}" then SOME i else close (i + 1)
      fun go (i, acc) =
        if i >= n then String.concat (List.rev acc)
        else if String.sub (template, i) = #"{" then
          case close (i + 1) of
            SOME j =>
              (case List.find (fn (k, _) => k = String.substring (template, i + 1, j - i - 1)) pairs of
                 SOME (_, v) => go (j + 1, v :: acc)
               | NONE => go (i + 1, "{" :: acc))
          | NONE => go (i + 1, "{" :: acc)
        else go (i + 1, String.str (String.sub (template, i)) :: acc)
    in go (0, []) end

  (* the names {a} and {a.b} a template gives, by their first part *)
  fun placeholders (template : string) : string list =
    let
      val n = String.size template
      fun go (i, acc) =
        if i >= n then List.rev acc
        else if String.sub (template, i) = #"{" then
          let
            fun close j = if j >= n then NONE else if String.sub (template, j) = #"}" then SOME j else close (j + 1)
          in
            case close (i + 1) of
              SOME j => go (j + 1, String.substring (template, i + 1, j - i - 1) :: acc)
            | NONE => go (i + 1, acc)
          end
        else go (i + 1, acc)
    in go (0, []) end

  fun atomic (s : string) : string =
    if CharVector.exists (fn c => c = #" ") s andalso not (String.isPrefix "(" s andalso String.isSuffix ")" s) then "(" ^ s ^ ")" else s

  fun seq [] = "()"
    | seq [x] = x
    | seq xs = "(" ^ String.concatWith "; " xs ^ ")"

  fun conj [] = "true"
    | conj xs = String.concatWith " andalso " xs

  (* the variable a field is bound to: its name and a prime, so that no
     field shadows a function of the family; and the two of a sameness *)
  fun var (f : string) = f ^ "'"
  fun var1 (f : string) = f ^ "'1"
  fun var2 (f : string) = f ^ "'2"

  val counter = ref 0
  fun fresh (p : string) = (counter := !counter + 1; p ^ "_" ^ Int.toString (!counter))

  (* ---- the description ---- *)

  type cx = {desc : description, fam : family}

  fun family (d : description, name : string) : family =
    case List.find (fn (f : family) => #name f = name) (#families d) of
      SOME f => f
    | NONE => refuse ("no family " ^ name)
  fun typeOf (d : description, name : string) : ty =
    case List.find (fn (t : ty) => #name t = name) (#types d) of
      SOME t => t
    | NONE => refuse ("no type " ^ name)
  fun instanceOf (d : description, fam : string, ty : string) : instance =
    case List.find (fn (i : instance) => #family i = fam andalso #ty i = ty) (#instances d) of
      SOME i => i
    | NONE => refuse ("the type " ^ ty ^ " has no instance in the family " ^ fam)
  fun nameIn (i : instance, t : traversal) : string =
    case List.find (fn (t', _) => t' = t) (#names i) of
      SOME (_, n) => n
    | NONE => refuse ("the type " ^ #ty i ^ " has no " ^ traversalName t ^ " in the family " ^ #family i)
  fun nameOf (cx : cx, ty : string, t : traversal) : string = nameIn (instanceOf (#desc cx, #name (#fam cx), ty), t)
  fun leaf (cx : cx, n : string) : leaf =
    case List.find (fn (k, _) => k = n) (#leaves (#fam cx)) of
      SOME (_, l) => l
    | NONE => refuse ("the family " ^ #name (#fam cx) ^ " has no codec " ^ n)

  fun layerName l = case l of Static => "static" | Abi => "ABI" | Side => "sidecar"

  (* a codec at a layer: each of its codecs written by hand may be *)
  fun checkLayer (cx : cx, where' : string, cd : codec, l : layer) : unit =
    case cd of
      Leaf n => if List.exists (fn x => x = l) (#layers (leaf (cx, n))) then ()
                else refuse (where' ^ ": the codec " ^ n ^ " is not written to the " ^ layerName l ^ " layer")
    | Type t => ignore (typeOf (#desc cx, t))
    | List c => checkLayer (cx, where', c, l)
    | Option c => checkLayer (cx, where', c, l)
    | Tuple cs => List.app (fn c => checkLayer (cx, where', c, l)) cs
    | Map c => checkLayer (cx, where', c, l)
    | Shared (_, c) => checkLayer (cx, where', c, l)

  (* what a reader takes for a field of the sidecar where there is none *)
  fun default (cx : cx, where' : string, cd : codec) : string =
    case cd of
      Leaf n => (case #default (leaf (cx, n)) of "" => refuse (where' ^ ": the codec " ^ n ^ " has no value without a sidecar") | v => v)
    | List _ => "[]"
    | Option _ => "NONE"
    | Map _ => "StringMap.empty"
    | Shared (_, c) => default (cx, where', c)
    | _ => refuse (where' ^ ": a field of the sidecar with no value without one")

  (* ---- expressions, by codec ---- *)

  fun wexp (cx : cx, cd : codec, l : layer, x : string) : string =
    let
      val fam = #fam cx
      val s = #wstream fam l
    in
      case cd of
        Leaf n => subst (#write (leaf (cx, n)), [("e", #warg fam), ("w", s), ("x", x)])
      | Type t => nameOf (cx, t, Write) ^ " (" ^ #warg fam ^ ", " ^ x ^ ")"
      | List c => let val y = fresh "x" in "P.list (fn (_, " ^ y ^ ") => " ^ wexp (cx, c, l, y) ^ ") (" ^ s ^ ", " ^ x ^ ")" end
      | Option c => let val y = fresh "x" in "P.option (fn (_, " ^ y ^ ") => " ^ wexp (cx, c, l, y) ^ ") (" ^ s ^ ", " ^ x ^ ")" end
      | Tuple cs =>
          let val ys = List.map (fn _ => fresh "x") cs
          in "(case " ^ x ^ " of (" ^ String.concatWith ", " ys ^ ") => "
             ^ seq (ListPair.map (fn (c, y) => wexp (cx, c, l, y)) (cs, ys)) ^ ")" end
      | Map c =>
          let val n = fresh "n" val y = fresh "x"
          in "P.list (fn (_, (" ^ n ^ ", " ^ y ^ ")) => (P.string (" ^ s ^ ", " ^ n ^ "); " ^ wexp (cx, c, l, y) ^ ")) ("
             ^ s ^ ", StringMap.listItemsi " ^ x ^ ")" end
      | Shared (t, c) =>
          subst (#once fam, [("t", t), ("e", #warg fam), ("w", s), ("key", keyExp (cx, c, x)), ("body", wexp (cx, c, l, x))])
    end

  (* a value's key: its bytes, every field written plainly *)
  and keyExp (cx : cx, cd : codec, x : string) : string =
    let val k = fresh "k"
    in "let val " ^ k ^ " = P.writer () in " ^ kexp (cx, cd, k, x) ^ "; P.contents " ^ k ^ " end" end

  and kexp (cx : cx, cd : codec, k : string, x : string) : string =
    case cd of
      Leaf n => (case #key (leaf (cx, n)) of
                   "" => refuse ("the codec " ^ n ^ " has no key, and a value written once must")
                 | t => subst (t, [("k", k), ("x", x)]))
    | Type t => nameOf (cx, t, Key) ^ " (" ^ k ^ ", " ^ x ^ ")"
    | List c => let val y = fresh "x" in "P.list (fn (_, " ^ y ^ ") => " ^ kexp (cx, c, k, y) ^ ") (" ^ k ^ ", " ^ x ^ ")" end
    | Option c => let val y = fresh "x" in "P.option (fn (_, " ^ y ^ ") => " ^ kexp (cx, c, k, y) ^ ") (" ^ k ^ ", " ^ x ^ ")" end
    | Tuple cs =>
        let val ys = List.map (fn _ => fresh "x") cs
        in "(case " ^ x ^ " of (" ^ String.concatWith ", " ys ^ ") => "
           ^ seq (ListPair.map (fn (c, y) => kexp (cx, c, k, y)) (cs, ys)) ^ ")" end
    | Map c =>
        let val n = fresh "n" val y = fresh "x"
        in "P.list (fn (_, (" ^ n ^ ", " ^ y ^ ")) => (P.string (" ^ k ^ ", " ^ n ^ "); " ^ kexp (cx, c, k, y) ^ ")) ("
           ^ k ^ ", StringMap.listItemsi " ^ x ^ ")" end
    | Shared (_, c) => kexp (cx, c, k, x)

  fun rexp (cx : cx, cd : codec, r : string) : string =
    let val fam = #fam cx
    in
      case cd of
        Leaf n => subst (#read (leaf (cx, n)), [("d", #rarg fam), ("r", r)])
      | Type t => nameOf (cx, t, Read) ^ " " ^ atomic (#rarg fam)
      | List c => "P.rlist (fn _ => " ^ rexp (cx, c, r) ^ ") " ^ atomic r
      | Option c => "P.roption (fn _ => " ^ rexp (cx, c, r) ^ ") " ^ atomic r
      | Tuple cs =>
          let val ys = List.map (fn _ => fresh "x") cs
          in "let " ^ String.concatWith " " (ListPair.map (fn (c, y) => "val " ^ y ^ " = " ^ rexp (cx, c, r)) (cs, ys))
             ^ " in (" ^ String.concatWith ", " ys ^ ") end" end
      | Map c =>
          let val n = fresh "n"
          in "StringMap.fromList (P.rlist (fn _ => let val " ^ n ^ " = P.rstring " ^ atomic r ^ " in (" ^ n ^ ", "
             ^ rexp (cx, c, r) ^ ") end) " ^ atomic r ^ ")" end
      | Shared (t, c) => subst (#ronce fam, [("t", t), ("d", #rarg fam), ("r", r), ("body", rexp (cx, c, r))])
    end

  fun sexp (cx : cx, cd : codec, x : string, y : string) : string =
    case cd of
      Leaf n => (case #same (leaf (cx, n)) of
                   "" => refuse ("the codec " ^ n ^ " has no sameness")
                 | t => subst (t, [("x", x), ("y", y)]))
    | Type t => nameOf (cx, t, Same) ^ " (" ^ x ^ ", " ^ y ^ ")"
    | List c => let val a = fresh "x" val b = fresh "y"
                in "ListPair.allEq (fn (" ^ a ^ ", " ^ b ^ ") => " ^ sexp (cx, c, a, b) ^ ") (" ^ x ^ ", " ^ y ^ ")" end
    | Option c => let val a = fresh "x" val b = fresh "y"
                  in "(case (" ^ x ^ ", " ^ y ^ ") of (NONE, NONE) => true | (SOME " ^ a ^ ", SOME " ^ b ^ ") => "
                     ^ sexp (cx, c, a, b) ^ " | _ => false)" end
    | Tuple cs =>
        let val xs = List.map (fn _ => fresh "x") cs val ys = List.map (fn _ => fresh "y") cs
        in "(case (" ^ x ^ ", " ^ y ^ ") of ((" ^ String.concatWith ", " xs ^ "), (" ^ String.concatWith ", " ys ^ ")) => "
           ^ conj (List.map (fn (c, (a, b)) => sexp (cx, c, a, b)) (ListPair.zip (cs, ListPair.zip (xs, ys)))) ^ ")" end
    | Map c => let val a = fresh "x" val b = fresh "y"
               in "sameMap (fn (" ^ a ^ ", " ^ b ^ ") => " ^ sexp (cx, c, a, b) ^ ") (" ^ x ^ ", " ^ y ^ ")" end
    | Shared (_, c) => sexp (cx, c, x, y)

  fun fexp (cx : cx, cd : codec, x : string) : string =
    case cd of
      Leaf n => (case #fp (leaf (cx, n)) of
                   "" => refuse ("the codec " ^ n ^ " has no fingerprint")
                 | t => subst (t, [("x", x)]))
    | Type t => nameOf (cx, t, Fp) ^ " (" ^ #fparg (#fam cx) ^ ", " ^ x ^ ")"
    | List c => let val y = fresh "x" in "(P.nat (w, List.length " ^ x ^ "); List.app (fn " ^ y ^ " => " ^ fexp (cx, c, y) ^ ") " ^ x ^ ")" end
    | Option c => let val y = fresh "x" in "P.option (fn (_, " ^ y ^ ") => " ^ fexp (cx, c, y) ^ ") (w, " ^ x ^ ")" end
    | Tuple cs =>
        let val ys = List.map (fn _ => fresh "x") cs
        in "(case " ^ x ^ " of (" ^ String.concatWith ", " ys ^ ") => " ^ seq (ListPair.map (fn (c, y) => fexp (cx, c, y)) (cs, ys)) ^ ")" end
    | Map c =>
        let val n = fresh "n" val y = fresh "x"
        in "(P.nat (w, StringMap.numItems " ^ x ^ "); StringMap.appi (fn (" ^ n ^ ", " ^ y ^ ") => (P.string (w, " ^ n ^ "); "
           ^ fexp (cx, c, y) ^ ")) " ^ x ^ ")" end
    | Shared (_, c) => fexp (cx, c, x)

  (* ---- the names a function binds ---- *)

  fun binds (cx : cx, cd : codec) : bool =
    let
      val seen = ref []
      fun go cd =
        case cd of
          Leaf n => #binder (#fam cx) = SOME n
        | Type t =>
            if List.exists (fn s => s = t) (!seen) then false
            else (seen := t :: !seen;
                  List.exists (fn (p : part) => List.exists (fn (f : field) => go (#codec f)) (#fields p)) (#parts (typeOf (#desc cx, t))))
        | List c => go c
        | Option c => go c
        | Tuple cs => List.exists go cs
        | Map c => go c
        | Shared (_, c) => go c
    in go cd end

  fun bexp (cx : cx, cd : codec, x : string) : string =
    case cd of
      Leaf _ => "IntTable.insert (t, " ^ x ^ ", ())"
    | Type t => nameOf (cx, t, Binds) ^ " (t, " ^ x ^ ")"
    | List c => let val y = fresh "x" in "List.app (fn " ^ y ^ " => " ^ bexp (cx, c, y) ^ ") " ^ x end
    | Option c => let val y = fresh "x" in "Option.app (fn " ^ y ^ " => " ^ bexp (cx, c, y) ^ ") " ^ x end
    | Tuple cs =>
        let val ys = List.map (fn c => if binds (cx, c) then fresh "x" else "_") cs
        in "(case " ^ x ^ " of (" ^ String.concatWith ", " ys ^ ") => "
           ^ seq (List.mapPartial (fn (c, y) => if y = "_" then NONE else SOME (bexp (cx, c, y))) (ListPair.zip (cs, ys))) ^ ")" end
    | Map c => let val y = fresh "x" in "StringMap.app (fn " ^ y ^ " => " ^ bexp (cx, c, y) ^ ") " ^ x end
    | Shared (_, c) => bexp (cx, c, x)

  (* ---- patterns ---- *)

  (* a part's pattern, each field bound by bound, or "_" *)
  fun pattern (p : part, bound : string -> string option) : string =
    let
      fun b (f : field) = getOpt (bound (#name f), "_")
      val body =
        case #shape p of
          Record => "{" ^ String.concatWith ", " (List.map (fn f => #name f ^ " = " ^ b f) (#fields p)) ^ "}"
        | Args => (case #fields p of
                     [f] => b f
                   | fs => "(" ^ String.concatWith ", " (List.map b fs) ^ ")")
        | Nullary => ""
    in
      case (#con p, body) of
        ("", _) => body
      | (c, "") => c
      | (c, _) => c ^ " " ^ body
    end

  fun constructBy (p : part, var : string -> string) : string =
    let
      val body =
        case #shape p of
          Record => "{" ^ String.concatWith ", " (List.map (fn f => #name f ^ " = " ^ var (#name f)) (#fields p)) ^ "}"
        | Args => (case #fields p of
                     [f] => var (#name f)
                   | fs => "(" ^ String.concatWith ", " (List.map (fn f => var (#name f)) fs) ^ ")")
        | Nullary => ""
    in
      case (#build p, body) of
        ("", _) => body
      | (c, "") => c
      | (c, _) => c ^ " " ^ body
    end
  fun construct (p : part) : string = constructBy (p, var)

  fun fieldOf (p : part, n : string) : field =
    case List.find (fn (f : field) => #name f = n) (#fields p) of
      SOME f => f
    | NONE => refuse ((if #con p = "" then "a record" else #con p) ^ " has no field " ^ n)

  fun whereOf (t : ty, p : part) = if #con p = "" then #sml t else #con p

  (* the fields an item of a fingerprint or of a sameness reads *)
  fun fpFields (p : part, item : fp) : string list =
    case item of
      FpField (_, f) => [#name (fieldOf (p, f))]
    | FpText (_, t) =>
        List.map (fn h => #name (fieldOf (p, case String.fields (fn c => c = #".") h of f :: _ => f | [] => h))) (placeholders t)
  fun sameFields (p : part, item : same) : string list =
    case item of
      SameField f => [#name (fieldOf (p, f))]
    | SameVia (_, f) => [#name (fieldOf (p, f))]

  fun member (x : string, l : string list) = List.exists (fn y => y = x) l

  (* every field of p read by the traversal or left out of it, with a
     reason, and none both *)
  fun covered (what : string, t : ty, p : part, used : string list, out : (string * string) list) : unit =
    (List.app (fn (f, why) => (ignore (fieldOf (p, f));
                               if why = "" then refuse (whereOf (t, p) ^ ": the field " ^ f ^ " is left out of its " ^ what ^ " with no reason")
                               else if member (f, used) then refuse (whereOf (t, p) ^ ": the field " ^ f ^ " is both in its " ^ what ^ " and left out of it")
                               else ())) out;
     List.app (fn (f : field) =>
                 if member (#name f, used) orelse List.exists (fn (g, _) => g = #name f) out then ()
                 else refuse (whereOf (t, p) ^ ": the field " ^ #name f ^ " is in no " ^ what ^ ", nor left out of it with a reason"))
              (#fields p))

  (* ---- the functions ---- *)

  fun header (kw : string, name : string, params : string, result : string) =
    "  " ^ kw ^ " " ^ name ^ " (" ^ params ^ ") : " ^ result ^ " ="

  fun viewOf (t : ty, v : string) = case #view t of SOME f => f ^ " " ^ v | NONE => v

  (* the parts of a sum with their bytes: those written as themselves *)
  fun numbered (t : ty) : (int * part) list =
    #2 (List.foldl (fn (p, (i, acc)) => case #writeAs p of
                                          SOME _ => (i, acc @ [(~1, p)])
                                        | NONE => (i + 1, acc @ [(i, p)])) (0, []) (#parts t))

  (* An arm's body is one line where it fits in a line of 110, and else one
     line for each part of it: a body marks where it breaks, \001 a part of a
     sequence, \002 a declaration of a let, \003 its in *)
  fun spaces n = CharVector.tabulate (n, fn _ => #" ")
  fun flat (body : string) : string =
    String.translate (fn #"\001" => " " | #"\002" => " " | #"\003" => " " | c => String.str c) body
  fun broken (indent : int, body : string) : string =
    String.translate (fn #"\001" => "\n" ^ spaces (indent + 1) | #"\002" => "\n" ^ spaces (indent + 2)
                       | #"\003" => "\n" ^ spaces indent | c => String.str c) body
  fun arm (lead : string, pat : string, body : string) : string =
    let val line = lead ^ pat ^ " => " ^ flat body
    in if String.size line <= 110 then line else lead ^ pat ^ " =>\n" ^ spaces 8 ^ broken (8, body) end
  (* a sequence, a let and a conjunction that may break *)
  fun seqTop [] = "()"
    | seqTop [x] = x
    | seqTop xs = "(" ^ String.concatWith ";\001" xs ^ ")"
  fun letTop ([], e) = e
    | letTop (ds, e) = "let\002" ^ String.concatWith "\002" ds ^ "\003in " ^ e ^ " end"
  fun conjTop [] = "true"
    | conjTop xs = String.concatWith "\001andalso " xs

  fun cases (scrutinee : string, arms : (string * string) list, last : string option) : string =
    "    case " ^ scrutinee ^ " of\n"
    ^ String.concatWith "\n" (ListPair.map (fn (i, (pat, e)) => arm (if i = 0 then "      " else "    | ", pat, e))
                                           (List.tabulate (List.length arms, fn i => i), arms))
    ^ (case last of SOME e => "\n    | " ^ e | NONE => "")

  fun writer (cx : cx, kw : string, t : ty, i : instance) : string =
    let
      val fam = #fam cx
      val () = counter := 0
      fun arm (n, p : part) =
        case #writeAs p of
          SOME f => (pattern (p, fn g => if g = f then SOME (var g) else NONE), nameIn (i, Write) ^ " (" ^ #warg fam ^ ", " ^ var f ^ ")")
        | NONE =>
            let
              val note = case #note p of
                           SOME k => (case List.find (fn (k', _) => k' = k) (#notes fam) of
                                        SOME (_, "") => []
                                      | SOME (_, tpl) => [subst (tpl, [("e", #warg fam), ("x", "v")])]
                                      | NONE => refuse ("the family " ^ #name fam ^ " has no note " ^ k))
                         | NONE => []
              val tag = if #sum t then ["P.byte (" ^ #wstream fam (#tagLayer t) ^ ", " ^ Int.toString n ^ ")"] else []
              val fs = List.map (fn (f : field) => (checkLayer (cx, whereOf (t, p) ^ "." ^ #name f, #codec f, #layer f);
                                                    wexp (cx, #codec f, #layer f, var (#name f)))) (#fields p)
            in (pattern (p, SOME o var), seqTop (note @ tag @ fs)) end
      val body = cases (viewOf (t, "v"), List.map arm (numbered t), NONE)
      val body =
        case #share i of
          NONE => body
        | SOME {tag, id, table, count, ...} =>
            let fun s x = subst (x, [("e", #warg fam)])
                val w = #wstream fam Static
            in
              "    case IntTable.find (" ^ s table ^ ", " ^ id ^ " v) of\n"
              ^ "      SOME k => (P.byte (" ^ w ^ ", " ^ Int.toString tag ^ "); P.nat (" ^ w ^ ", k))\n"
              ^ "    | NONE =>\n      ((" ^ String.substring (body, 4, String.size body - 4) ^ ");\n"
              ^ "       IntTable.insert (" ^ s table ^ ", " ^ id ^ " v, !(" ^ s count ^ ")); " ^ s count ^ " := !(" ^ s count ^ ") + 1)"
            end
    in header (kw, nameIn (i, Write), #wparam fam ^ ", v : " ^ #sml t, "unit") ^ "\n" ^ body end

  fun reader (cx : cx, kw : string, t : ty, i : instance) : string =
    let
      val fam = #fam cx
      val () = counter := 0
      fun fieldRead (p : part) (f : field) =
        "val " ^ var (#name f) ^ " = "
        ^ (case #layer f of
             Side => let val s = fresh "s"
                     in "(case " ^ #side fam ^ " of SOME " ^ s ^ " => " ^ rexp (cx, #codec f, s) ^ " | NONE => "
                        ^ default (cx, whereOf (t, p) ^ "." ^ #name f, #codec f) ^ ")" end
           | l => rexp (cx, #codec f, #rstream fam l))
      fun made (p : part) =
        case #fields p of
          [] => construct p
        | fs => letTop (List.map (fieldRead p) fs, construct p)
      val parts = List.filter (fn (n, _) => n >= 0) (numbered t)
      val body =
        if #sum t then
          let val bad = "_ => raise " ^ #bad fam ^ " \"" ^ #bad i ^ "\""
          in
            case #share i of
              NONE => cases ("P.rbyte " ^ atomic (#rstream fam (#tagLayer t)), List.map (fn (n, p) => (Int.toString n, made p)) parts, SOME bad)
            | SOME {tag, table = _, count = _, rtable, rcount, ...} =>
                let
                  fun s x = subst (x, [("d", #rarg fam)])
                  val r = atomic (#rstream fam (#tagLayer t))
                in
                  "    case P.rbyte " ^ r ^ " of\n"
                  ^ "      " ^ Int.toString tag ^ " => (case IntTable.find (" ^ s rtable ^ ", P.rnat " ^ r ^ ") of SOME t => t | NONE => raise "
                  ^ #bad fam ^ " \"a value before it is written\")\n"
                  ^ "    | b =>\n        let\n          val t =\n"
                  ^ "            case b of\n"
                  ^ String.concatWith "\n" (List.map (fn (n, p) => (if n = 0 then "              " else "            | ") ^ Int.toString n ^ " => " ^ flat (made p)) parts)
                  ^ "\n            | " ^ bad ^ "\n"
                  ^ "        in IntTable.insert (" ^ s rtable ^ ", !(" ^ s rcount ^ "), t); " ^ s rcount ^ " := !(" ^ s rcount ^ ") + 1; t end"
                end
          end
        else let val m = made (#2 (hd parts))
             in if String.size (flat m) <= 106 then "    " ^ flat m else "    " ^ broken (4, m) end
    in header (kw, nameIn (i, Read), #rparam fam, #sml t) ^ "\n" ^ body end

  fun sameness (cx : cx, kw : string, t : ty, i : instance) : string =
    let
      val () = counter := 0
      fun arm (p : part) =
        let
          val () = if isSome (#writeAs p) then refuse (whereOf (t, p) ^ ": a part written as another has no sameness") else ()
          val used = List.concat (List.map (fn s => sameFields (p, s)) (#same p))
          val () = covered ("sameness", t, p, used, #sameOut p)
          fun item s =
            case s of
              SameField f => sexp (cx, #codec (fieldOf (p, f)), var1 f, var2 f)
            | SameVia (g, f) => g ^ " " ^ var1 f ^ " = " ^ g ^ " " ^ var2 f
        in
          ("(" ^ pattern (p, fn f => if member (f, used) then SOME (var1 f) else NONE) ^ ", "
           ^ pattern (p, fn f => if member (f, used) then SOME (var2 f) else NONE) ^ ")",
           conjTop (List.map item (#same p)))
        end
      val arms = List.map arm (#parts t)
    in
      header (kw, nameIn (i, Same), "x : " ^ #sml t ^ ", y : " ^ #sml t, "bool") ^ "\n"
      ^ cases ("(" ^ viewOf (t, "x") ^ ", " ^ viewOf (t, "y") ^ ")", arms,
               if List.length arms > 1 then SOME "_ => false" else NONE)
    end

  (* a text's {f} and {f.g} made the field's variable and a selection of it *)
  fun fill (p : part, text : string) : string =
    subst (text, List.map (fn h =>
                             (h, case String.fields (fn c => c = #".") h of
                                   [f] => (ignore (fieldOf (p, f)); var f)
                                 | f :: rest => (ignore (fieldOf (p, f));
                                                 List.foldl (fn (g, e) => "#" ^ g ^ " " ^ atomic e) (var f) rest)
                                 | [] => h))
                          (placeholders text))

  fun fingerprint (cx : cx, kw : string, t : ty, i : instance) : string =
    let
      val fam = #fam cx
      val () = counter := 0
      fun arm (p : part) =
        let
          val () = if isSome (#writeAs p) then refuse (whereOf (t, p) ^ ": a part written as another has no fingerprint") else ()
          val used = List.concat (List.map (fn x => fpFields (p, x)) (#fp p))
          val () = covered ("fingerprint", t, p, used, #fpOut p)
          fun guard (g, e) = case g of Both => e | Full => "if " ^ #static fam ^ " then () else " ^ e
          fun item x =
            case x of
              FpField (g, f) => guard (g, fexp (cx, #codec (fieldOf (p, f)), var f))
            | FpText (g, text) => guard (g, fill (p, text))
          val tag = case #fpTag p of SOME n => ["P.byte (w, " ^ Int.toString n ^ ")"] | NONE => []
        in (pattern (p, fn f => if member (f, used) then SOME (var f) else NONE), seqTop (tag @ List.map item (#fp p))) end
    in
      header (kw, nameIn (i, Fp), #fpparam fam ^ ", v : " ^ #sml t, "unit") ^ "\n"
      ^ cases (viewOf (t, "v"), List.map arm (#parts t), NONE)
    end

  fun key (cx : cx, kw : string, t : ty, i : instance) : string =
    let
      val () = counter := 0
      fun arm (n, p : part) =
        (pattern (p, SOME o var),
         seqTop ((if #sum t then ["P.byte (k, " ^ Int.toString n ^ ")"] else [])
              @ List.map (fn (f : field) => kexp (cx, #codec f, "k", var (#name f))) (#fields p)))
    in
      header (kw, nameIn (i, Key), "k : P.writer, v : " ^ #sml t, "unit") ^ "\n"
      ^ cases (viewOf (t, "v"), List.map arm (List.filter (fn (n, _) => n >= 0) (numbered t)), NONE)
    end

  fun binders (cx : cx, kw : string, t : ty, i : instance) : string =
    let
      val () = counter := 0
      fun arm (p : part) =
        let val bound = List.filter (fn (f : field) => binds (cx, #codec f)) (#fields p)
        in (pattern (p, fn f => if List.exists (fn (g : field) => #name g = f) bound then SOME (var f) else NONE),
            seqTop (List.map (fn (f : field) => bexp (cx, #codec f, var (#name f))) bound)) end
    in
      header (kw, nameIn (i, Binds), "t : unit IntTable.table, v : " ^ #sml t, "unit") ^ "\n"
      ^ cases (viewOf (t, "v"), List.map arm (#parts t), NONE)
    end

  (* ---- the fingerprint oracle's changes ---- *)

  (* What a field marked in a fingerprint or a sameness is to them, changed
     alone: 2 every layer's fingerprint moves, 1 only the full one, 0 none;
     2 the sameness says another, 1 it may not (it compares a function of
     it), 0 it says the same *)
  fun fpLevel (p : part, f : string) : int =
    List.foldl (fn (item, l) => if member (f, fpFields (p, item))
                                then Int.max (l, case item of FpField (Full, _) => 1 | FpText (Full, _) => 1 | _ => 2)
                                else l) 0 (#fp p)
  fun sameLevel (p : part, f : string) : int =
    List.foldl (fn (item, l) => case item of
                                  SameField g => if g = f then 2 else l
                                | SameVia (_, g) => if g = f then Int.max (l, 1) else l) 0 (#same p)

  (* a codec's other values than x: a list of (what, fingerprint, sameness,
     value), each changing one thing *)
  fun pexp (cx : cx, cd : codec, x : string) : string =
    case cd of
      Leaf n =>
        let val l = leaf (cx, n)
        in
          case #other l of
            "" => "[]"
          | t => let val y = fresh "y"
                 in "List.map (fn " ^ y ^ " => (\"\", " ^ (if #static l then "2" else "1") ^ ", 2, " ^ y ^ ")) ("
                    ^ subst (t, [("x", x)]) ^ ")" end
        end
    | Type t => let val (l, f, s', y) = (fresh "l", fresh "f", fresh "s", fresh "y")
                in "List.map (fn (" ^ l ^ ", " ^ f ^ ", " ^ s' ^ ", " ^ y ^ ") => (\".\" ^ " ^ l ^ ", " ^ f ^ ", " ^ s' ^ ", " ^ y ^ ")) ("
                   ^ nameOf (cx, t, Perturb) ^ " " ^ x ^ ")" end
    | List _ => "(case List.rev " ^ x ^ " of _ :: r => [(\"[-1]\", 2, 2, List.rev r)] | [] => [])"
    | Option _ => "(case " ^ x ^ " of SOME _ => [(\"[none]\", 2, 2, NONE)] | NONE => [])"
    | Map _ => "(case StringMap.firsti " ^ x ^ " of SOME (k, _) => [(\"[-\" ^ k ^ \"]\", 2, 2, StringMap.remove (" ^ x ^ ", k))] | NONE => [])"
    | Tuple cs =>
        let
          val ys = List.map (fn _ => fresh "x") cs
          val n = List.length cs
          fun one (i, c, y) =
            let val (l, f, s, z) = (fresh "l", fresh "f", fresh "s", fresh "z")
            in "List.map (fn (" ^ l ^ ", " ^ f ^ ", " ^ s ^ ", " ^ z ^ ") => (\"." ^ Int.toString (i + 1) ^ "\" ^ " ^ l ^ ", " ^ f ^ ", " ^ s
               ^ ", (" ^ String.concatWith ", " (List.tabulate (n, fn j => if j = i then z else List.nth (ys, j))) ^ "))) ("
               ^ pexp (cx, c, y) ^ ")" end
        in
          "(case " ^ x ^ " of (" ^ String.concatWith ", " ys ^ ") => List.concat ["
          ^ String.concatWith ", " (List.tabulate (n, fn i => one (i, List.nth (cs, i), List.nth (ys, i)))) ^ "])"
        end
    | Shared (_, c) => pexp (cx, c, x)

  fun perturb (cx : cx, kw : string, t : ty, i : instance) : string =
    let
      val () = counter := 0
      fun arm (p : part) =
        let
          fun change (f : field) =
            let
              val (l, fl, sl, z) = (fresh "l", fresh "f", fresh "s", fresh "z")
              val made = constructBy (p, fn g => if g = #name f then z else var g)
            in
              "List.map (fn (" ^ l ^ ", " ^ fl ^ ", " ^ sl ^ ", " ^ z ^ ") => (\"" ^ (if #con p = "" then "" else #con p ^ ".") ^ #name f ^ "\" ^ " ^ l
              ^ ", Int.min (" ^ Int.toString (if #fp t then fpLevel (p, #name f) else 0) ^ ", " ^ fl ^ "), Int.min ("
              ^ Int.toString (if #same t then sameLevel (p, #name f) else 0) ^ ", " ^ sl ^ "), " ^ made ^ ")) ("
              ^ pexp (cx, #codec f, var (#name f)) ^ ")"
            end
        in
          (pattern (p, SOME o var),
           case #fields p of
             [] => "[]"
           | fs => "List.concat\001[" ^ String.concatWith ",\001 " (List.map change fs) ^ "]")
        end
    in
      header (kw, nameIn (i, Perturb), "v : " ^ #sml t, "(string * int * int * " ^ #sml t ^ ") list") ^ "\n"
      ^ cases (viewOf (t, "v"), List.map arm (List.filter (fn p => not (isSome (#writeAs p))) (#parts t)), NONE)
    end

  (* the checks of a type that hold whatever is generated of it *)
  fun check (d : description) (t : ty) : unit =
    List.app (fn (p : part) =>
                ((if #fp t then () else if null (#fp p) andalso null (#fpOut p) andalso #fpTag p = NONE then ()
                  else refuse (whereOf (t, p) ^ ": marks of a fingerprint in a type that has none"));
                 (if #same t then () else if null (#same p) andalso null (#sameOut p) then ()
                  else refuse (whereOf (t, p) ^ ": marks of a sameness in a type that has none"));
                 (if #fp t andalso not (isSome (#writeAs p)) then
                    covered ("fingerprint", t, p, List.concat (List.map (fn x => fpFields (p, x)) (#fp p)), #fpOut p)
                  else ());
                 (if #same t andalso not (isSome (#writeAs p)) then
                    covered ("sameness", t, p, List.concat (List.map (fn s => sameFields (p, s)) (#same p)), #sameOut p)
                  else ());
                 (if #sum t orelse List.length (#parts t) = 1 then () else refuse (#sml t ^ ": a record of more than one part"));
                 let val names = List.map #name (#fields p)
                 in List.app (fn n => if List.length (List.filter (fn m => m = n) names) > 1
                                      then refuse (whereOf (t, p) ^ ": two fields " ^ n) else ()) names end;
                 Option.app (fn f => ignore (fieldOf (p, f))) (#writeAs p)))
             (#parts t)

  (* one function of a region *)
  fun function (d : description, kw : string, (famName : string, tyName : string, tr : traversal)) : string =
    let
      val cx = {desc = d, fam = family (d, famName)}
      val t = typeOf (d, tyName)
      val i = instanceOf (d, famName, tyName)
      val () = check d t
    in
      case tr of
        Write => writer (cx, kw, t, i)
      | Read => reader (cx, kw, t, i)
      | Same => if #same t then sameness (cx, kw, t, i) else refuse (#sml t ^ " has no sameness")
      | Fp => if #fp t then fingerprint (cx, kw, t, i) else refuse (#sml t ^ " has no fingerprint")
      | Key => key (cx, kw, t, i)
      | Binds => binders (cx, kw, t, i)
      | Perturb => perturb (cx, kw, t, i)
    end

  (* a region's text, its functions in order; and each one's, by name *)
  fun regionFunctions (d : description, r : region) : (string * string) list =
    ListPair.map (fn (n, item as (f, t, tr)) =>
                    (nameIn (instanceOf (d, f, t), tr), function (d, if n = 0 then #start r else "and", item)))
                 (List.tabulate (List.length (#items r), fn i => i), #items r)
  fun region (d : description, r : region) : string =
    String.concatWith "\n\n" (List.map #2 (regionFunctions (d, r)))

  (* every type is checked, generated or not *)
  fun checkAll (d : description) : unit = List.app (check d) (#types d)
end
