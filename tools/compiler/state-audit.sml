(* Audit persistent compiler roots from parsed SML, not indentation or text
   matches. Function-local scratch storage is outside this ownership domain. *)
structure CompilerStateAudit =
struct
  open Ast
  datatype kind = Cell | Array | RefArray | Table | RefTable | TableMap | TableOption | TableVector
  type root = {key : string, name : string, kind : kind, span : Source.span}
  type registration = {key : string, variable : string, adapter : string, clone : string option}
  fun name (EVar (id, _, _, _)) = SOME (longidToString id)
    | name (ETyped (e, _, _, _)) = name e
    | name _ = NONE
  fun patName (PVar (([], n), _, _, _)) = SOME n
    | patName (PTyped (p, _, _, _)) = patName p
    | patName _ = NONE
  fun patType (PTyped (_, t, _, _)) = SOME t | patType _ = NONE
  fun hasTable t =
    case t of
      TyCon (ts, (path, n), _, _) => (path = ["IntTable"] andalso n = "table") orelse List.exists hasTable ts
    | TyRecord (fs, _, _) => List.exists (hasTable o #2) fs
    | TyTuple (ts, _, _) => List.exists hasTable ts
    | _ => false
  fun mutableType t =
    case t of
      TyCon (ts,(path,n),_, _) =>
        (path=[] andalso (n="ref" orelse n="array")) orelse
        (path=["IntTable"] andalso n="table") orelse List.exists mutableType ts
    | TyRecord (fs,_, _) => List.exists (mutableType o #2) fs
    | TyTuple (ts,_, _) => List.exists mutableType ts
    | _ => false
  fun typeKind t =
    case t of
      TyCon ([inner], ([], "ref"), _, _) =>
        (case inner of
           TyCon (_, (["IntTable"], "table"), _, _) => RefTable
         | TyCon (_, ([], "array"), _, _) => RefArray
         | TyCon (_, ([], "option"), _, _) => if hasTable inner then TableOption else Cell
         | TyCon (_, (["StringMap"], "map"), _, _) => if hasTable inner then TableMap else Cell
         | _ => Cell)
    | TyCon (_, (["IntTable"], "table"), _, _) => Table
    | TyCon (_, ([], "array"), _, _) => Array
    | TyCon (_, ([], "vector"), _, _) => if hasTable t then TableVector else Cell
    | _ => Cell
  val allocators = ["ref", "Array.array", "Array.tabulate", "Array.fromList", "IntTable.table"]
  (* Eager collection builders invoke their callback during initialization.
     A function value itself allocates no persistent scratch cells yet. *)
  fun allocations eager e =
    case e of
      EApp (f, a, _, _) =>
        let val n = name f
            val callback = List.exists (fn x => SOME x = n)
              ["Vector.tabulate", "Array.tabulate", "List.tabulate", "Vector.map", "Array.map", "List.map"]
            val direct = case n of SOME x => if List.exists (fn y => x = y) allocators then [x] else [] | NONE => []
        in direct @ allocations false f @ allocations callback a end
    | ERecord (fs, _, _) => List.concat (List.map (allocations eager o #2) fs)
    | ETuple (es, _, _) => List.concat (List.map (allocations eager) es)
    | EList (es, _, _, _) => List.concat (List.map (allocations eager) es)
    | ESeq (es, _, _) => List.concat (List.map (allocations eager) es)
    | ETyped (e, _, _, _) => allocations eager e
    | EIf (a,b,c,_, _) => allocations eager a @ allocations eager b @ allocations eager c
    | EAndalso (a,b,_, _) => allocations eager a @ allocations eager b
    | EOrelse (a,b,_, _) => allocations eager a @ allocations eager b
    | EHandle (e, rs, _, _) => allocations eager e @ List.concat (List.map (allocations eager o #2) rs)
    | ECase (e, rs, _, _) => allocations eager e @ List.concat (List.map (allocations eager o #2) rs)
    | ELet (ds,e,_, _) => List.concat (List.map values ds) @ allocations eager e
    | EFn (rs,_,_, _) => if eager then List.concat (List.map (allocations false o #2) rs) else []
    | _ => []
  and values (DVal (_,bs,_, _)) = List.concat (List.map (allocations false o #2) bs)
    | values (DLocal (a,b,_, _)) = List.concat (List.map values (a@b))
    | values _ = []

  fun cloneName e =
    case name e of SOME n => SOME n
    | NONE => (case e of EApp (f,a,_, _) =>
                 (case (name f, name a) of (SOME x,SOME y) => SOME (x ^ " " ^ y) | _ => NONE)
               | _ => NONE)
  fun registration e =
    case e of
      EApp (EVar ((["CompilerState"], adapter),_,_, _), ETuple (EScon (SString key,_,_, _) :: variable :: rest,_, _),_, _) =>
        (case name variable of
           SOME v => SOME {key=key, variable=v, adapter=adapter,
                          clone=case rest of [clone] => cloneName clone | _ => NONE}
         | NONE => NONE)
    | _ => NONE
  val lifecycle = ["CompilerState.roots", "CompilerState.baseline", "CompilerState.next", "CompilerState.active"]
  fun analyse (path, text) =
    let
      val source = Source.fromString (path,text)
      val (ds,_) = Parser.parseTokensWith (Lexer.tokenize source,Fixity.initial)
      val roots = ref [] : root list ref
      val registered = ref [] : registration list ref
      val problems = ref [] : string list ref
      fun problem s = problems := s :: !problems
      fun value prefix (p,e) =
        let
          val () = case registration e of SOME r => registered := r :: !registered | NONE => ()
          val allocated = allocations false e
          val typed = case patType p of SOME t => mutableType t | NONE => false
          val key = case patName p of SOME n => prefix ^ "." ^ n | NONE => ""
        in
          if (null allocated andalso not typed) orelse List.exists (fn x => x=key) lifecycle then ()
          else case patName p of
            NONE => problem (Source.describe (spanOfPat p) ^ ": persistent storage needs a named root")
          | SOME n =>
              let val kind = case patType p of SOME t => typeKind t
                    | NONE => if List.exists (fn x => x="ref") allocated then Cell
                              else if List.exists (fn x => x="IntTable.table") allocated then Table else Array
              in roots := {key=key,name=n,kind=kind,span=spanOfPat p} :: !roots end
        end
      fun walk prefix d =
        case d of
          DVal (_,bs,_, _) => List.app (value prefix) bs
        | DStructure (bs,_, _) => List.app (fn b => str (if prefix="" then #name b else prefix ^ "." ^ #name b) (#strexp b)) bs
        | DFunctor (bs,_, _) => List.app (fn b => str (if prefix="" then #name b else prefix ^ "." ^ #name b) (#body b)) bs
        | DLocal (a,b,_, _) => List.app (walk prefix) (a@b)
        | DAbstype (_,_,ds,_, _) => List.app (walk prefix) ds
        | _ => ()
      and str prefix s =
        case s of
          StrStruct (ds,_, _) => List.app (walk prefix) ds
        | StrAscribe (s,_,_,_, _) => str prefix s
        | StrLet (ds,s,_, _) => (List.app (walk prefix) ds;str prefix s)
        | _ => ()
      val () = List.app (walk "") ds
      fun expected kind =
        case kind of
          Cell => ("cellRoot",NONE) | Array => ("arrayRoot",NONE) | Table => ("tableRoot",NONE)
        | TableVector => ("tableVectorRoot",NONE)
        | RefArray => ("refRoot",SOME "CompilerState.copyArray")
        | RefTable => ("refRoot",SOME "IntTable.copy")
        | TableOption => ("refRoot",SOME "Option.map IntTable.copy")
        | TableMap => ("refRoot",SOME "StringMap.map IntTable.copy")
      fun check (r : root) =
        case List.filter (fn x : registration => #key x = #key r) (!registered) of
          [] => problem (Source.describe (#span r) ^ ": unregistered compiler root " ^ #key r)
        | [x] => if #variable x = #name r andalso (#adapter x,#clone x) = expected (#kind r) then ()
                 else problem (Source.describe (#span r) ^ ": wrong ownership adapter for " ^ #key r)
        | _ => problem ("duplicate compiler root registration: " ^ #key r)
      val () = List.app check (!roots)
      val () = List.app (fn r : registration =>
        if List.exists (fn x : root => #key x = #key r) (!roots) then ()
        else problem ("registration without persistent root: " ^ #key r)) (!registered)
    in {roots=List.rev (!roots),problems=List.rev (!problems)} end

  fun selfTest () =
    let
      fun check (label,text,expected) =
        let val result = analyse ("audit-fixture.sml",text)
        in if null (#problems result) = expected then () else raise Fail ("state audit fixture: " ^ label) end
      val registered = "structure A = struct val x = ref 0 val () = CompilerState.cellRoot (\"A.x\",x) end"
      val () = check ("registered",registered,true)
      val () = check ("typed factory","structure A = struct val x : int ref = Factory.make () end",false)
      val () = check ("functor root","functor A () = struct val x = ref 0 end",false)
      val () = check ("missing","structure A = struct val x = ref 0 end",false)
      val () = check ("comment","structure A = struct (* val () = CompilerState.cellRoot (\"A.x\",x) *) val x = ref 0 end",false)
      val () = check ("scratch","structure A = struct fun f () = ref 0 val g = fn () => ref 0 end",true)
      val () = check ("nested/local","structure A = struct local val x = ref 0 in structure B = struct val y = ref 0 end end end",false)
      val () = check ("shallow table","structure A = struct val x : int IntTable.table ref = ref (IntTable.table 16) val () = CompilerState.cellRoot (\"A.x\",x) end",false)
      val () = check ("table clone","structure A = struct val x : int IntTable.table ref = ref (IntTable.table 16) val () = CompilerState.refRoot (\"A.x\",x,IntTable.copy) end",true)
      val () = check ("callback","structure A = struct val x : int IntTable.table vector = Vector.tabulate (2,fn _ => IntTable.table 16) end",false)
      val () = check ("wrong variable","structure A = struct val x = ref 0 val () = CompilerState.cellRoot (\"A.x\",y) end",false)
      val () = check ("initialization scratch requires review","structure A = struct val x = let val a = Array.array (2,0) in Array.vector a end end",false)
    in print "PASS compiler-state audit planted faults\n" end
  fun read file = let val input=TextIO.openIn file in TextIO.inputAll input before TextIO.closeIn input end
  fun main () =
    let
      val args=CommandLine.arguments ()
      val () = if List.exists (fn x => x="--self-test") args then selfTest () else ()
      val files=List.filter (fn x => x<>"--self-test") args
      val results=List.map (fn path => analyse (path,read path)) files
      val errors=List.concat (List.map #problems results)
      val count=List.foldl (fn (r,n) => n+length (#roots r)) 0 results
    in
      if null errors then print ("PASS compiler-state audit: " ^ Int.toString count ^ " roots\n")
      else (List.app (fn s => print ("FAIL compiler-state audit: " ^ s ^ "\n")) errors;OS.Process.exit OS.Process.failure)
    end
end
