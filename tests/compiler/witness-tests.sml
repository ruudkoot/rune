(* The syntax's node ids, the elaborator's witnesses and SourceTy (the
   linting roadmap's M11), from inside the compiler: a program parsed and
   elaborated as a unit is, what the tables hold of it after
   Elaborate.finish, read as SourceTy; a declaration that fails leaves
   nothing but its status; a unit undone leaves nothing. Each check prints
   a line PASS or FAIL, and the program fails at the first FAIL. *)
structure CompilerWitnessTests =
struct
  val failures = ref 0
  fun check (what, ok) =
    if ok then print ("PASS " ^ what ^ "\n")
    else (failures := !failures + 1; print ("FAIL " ^ what ^ "\n"))

  val text = String.concat
    ["datatype 'a tree = Leaf | Node of 'a tree * 'a * 'a tree\n",
     "datatype t = A | B of int -> int\n",
     "fun size Leaf = 0\n",
     "  | size (Node (l, _, r)) = size l + 1 + size r\n",
     "fun first [] = raise Match\n",
     "  | first (x :: _) = x\n",
     "val 'a id = fn (x : 'a) => x\n",
     "fun pair x = (x, x) and swap (a, b) = (b, a)\n",
     "val w = 0w7\n",
     "val bad = undefined + 1\n",
     "val after = size (Node (Leaf, \"x\", Leaf))\n"]

  (* every node's id, from a walk of the syntax *)
  fun ids (ds : Ast.dec list) : int list =
    let
      open Ast
      val acc = ref []
      fun add n = acc := n :: !acc
      fun exp e =
        (add (idOfExp e);
         case e of
           ERecord (fs, _, _) => List.app (exp o #2) fs | ETuple (es, _, _) => List.app exp es
         | EList (es, _, _, _) => List.app exp es | ESeq (es, _, _) => List.app exp es
         | ELet (ds, e, _, _) => (List.app dec ds; exp e) | EApp (a, b, _, _) => (exp a; exp b)
         | ETyped (e, t, _, _) => (exp e; ty t) | EAndalso (a, b, _, _) => (exp a; exp b)
         | EOrelse (a, b, _, _) => (exp a; exp b) | EHandle (e, rs, _, _) => (exp e; List.app rule rs)
         | ERaise (e, _, _) => exp e | EIf (a, b, c, _, _) => (exp a; exp b; exp c) | EWhile (a, b, _, _) => (exp a; exp b)
         | ECase (e, rs, _, _) => (exp e; List.app rule rs) | EFn (rs, _, _, _) => List.app rule rs
         | EPrim (_, t, _, _, _) => ty t | _ => ())
      and rule (p, e) = (pat p; exp e)
      and pat p =
        (add (idOfPat p);
         case p of
           PRecord (fs, _, _, _, _) => List.app (pat o #2) fs | PTuple (ps, _, _) => List.app pat ps
         | PList (ps, _, _) => List.app pat ps | PApp (_, _, q, _, _) => pat q | PTyped (q, t, _, _) => (pat q; ty t)
         | PLayered (_, t, q, _, _, _) => (Option.app ty t; pat q) | POr (ps, _, _) => List.app pat ps | _ => ())
      and ty t =
        (add (idOfTy t);
         case t of
           TyRecord (fs, _, _) => List.app (ty o #2) fs | TyTuple (ts, _, _) => List.app ty ts
         | TyCon (ts, _, _, _) => List.app ty ts | TyArrow (a, b, _, _) => (ty a; ty b) | _ => ())
      and dec d =
        (add (idOfDec d);
         case d of
           DVal (_, bs, _, _) => List.app rule bs | DValRec (_, bs, _, _) => List.app rule bs
         | DFun (_, fs, _, _) =>
             List.app (fn (f : fundef) => (add (#id f); List.app (fn (c : clause) => (add (#id c); List.app pat (#pats c);
                                                                               Option.app ty (#resty c); exp (#body c)))
                                                                (#clauses f))) fs
         | DDatatype (dbs, _, _, _) =>
             List.app (fn (db : datbind) => (add (#id db); List.app (fn (_, t, _) => Option.app ty t) (#cons db))) dbs
         | DLocal (a, b, _, _) => (List.app dec a; List.app dec b) | _ => ())
    in List.app dec ds; !acc end

  fun distinct (xs : int list) =
    let
      val seen = IntTable.table 256
      fun go [] = true
        | go (x :: rest) = not (isSome (IntTable.find (seen, x))) andalso (IntTable.insert (seen, x, ()); go rest)
    in go xs end

  (* the lines Witness.dump writes, in a list *)
  fun dumped () : string list =
    let val acc = ref [] in Witness.dump (fn _ => true, fn l => acc := l :: !acc); List.rev (!acc) end
  fun has (ls, s) = List.exists (fn l => String.isSubstring s l) ls

  fun main () =
    let
      val () = UnitBasis.startSession ()
      val () = Pass.whole := false
      val file = Source.fromString ("witness-probe.sml", text)
      val () = Source.register file
      val first = !Ast.nextId
      val (ds, _) = Parser.parseTokensWith (Lexer.tokenize file, Fixity.initial)
      val all = ids ds
      val () = check ("every node has an id of its own", distinct all)
      val () = check ("the ids are those the parse gave", List.all (fn n => n >= first andalso n < !Ast.nextId) all)
      val env = ref Env.initial
      val start = UnitBasis.begin (!env, Fixity.initial)
      val marked = Witness.mark ()
      val () = Error.silent := true
      val () = Elaborate.recover := true
      val () = Elaborate.elabTop (env, ds)
      val () = Elaborate.finish ()
      val lines = dumped ()
      val () = List.app (fn l => print ("  " ^ l)) lines
      val () = check ("a constructor pattern's instance", has (lines, "instance 'a tree * 'a * 'a tree -> 'a tree")
                                                        orelse has (lines, "instance int tree"))
      val () = check ("a wildcard's type", has (lines, "type 'a") orelse has (lines, "type int"))
      val () = check ("a raise's type", has (lines, "probe.sml:5:16: type"))
      val () = check ("the [] pattern", has (lines, "probe.sml:5:11: type"))
      val () = check ("the names a datatype declaration made, with their equality",
                      has (lines, "created tree (eq)") andalso has (lines, "created t") andalso not (has (lines, "created t (eq)")))
      val () = check ("the explicit type variables a val scopes", has (lines, "scoped 'a = 'a"))
      val () = check ("each binding of a group generalised at the binding",
                      List.length (List.filter (fn l => String.isSubstring "generalised" l) lines) >= 4)
      val () = check ("the default of an overloaded constant", has (lines, "default int") andalso has (lines, "default word"))
      val () = check ("a declaration that failed", has (lines, "probe.sml:10:1: failed"))
      val () = check ("what it recorded is dropped",
                      not (List.exists (fn l => String.isSubstring "probe.sml:10:" l andalso not (String.isSubstring "failed" l)) lines))
      (* the names after "generalised " in each such line *)
      val gens = List.mapPartial
                   (fn l => let val (_, rest) = Substring.position "generalised " (Substring.full l)
                            in if Substring.isEmpty rest then NONE
                               else SOME (String.tokens (fn c => c = #"," orelse Char.isSpace c)
                                                        (Substring.string (Substring.triml 12 rest)))
                            end) lines
      val () = check ("each variable a binding generalised once",
                      List.all (fn ns => List.all (fn n => List.length (List.filter (fn m => m = n) ns) = 1) ns) gens)
      val () = check ("each node's default once",
                      List.length (List.filter (fn l => String.isSubstring "probe.sml:4:40: default" l) lines) = 1)
      val () = check ("the declarations that elaborated", has (lines, "probe.sml:11:1: elaborated"))
      (* SourceTy: one node for each type *)
      val () = SourceTy.settled := true
      val t1 = SourceTy.ofType (Types.TArrow (Types.intTy, Types.listTy Types.intTy))
      val t2 = SourceTy.ofType (Types.TArrow (Types.intTy, Types.listTy Types.intTy))
      val () = check ("SourceTy is hash-consed", SourceTy.same (t1, t2))
      val () = check ("SourceTy prints as Types does", SourceTy.toString t1 = Types.toString (Types.TArrow (Types.intTy, Types.listTy Types.intTy)))
      val () = check ("a zonk keeps to its budget",
                      (SourceTy.budget := 2; ignore (SourceTy.ofType (Types.listTy (Types.listTy Types.intTy))); false)
                      handle SourceTy.Budget => true)
      val () = SourceTy.budget := 10000000
      (* the unit undone: what it recorded goes *)
      val () = UnitBasis.undo start
      val () = check ("a unit undone leaves nothing recorded", Witness.mark () = marked)
      (* the default of an overloaded identifier, where its context ends in
         each mode of --overloading *)
      fun mode m =
        let
          val name = Elaborate.overloadModeName m
          val () = Elaborate.overloading := m
          val f = Source.fromString ("mode-" ^ name ^ ".sml", "fun twice x = x + x\nval n = twice 2\n")
          val () = Source.register f
          val (ds, _) = Parser.parseTokensWith (Lexer.tokenize f, Fixity.initial)
          val env = ref Env.initial
          val start = UnitBasis.begin (!env, Fixity.initial)
          val () = Elaborate.elabTop (env, ds)
          val () = Elaborate.finish ()
          val lines = dumped ()
          val () = check ("the default of an overloaded identifier, --overloading=" ^ name,
                          has (lines, "mode-" ^ name ^ ".sml:1:17: default int"))
        in UnitBasis.undo start end
      val () = List.app mode [Elaborate.OverBinding, Elaborate.OverDeclaration, Elaborate.OverToplevel, Elaborate.OverTopdec]
      val () = Elaborate.overloading := Elaborate.OverDeclaration
    in
      if !failures = 0 then print "PASS compiler witnesses\n"
      else (print (Int.toString (!failures) ^ " failed\n"); OS.Process.exit OS.Process.failure)
    end
end
val () = CompilerWitnessTests.main ()
