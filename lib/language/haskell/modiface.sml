(* Implements: HS_MOD_IFACE *)
structure HsModIface :> HS_MOD_IFACE =
struct
  structure M = HsStringMap
  structure T = HsTypes
  structure A = HsAst

  type t = {id : string, exports : HsModules.entity list, defs : HsModules.def list,
            fixities : (string * (A.fixity * int)) list, checked : HsInfer.part}

  fun make {id, exports, defs : HsModules.def list, fixity, env} : t =
    {id = id, exports = exports, defs = defs,
     fixities = List.mapPartial (fn (d : HsModules.def) =>
                                   let val k = HsModules.key (#entity d)
                                   in Option.map (fn f => (k, f)) (fixity k) end) defs,
     checked = HsInfer.part (env, fn h => h = id)}

  (* ---- canonical text ---- *)

  fun ty t =
    case t of
      T.TCon k => k
    | T.TAp (a, b) => "(" ^ ty a ^ " " ^ ty b ^ ")"
    | T.TGen i => "#" ^ Int.toString i
    | T.TMeta (ref (T.Link t')) => ty t'
    | T.TMeta (ref (T.Free {id, ...})) => "?" ^ Int.toString id
    | T.TRigid {name, ...} => "!" ^ name

  fun pred ({cls, ty = t} : T.pred) = cls ^ " " ^ ty t
  fun context ps = "(" ^ String.concatWith ", " (List.map pred ps) ^ ")"
  fun scheme ({vars, ctx, ty = t} : T.scheme) = "forall " ^ Int.toString vars ^ ". " ^ context ctx ^ " => " ^ ty t
  fun kind k = T.showKind (T.defaultKind k)

  fun fixityText NONE = ""
    | fixityText (SOME (f, p)) =
        " " ^ (case f of A.Infix => "infix" | A.Infixl => "infixl" | A.Infixr => "infixr") ^ " " ^ Int.toString p

  (* the type constructors and classes a type mentions *)
  fun mentionsTy t =
    case t of
      T.TCon k => [k]
    | T.TAp (a, b) => mentionsTy a @ mentionsTy b
    | T.TMeta (ref (T.Link t')) => mentionsTy t'
    | _ => []
  fun mentionsPreds ps = List.concat (List.map (fn {cls, ty = t} => cls :: mentionsTy t) ps)
  fun mentionsScheme ({ctx, ty = t, ...} : T.scheme) = mentionsPreds ctx @ mentionsTy t

  (* an item: its key, the keys of its members (a type's constructors and
     fields, a class's methods), its text, what it mentions *)
  type item = {key : string, members : string list, text : string, mentions : string list}

  fun items ({fixities, checked, ...} : t) : item list =
    let
      val fix = List.foldl (fn ((k, f), m) => M.insert (m, k, f)) M.empty fixities
      fun fixOf k = fixityText (M.find (fix, k))
      val values = List.foldl (fn ((k, s), m) => M.insert (m, k, s)) M.empty (#values checked)
      fun valueText k = case M.find (values, k) of SOME s => scheme s | NONE => "(no type)"
      fun valueMentions k = case M.find (values, k) of SOME s => mentionsScheme s | NONE => []
      val cons = List.foldl (fn ((k, c), m) => M.insert (m, k, c)) M.empty (#cons checked)
      val fieldsOf =
        List.foldl (fn ((k, f as {tycon, ...}), m) => M.insert (m, tycon, (k, f) :: getOpt (M.find (m, tycon), [])))
          M.empty (#fields checked)
      val methods = List.foldl (fn ((k, x), m) => M.insert (m, k, x)) M.empty (#methods checked)
      fun tyItem (tc : HsKinds.tycon) : item =
        let
          val k = #key tc
          val fs = List.rev (getOpt (M.find (fieldsOf, k), []))
          val conLines =
            List.map (fn c =>
                        let val arity = case M.find (cons, c) of SOME {arity, ...} => Int.toString arity | NONE => "?"
                            val fields = case M.find (cons, c) of SOME {fields, ...} => String.concatWith "," fields | NONE => ""
                            val strict =
                              case M.find (cons, c) of
                                SOME {strict, ...} => String.concat (List.map (fn true => "!" | false => ".") strict)
                              | NONE => ""
                        in "  con " ^ c ^ " " ^ arity ^ " [" ^ fields ^ "] " ^ strict ^ " " ^ valueText c ^ fixOf c end)
              (#cons tc)
          val fieldLines =
            List.map (fn (f, {ty = t, cons = cs, ...}) =>
                        "  field " ^ f ^ " " ^ ty t ^ " [" ^
                        String.concatWith "," (List.map (fn (c, i) => c ^ ":" ^ Int.toString i) cs) ^ "] " ^ valueText f ^ fixOf f)
              fs
          val head =
            "type " ^ k ^ " " ^ kind (#kind tc) ^ " " ^ Int.toString (#params tc) ^
            (case #synonym tc of SOME r => " = " ^ ty r | NONE => if #newtype tc then " newtype" else " data") ^ fixOf k
        in
          {key = k, members = #cons tc @ List.map #1 fs,
           text = String.concatWith "\n" (head :: conLines @ fieldLines),
           mentions = (case #synonym tc of SOME r => mentionsTy r | NONE => []) @
                      List.concat (List.map valueMentions (#cons tc)) @
                      List.concat (List.map (fn (f, {ty = t, ...}) => mentionsTy t @ valueMentions f) fs)}
        end
      fun classItem (c : HsClasses.class) : item =
        let
          val k = #key c
          val methodLines =
            List.map (fn m =>
                        "  method " ^ m ^ " " ^
                        (case M.find (methods, m) of SOME {scheme = s, ...} => scheme s | NONE => valueText m) ^ fixOf m)
              (#methods c)
        in
          {key = k, members = #methods c,
           text = String.concatWith "\n"
                    (("class " ^ k ^ " " ^ kind (#kind c) ^ " (" ^ String.concatWith ", " (#supers c) ^ ")" ^ fixOf k)
                     :: methodLines),
           mentions = #supers c @
                      List.concat (List.map (fn m => case M.find (methods, m) of SOME {scheme = s, ...} => mentionsScheme s
                                                                                | NONE => valueMentions m) (#methods c))}
        end
      val tys = List.map tyItem (#tycons checked)
      val clss = List.map classItem (#classes checked)
      val owned = List.foldl (fn ({key, members, ...} : item, s) => List.foldl (fn (m, s) => M.insert (s, m, ())) (M.insert (s, key, ())) members)
                    M.empty (tys @ clss)
      val vals =
        List.mapPartial (fn (k, s) => if M.member (owned, k) then NONE
                                      else SOME {key = k, members = [], text = "value " ^ k ^ " " ^ scheme s ^ fixOf k,
                                                 mentions = mentionsScheme s})
          (#values checked)
      val insts =
        List.map (fn (i : HsClasses.instance) =>
                    {key = #id i, members = [],
                     text = "instance " ^ #id i ^ " " ^ #cls i ^ " " ^ #tycon i ^ " " ^ Int.toString (#vars i) ^ " " ^
                            context (#ctx i) ^ (if #derived i then " derived" else ""),
                     mentions = #cls i :: #tycon i :: mentionsPreds (#ctx i)})
          (#instances checked)
    in
      tys @ clss @ vals @ insts
    end

  fun canonical t =
    List.concat (List.map (fn {key, members, text, ...} : item => (key, text) :: List.map (fn m => (m, text)) members) (items t))

  (* ---- fingerprints by recursive group ---- *)

  fun sortStrings xs =
    let
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if String.< (x, y) then x :: y :: ys else y :: insert (x, ys)
    in
      List.foldl insert [] xs
    end

  fun fingerprints hash (t, external) =
    let
      val its = items t
      val byKey = List.foldl (fn (i : item, m) => M.insert (m, #key i, i)) M.empty its
      (* each key of the module to the item that holds it *)
      val owner = List.foldl (fn ({key, members, ...} : item, s) => List.foldl (fn (m, s) => M.insert (s, m, key)) (M.insert (s, key, key)) members)
                    M.empty its
      fun local_ k = M.find (owner, k)
      fun edges (i : item) = List.mapPartial local_ (#mentions i)
      (* Tarjan's algorithm over the items, a group complete once its root is *)
      val index : int M.map ref = ref M.empty
      val low : int M.map ref = ref M.empty
      val onStack : bool M.map ref = ref M.empty
      val stack : string list ref = ref []
      val counter = ref 0
      val groups : string list list ref = ref []
      fun get (m, k) = valOf (M.find (!m, k))
      fun connect v =
        let
          val () = (index := M.insert (!index, v, !counter); low := M.insert (!low, v, !counter);
                    counter := !counter + 1; stack := v :: !stack; onStack := M.insert (!onStack, v, true))
          fun edge w =
            if not (M.member (!index, w)) then (connect w; low := M.insert (!low, v, Int.min (get (low, v), get (low, w))))
            else if M.find (!onStack, w) = SOME true then low := M.insert (!low, v, Int.min (get (low, v), get (index, w)))
            else ()
          val () = List.app edge (edges (valOf (M.find (byKey, v))))
        in
          if get (low, v) = get (index, v) then
            let
              fun pop acc =
                case !stack of
                  w :: rest => (stack := rest; onStack := M.insert (!onStack, w, false);
                                if w = v then w :: acc else pop (w :: acc))
                | [] => acc
            in
              groups := pop [] :: !groups
            end
          else ()
        end
      val () = List.app (fn ({key, ...} : item) => if M.member (!index, key) then () else connect key) its
      (* dependencies first: the first group completed is a sink *)
      val ordered = List.rev (!groups)
      val fps : string M.map ref = ref M.empty
      fun groupFp members =
        let
          val ms = sortStrings members
          val texts = List.map (fn k => #text (valOf (M.find (byKey, k)))) ms
          val inGroup = fn k => List.exists (fn m => m = k) ms
          val outside =
            List.concat
              (List.map (fn k =>
                           List.mapPartial (fn x =>
                                              case local_ x of
                                                SOME o_ => if inGroup o_ then NONE else SOME (x ^ "=" ^ valOf (M.find (!fps, o_)))
                                              | NONE => SOME (x ^ "=" ^ getOpt (external x, x)))
                             (#mentions (valOf (M.find (byKey, k)))))
                 ms)
        in
          hash (String.concatWith "\n" texts ^ "\n--\n" ^ String.concatWith "\n" (sortStrings outside))
        end
      val () = List.app (fn g => let val fp = groupFp g in List.app (fn k => fps := M.insert (!fps, k, fp)) g end) ordered
    in
      List.concat (List.map (fn {key, members, ...} : item =>
                               let val fp = valOf (M.find (!fps, key)) in (key, fp) :: List.map (fn m => (m, fp)) members end)
                     its)
    end
end
