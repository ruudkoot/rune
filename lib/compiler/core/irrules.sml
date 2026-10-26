(* Rules that LambdaLint and MidLint share (linting roadmap, M4; docs/ir.md,
   What a Lambda keeps, What a Mid keeps), each answering what is wrong,
   NONE where nothing is:
   * a constant's kind agrees with its type -- an int's CInt, a word's
     CWord, ... -- and its value is in the type's range (an int's 63 bits,
     an Int64.int's 64, a word's and a Word64.word's from 0, a char's 8);
     open_layout's descriptor, a CInt given its datatype, is the one
     exception, which the lints take as that primitive's argument;
   * a primitive's type at a use is an instance of its description's
     (PrimTys, which runeisa reads from src/isa): each type variable stands
     for one type throughout, a type name the compiler builds in is itself
     and unit the empty tuple, and a name it does not (option, order,
     Word32.word, the Basis's) stands for any type; the compiler's own
     primitives, which no VM has, are checked by their own rules;
   * an exception's payload (MkExn) has the type of its argument (Ty.exnArgOf:
     the elaborator's, or a copy's that the pass which made it registered
     at the copy's types, or one's a pass put where it was at other types);
   * a cast the compiler makes is of its origin's kind: functor_cast, a
     record slot's, to or from unit; dynamic_cast, a dynamic module's slot,
     to or from unit; open_cast, an open constructor's, to or from unit, a
     tuple of units (Ty.flatArg) or a flat datatype (Ty.flat); the
     program's own unsafe_cast is anything. *)
structure IrRules =
struct
  fun pow2 n = IntInf.pow (IntInf.fromInt 2, n)
  val int63Min = IntInf.~ (pow2 62)
  val int63Max = IntInf.- (pow2 62, IntInf.fromInt 1)
  val int64Min = IntInf.~ (pow2 63)
  val int64Max = IntInf.- (pow2 63, IntInf.fromInt 1)
  val word64Max = IntInf.- (pow2 64, IntInf.fromInt 1)
  val zero = IntInf.fromInt 0

  (* a constant of type t: what is wrong with it *)
  fun const (c : Lambda.const, t : Ty.ty) : string option =
    let
      val st = case Ty.view t of Ty.Con (s, _, _) => s | _ => ~1
      fun within (v, lo, hi) = IntInf.>= (v, lo) andalso IntInf.<= (v, hi)
      (* what is wrong, made only where something is: a char past 255 has
         no character to print *)
      fun shown () = case c of
                       Lambda.CChar ch => if ch >= 0 andalso ch <= 255 then Lambda.constToString c else "char " ^ Int.toString ch
                     | _ => Lambda.constToString c
      fun kind (tc : Types.tycon, ok) =
        if st <> #stamp tc then SOME ("a constant " ^ shown () ^ " of type " ^ Ty.toString t)
        else if ok then NONE
        else SOME ("the constant " ^ shown () ^ " out of the range of " ^ Ty.toString t)
    in
      case c of
        Lambda.CInt i => kind (Types.intTycon, within (i, int63Min, int63Max))
      | Lambda.CWord w => kind (Types.wordTycon, within (w, zero, int64Max))
      | Lambda.CInt64 i => kind (Types.int64Tycon, within (i, int64Min, int64Max))
      | Lambda.CWord64 w => kind (Types.word64Tycon, within (w, zero, word64Max))
      | Lambda.CReal _ => kind (Types.realTycon, true)
      | Lambda.CString _ => kind (Types.stringTycon, true)
      | Lambda.CChar ch => kind (Types.charTycon, ch >= 0 andalso ch <= 255)
    end

  (* the compiler's own primitives, whose rules are their own *)
  val casts = ["functor_cast", "dynamic_cast", "open_cast"]
  fun own (name : string) = List.exists (fn p => p = name) ("functor_marker" :: "open_boxed" :: "open_layout" :: casts)

  (* the built-in type a description's name is, by its stamp: NONE for one
     that stands for any type *)
  val builtins : int StringMap.map =
    List.foldl (fn (c : Types.tycon, m) => StringMap.insert (m, #name c, #stamp c)) StringMap.empty Types.builtinTycons
  fun builtin (name : string) : int option = StringMap.find (builtins, name)

  (* a primitive's use at type t, against its description: what is wrong *)
  fun prim (name : string, t : Ty.ty) : string option =
    if own name then NONE
    else
          case PrimTys.find name of
            NONE => SOME ("primitive " ^ name ^ " has no description")
          | SOME (params, result) =>
              let
                val vars : (int * Ty.ty) list ref = ref []
                exception No
                fun go (d : PrimTys.ty, u : Ty.ty) : unit =
                  case d of
                    PrimTys.Var i =>
                      (case List.find (fn (j, _) => i = j) (!vars) of
                         SOME (_, u') => if Ty.equal (u, u') then () else raise No
                       | NONE => vars := (i, u) :: !vars)
                  | PrimTys.Con ("unit", []) => if Ty.equal (u, Ty.unit) then () else raise No
                  | PrimTys.Con (n, args) =>
                      (case builtin n of
                         NONE => ()
                       | SOME s =>
                           case Ty.view u of
                             Ty.Con (s', _, us) =>
                               if s = s' andalso List.length args = List.length us then ListPair.app go (args, us) else raise No
                           | _ => raise No)
                  | PrimTys.Tuple ds =>
                      (case Ty.view u of
                         Ty.Tuple us => if List.length ds = List.length us then ListPair.app go (ds, us) else raise No
                       | _ => raise No)
                  | PrimTys.Arrow (a, b) =>
                      (case Ty.view u of
                         Ty.Arrow (a', b') => (go (a, a'); go (b, b'))
                       | _ => raise No)
                val whole = PrimTys.Arrow (case params of [p] => p | ps => PrimTys.Tuple ps, result)
              in
                (go (whole, t); NONE)
                handle No => SOME ("primitive " ^ name ^ " at " ^ Ty.toString t ^ ", which is no instance of its description")
              end

  (* an exception's payload of type got, the exception the stamp declares:
     what is wrong *)
  fun payload (stamp : int, got : Ty.ty) : string option =
    case Ty.exnArgOf stamp of
      NONE => NONE
    | SOME arg =>
        let val want = getOpt (arg, Ty.unit)
        in
          if Ty.equal (got, want) then NONE
          else SOME ("an exception's payload has type " ^ Ty.toString got ^ " where its argument is " ^ Ty.toString want)
        end

  (* a cast the compiler makes, by its primitive, from d to c: what is
     wrong *)
  fun isUnit t = Ty.equal (t, Ty.unit)
  fun isFlat t =
    case Ty.view t of
      Ty.Con (s, _, []) => isSome (Ty.flatOf s)
    | Ty.Tuple ts => List.all isUnit ts
    | _ => false
  fun cast (name : string, t : Ty.ty) : string option =
    if not (List.exists (fn c => c = name) casts) then NONE
    else
    case Ty.view t of
      Ty.Arrow (d, c) =>
        let
          fun need ok what = if ok then NONE else SOME ("a " ^ name ^ " from " ^ Ty.toString d ^ " to " ^ Ty.toString c ^ ", " ^ what)
        in
          case name of
            "functor_cast" => need (isUnit d orelse isUnit c) "neither unit"
          | "dynamic_cast" => need (isUnit d orelse isUnit c) "neither unit"
          | "open_cast" => need (isFlat d orelse isFlat c) "neither unit nor flat"
          | _ => NONE
        end
    | _ => SOME ("a " ^ name ^ " of type " ^ Ty.toString t)

  (* a primitive's use at type t: what is wrong with it, by its description
     (prim) and, for a cast the compiler makes, by its origin's rule (cast).
     What was found right once is not looked at again: a primitive is used
     at few types, again and again, and a type is one node (Ty is
     hash-consed), whose id keys the uses found right *)
  val checked : string list IntTable.table = IntTable.table 256
  val () = CompilerState.tableRoot ("IrRules.checked", checked)
  fun use (name : string, t : Ty.ty) : string option =
    let val seen = getOpt (IntTable.find (checked, Ty.id t), [])
    in
      if List.exists (fn n => n = name) seen then NONE
      else
        case (case prim (name, t) of NONE => cast (name, t) | wrong => wrong) of
          NONE => (IntTable.insert (checked, Ty.id t, name :: seen); NONE)
        | wrong => wrong
    end
end
