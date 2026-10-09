(* The printers of the REPL (docs/repl.md, Printing; the incremental roadmap's
   D10): for each value a declaration binds, SML text that shows it, made
   from the type the elaborator gave it and compiled with the declaration,
   so that the back end represents the printer's values as it represents the
   value's own and the printer never reads a value's bits.

   A printer is an expression of type `int -> t -> string`, the depth left
   and the value, built from the pieces of RuneShow (lib/basis/compiler.sml).
   A datatype gets a function per type it is shown at, all of them one
   recursive group, which matches its constructors by names of their own:
   `rune'c<stamp>'<tag>`, bound in the environment the printer is elaborated
   in to the constructors the elaborator registered (Elaborate.dataCons), so
   that a datatype whose constructors are out of scope still shows them. An
   abstract type, a type variable and a function show as `?`, `?` and `fn`. *)
structure ReplShow =
struct
  open Types

  (* What the printers of one declaration need beyond its environment: the
     constructors they name, and the functions of the datatypes they made,
     by datatype and type, in the order they were made. *)
  type gen = {cons : Env.valstatus StringMap.map ref,
              funs : (string * string) list ref,      (* name, text of its clause *)
              made : string StringMap.map ref,         (* the datatype at its arguments -> name *)
              count : int ref}

  fun newGen () : gen = {cons = ref StringMap.empty, funs = ref [], made = ref StringMap.empty, count = ref 0}

  fun isTuple (fields : (string * ty) list) =
    List.length fields >= 2
    andalso #2 (List.foldl (fn ((l, _), (i, ok)) => (i + 1, ok andalso l = Int.toString i)) (1, true) fields)

  (* the type with the generic variables of a scheme replaced *)
  fun subst (m : ty IntMap.map) (t : ty) : ty =
    case prune t of
      TVar (r as ref (Unbound {id, ...})) => (case IntMap.find (m, id) of SOME u => u | NONE => TVar r)
    | TVar r => TVar r
    | TCon (c, args) => TCon (c, List.map (subst m) args)
    | TRecord fs => TRecord (List.map (fn (l, a) => (l, subst m a)) fs)
    | TArrow (a, b) => TArrow (subst m a, subst m b)

  (* a constructor's argument at the datatype's arguments *)
  fun argAt (scheme : ty, args : ty list) : ty option =
    case prune scheme of
      TArrow (a, res) =>
        (case prune res of
           TCon (_, ps) =>
             let
               val m = ListPair.foldl (fn (p, u, m) => case prune p of
                                                         TVar (ref (Unbound {id, ...})) => IntMap.insert (m, id, u)
                                                       | _ => m) IntMap.empty (ps, args)
             in SOME (subst m a) end
         | _ => SOME a)
    | _ => NONE

  fun quote s = "\"" ^ String.toString s ^ "\""

  (* SML text of an `int -> t -> string` printer for t *)
  fun printer (g : gen, t : ty) : string =
    case prune t of
      TVar _ => "RuneShow.hidden"
    | TArrow _ => "RuneShow.function"
    | TRecord [] => "RuneShow.unit"
    | TRecord fields =>
        if isTuple fields then
          "(fn d => fn v => RuneShow.tuple d ["
          ^ String.concatWith ", " (List.map (fn (l, a) => "fn d => " ^ printer (g, a) ^ " d (#" ^ l ^ " v)") fields)
          ^ "])"
        else
          "(fn d => fn v => RuneShow.record d ["
          ^ String.concatWith ", "
              (List.map (fn (l, a) => "(" ^ quote l ^ ", fn d => " ^ printer (g, a) ^ " d (#" ^ l ^ " v))") fields)
          ^ "])"
    | TCon (c, args) =>
        let val s = #stamp c
        in
          if s = #stamp intTycon then "RuneShow.int"
          else if s = #stamp wordTycon then "RuneShow.word"
          else if s = #stamp realTycon then "RuneShow.real"
          else if s = #stamp charTycon then "RuneShow.char"
          else if s = #stamp stringTycon then "RuneShow.string"
          else if s = #stamp exnTycon then "RuneShow.exn"
          else if s = #stamp boolTycon then "(fn _ => fn b => if b then \"true\" else \"false\")"
          else
            case (s = #stamp listTycon, s = #stamp refTycon, s = #stamp arrayTycon, s = #stamp vectorTycon, args) of
              (true, _, _, _, [a]) => "(RuneShow.list " ^ printer (g, a) ^ ")"
            | (_, true, _, _, [a]) => "(RuneShow.reference " ^ printer (g, a) ^ ")"
            | (_, _, true, _, [a]) => "(RuneShow.array " ^ printer (g, a) ^ ")"
            | (_, _, _, true, [a]) => "(RuneShow.vector " ^ printer (g, a) ^ ")"
            | _ =>
                case IntMap.find (!Elaborate.dataCons, s) of
                  SOME cons => datatypeAt (g, c, cons, args)
                | NONE => "RuneShow.hidden"
        end

  (* the function that shows the datatype c at args, made once *)
  and datatypeAt (g : gen, c : tycon, cons : (string * Env.valstatus) list, args : ty list) : string =
    let val key = Int.toString (#stamp c) ^ ":" ^ String.concatWith "," (List.map toString args)
    in
      case StringMap.find (!(#made g), key) of
        SOME name => name
      | NONE =>
          if !(#count g) >= 64 then "RuneShow.hidden"    (* a datatype nested without end at ever larger types *)
          else
            let
              val name = "rune's" ^ Int.toString (!(#count g))
              val () = #count g := !(#count g) + 1
              val () = #made g := StringMap.insert (!(#made g), key, name)
              fun clause (cname, v) =
                case v of
                  Env.Con {scheme, info} =>
                    let
                      val synth = "rune'c" ^ Int.toString (#stamp c) ^ "'" ^ Int.toString (#tag info)
                      val () = #cons g := StringMap.insert (!(#cons g), synth, v)
                    in
                      if #hasArg info then
                        case argAt (scheme, args) of
                          SOME a => synth ^ " a => RuneShow.con1 d (" ^ quote cname ^ ", fn d => " ^ printer (g, a) ^ " d a)"
                        | NONE => synth ^ " _ => " ^ quote cname
                      else synth ^ " => RuneShow.con0 " ^ quote cname
                    end
                | _ => "_ => \"?\""
              val body = "fn d => fn v => case v of " ^ String.concatWith " | " (List.map clause cons)
            in
              #funs g := (name, body) :: !(#funs g);
              name
            end
    end

  (* The text of the declaration that echoes the values bound, and the
     environment it is elaborated in beside the session's: the constructors
     it names. NONE where there is nothing to show. *)
  fun echoes (bound : (string * ty) list) : (string * Env.env) option =
    case bound of
      [] => NONE
    | _ =>
        let
          val g = newGen ()
          fun name n = if CharVector.all (fn c => Char.isAlphaNum c orelse c = #"_" orelse c = #"'") n then n
                       else "(op " ^ n ^ ")"
          val lines =
            List.map (fn (n, t) =>
                        "val () = RuneShow.echo (" ^ quote n ^ ", " ^ printer (g, t) ^ " (!RuneCompiler.printDepth) "
                        ^ name n ^ ", " ^ quote (toString t) ^ ")") bound
          val funs = List.rev (!(#funs g))
          val group =
            case funs of
              [] => ""
            | _ => "val rec " ^ String.concatWith " and " (List.map (fn (n, b) => n ^ " = " ^ b) funs) ^ " "
          val text = "local " ^ group ^ "in " ^ String.concatWith " " lines ^ " end"
          val env = StringMap.foldli (fn (n, v, e) => Env.bindVal (e, n, v)) Env.empty (!(#cons g))
        in SOME (text, env) end
end
