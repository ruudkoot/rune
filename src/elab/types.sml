(* Internal representation of types for elaboration. *)
structure Types =
struct
  type tycon = {name : string, stamp : int, arity : int}

  datatype ty =
      TVar of tvar ref
    | TCon of tycon * ty list
    | TRecord of (string * ty) list         (* labels sorted by labelCompare *)
    | TArrow of ty * ty

  and tvar =
      Unbound of {id : int, level : int, kind : kind, eq : bool}
    | Bound of ty

  and kind =
      KPlain
    | KOverload of string list             (* names of admissible tycons *)
    | KFlex of (string * ty) list          (* known fields of a flexible record *)

  (* A type scheme is a type whose generic variables have level = genericLevel. *)
  type scheme = ty

  val genericLevel = 1000000000

  fun sameTycon (a : tycon, b : tycon) = #stamp a = #stamp b

  (* --- builtin type constructors --- *)
  fun mk (name, stamp, arity) : tycon = {name = name, stamp = stamp, arity = arity}
  val intTycon = mk ("int", 1, 0)
  val wordTycon = mk ("word", 2, 0)
  val realTycon = mk ("real", 3, 0)
  val charTycon = mk ("char", 4, 0)
  val stringTycon = mk ("string", 5, 0)
  val boolTycon = mk ("bool", 6, 0)
  val listTycon = mk ("list", 7, 1)
  val refTycon = mk ("ref", 8, 1)
  val exnTycon = mk ("exn", 9, 0)
  val arrayTycon = mk ("array", 10, 1)
  val vectorTycon = mk ("vector", 11, 1)

  val intTy = TCon (intTycon, [])
  val wordTy = TCon (wordTycon, [])
  val realTy = TCon (realTycon, [])
  val charTy = TCon (charTycon, [])
  val stringTy = TCon (stringTycon, [])
  val boolTy = TCon (boolTycon, [])
  val exnTy = TCon (exnTycon, [])
  val unitTy = TRecord []
  fun listTy t = TCon (listTycon, [t])
  fun refTy t = TCon (refTycon, [t])
  fun arrayTy t = TCon (arrayTycon, [t])
  fun vectorTy t = TCon (vectorTycon, [t])

  val tyconCounter = ref 100
  fun freshTycon (name, arity) : tycon =
    let val s = !tyconCounter in tyconCounter := s + 1; mk (name, s, arity) end

  val tvarCounter = ref 0
  fun freshTvar (level, kind, eq) =
    let val id = !tvarCounter
    in tvarCounter := id + 1; TVar (ref (Unbound {id = id, level = level, kind = kind, eq = eq})) end
  fun fresh level = freshTvar (level, KPlain, false)

  (* --- record labels --- *)
  fun isNumericLabel s =
    String.size s > 0 andalso String.sub (s, 0) <> #"0" andalso List.all Char.isDigit (String.explode s)

  fun labelCompare (a, b) =
    case (isNumericLabel a, isNumericLabel b) of
      (true, true) =>
        if String.size a <> String.size b then Int.compare (String.size a, String.size b)
        else String.compare (a, b)
    | (true, false) => LESS
    | (false, true) => GREATER
    | (false, false) => String.compare (a, b)

  fun sortFields (fields : (string * 'a) list) =
    let
      fun ins (f, []) = [f]
        | ins (f as (l, _), (g as (l', _)) :: rest) =
          if labelCompare (l, l') = GREATER then g :: ins (f, rest) else f :: g :: rest
    in List.foldl ins [] fields end

  fun tupleTy tys =
    TRecord (ListPair.zip (List.tabulate (List.length tys, fn i => Int.toString (i + 1)), tys))

  fun isTuple fields =
    let fun go (_, []) = true
          | go (i, (l, _) :: rest) = l = Int.toString i andalso go (i + 1, rest)
    in List.length fields >= 2 andalso go (1, fields) end

  (* Index of a label in a sorted field list. *)
  fun labelIndex (fields : (string * 'a) list, lab) =
    let fun go (_, []) = NONE
          | go (i, (l, _) :: rest) = if l = lab then SOME i else go (i + 1, rest)
    in go (0, fields) end

  (* --- resolving variable links --- *)
  fun prune (t as TVar r) = (case !r of Bound t' => let val t'' = prune t' in r := Bound t''; t'' end | _ => t)
    | prune t = t

  (* Fully dereference (for the backend). *)
  fun resolve t =
    case prune t of
      TVar r => TVar r
    | TCon (c, args) => TCon (c, List.map resolve args)
    | TRecord fs => TRecord (List.map (fn (l, t) => (l, resolve t)) fs)
    | TArrow (a, b) => TArrow (resolve a, resolve b)

  (* --- pretty printing --- *)
  fun toStringWith (names : (int * string) list ref) t =
    let
      fun tvName (id, eq) =
        case List.find (fn (i, _) => i = id) (!names) of
          SOME (_, s) => s
        | NONE =>
          let
            val k = List.length (!names)
            val base = if k < 26 then String.str (Char.chr (Char.ord #"a" + k))
                       else "t" ^ Int.toString k
            val s = (if eq then "''" else "'") ^ base
          in names := (id, s) :: !names; s end
      fun paren (b, s) = if b then "(" ^ s ^ ")" else s
      (* prec: 0 = top, 1 = arrow domain, 2 = tuple operand, 3 = tycon argument *)
      fun go (prec, t) =
        case prune t of
          TVar r =>
            (case !r of
               Unbound {id, kind = KPlain, eq, ...} => tvName (id, eq)
             | Unbound {id, kind = KOverload _, ...} => tvName (id, false)
             | Unbound {kind = KFlex fields, ...} =>
                 "{" ^ String.concatWith ", " (List.map (fn (l, t) => l ^ " : " ^ go (0, t)) fields) ^ ", ...}"
             | Bound _ => "?")
        | TCon (c, []) => #name c
        | TCon (c, [a]) => go (3, a) ^ " " ^ #name c
        | TCon (c, args) => "(" ^ String.concatWith ", " (List.map (fn a => go (0, a)) args) ^ ") " ^ #name c
        | TRecord [] => "unit"
        | TRecord fields =>
            if isTuple fields then
              paren (prec >= 2, String.concatWith " * " (List.map (fn (_, t) => go (2, t)) fields))
            else "{" ^ String.concatWith ", " (List.map (fn (l, t) => l ^ " : " ^ go (0, t)) fields) ^ "}"
        | TArrow (a, b) => paren (prec >= 1, go (1, a) ^ " -> " ^ go (0, b))
    in go (0, t) end

  fun toString t = toStringWith (ref []) t
end
