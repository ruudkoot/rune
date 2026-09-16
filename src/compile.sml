signature COMPILE =
sig
  type instruction = {code : int, operand : IntInf.int ref, pos : Source.pos}
  type function = {locals : int, environment : int, code : instruction list}
  type program = {strings : string list, functions : function list}
  val program : (Core.pattern * Core.expr) list -> program
end
structure Compile :> COMPILE =
struct
  open Core
  type instruction = {code : int, operand : IntInf.int ref, pos : Source.pos}
  type function = {locals : int, environment : int, code : instruction list}
  type program = {strings : string list, functions : function list}
  datatype access = Local of int | Environment of int | Self
  fun patternIds (P (_,_,node)) = case node of Bind id => [id]
    | TuplePattern ps => List.concat (List.map patternIds ps)
    | ConstructorPattern (_,SOME pat) => patternIds pat | _ => []
  fun member id ids = List.exists (fn n => n = id) ids
  fun insert id [] = [id]
    | insert id (x::xs) = if id = x then x::xs else if id < x then id::x::xs else x::insert id xs
  (* Ascending binding identities give a deterministic environment layout. *)
  fun free expression =
    let fun walk bound (E (_,_,node)) acc =
          let fun sub e a = walk bound e a
              fun many es initialAcc = List.foldl (fn (e,currentAcc) => sub e currentAcc) initialAcc es
          in case node of
              Variable id => if member id bound then acc else insert id acc
            | Binary (_,a,b) => sub b (sub a acc) | Apply (f,a) => sub a (sub f acc)
            | If (c,a,b) => sub b (sub a (sub c acc))
            | Tuple es => many es acc | Sequence es => many es acc
            | Case (subject,clauses) => List.foldl
                (fn ((pat,body),a) => walk (List.concat [patternIds pat,bound]) body a) (sub subject acc) clauses
            | Function {self,param,body} => walk
                (List.concat [patternIds param,(case self of NONE => bound | SOME id => id::bound)]) body acc
            | Let (ds,body) =>
                let fun bindings currentBound [] a = walk currentBound body a
                      | bindings currentBound ((pat,e)::rest) a =
                          bindings (List.concat [patternIds pat,currentBound]) rest (walk currentBound e a)
                in bindings bound ds acc end
            | _ => acc
          end
    in walk [] expression [] end
  fun program declarations : program =
    let
      val strings = ref ([] : string list) val stringCount = ref 0
      val functions = ref ([] : (int * function) list) val functionCount = ref 1
      val instructions = ref 0
      fun lookup p env id = case List.find (fn (n,_) => n = id) env of
          SOME (_,a) => a | NONE => Source.fail p "internal" "unresolved core binding"
      fun build functionId capturedIds selfBinding parameter functionBody entryDecls =
        let
          val code = ref ([] : instruction list) val counter = ref 0
          val locals = ref (if functionId = 0 then 0 else 1)
          fun emit p (opnum : int) (operand : IntInf.int) =
            if !instructions >= Source.maxCount then Source.fail p "limit" "too many instructions"
            else let val target = ref operand
                 in code := {code=opnum,operand=target,pos=p} :: !code;
                    counter := !counter+1; instructions := !instructions+1; target end
          fun simple p opnum = ignore (emit p opnum (IntInf.fromInt 0))
          fun small p opnum n = ignore (emit p opnum (IntInf.fromInt n))
          fun load p env id = case lookup p env id of Local n => small p Opcode.LOAD n
            | Environment n => small p Opcode.ENV n | Self => simple p Opcode.SELF
          fun slot p =
            let val n = !locals
            in if n >= Source.maxCount then Source.fail p "limit" "too many local slots" else ();
               locals := n+1; n end
          fun save p = let val n = slot p in small p Opcode.STORE n; n end
          fun stringConstant p s =
            let val n = !stringCount
            in if n >= Source.maxCount then Source.fail p "limit" "too many string constants" else ();
               strings := s :: !strings; stringCount := n+1; small p Opcode.STRING n end
          fun patch targets = List.app (fn target => target := IntInf.fromInt (!counter)) targets
          (* Every test leaves the operand stack as it found it. Partial bindings
             are clause-local slots; a failed clause cannot expose them. *)
          fun attempt env subject (P (p,_,node)) failures =
            let fun test () = failures := emit p Opcode.JUMP_FALSE (IntInf.fromInt 0) :: !failures
                fun literal emitLiteral =
                  (small p Opcode.LOAD subject; emitLiteral (); simple p Opcode.EQ; test (); env)
            in case node of
                Bind id => (id,Local subject)::env
              | Wildcard => env
              | UnitPattern => (small p Opcode.LOAD subject; simple p Opcode.CHECK_UNIT; env)
              | IntegerPattern n => literal (fn () => ignore (emit p Opcode.INT n))
              | BooleanPattern b => literal (fn () => small p Opcode.BOOL (if b then 1 else 0))
              | StringPattern s => literal (fn () => stringConstant p s)
              | ConstructorPattern (id,arg) =>
                  (small p Opcode.LOAD subject; small p Opcode.IS_CON id; test ();
                   case arg of NONE => env | SOME pat =>
                     (small p Opcode.LOAD subject; small p Opcode.PAYLOAD id;
                      attempt env (save p) pat failures))
              | TuplePattern ps =>
                  let val () = small p Opcode.LOAD subject
                      val () = small p Opcode.CHECK_TUPLE (List.length ps)
                      val () = simple p Opcode.POP
                      fun loop currentEnv _ [] = currentEnv
                        | loop currentEnv i (pat::rest) =
                            (small p Opcode.LOAD subject; small p Opcode.GET i;
                             loop (attempt currentEnv (save p) pat failures) (i+1) rest)
                  in loop env 0 ps end
            end
          fun bind failure env (pat as P (p,_,_)) =
            let val subject = save p val failures = ref ([] : IntInf.int ref list)
                val env' = attempt env subject pat failures
                val () = if List.null (!failures) then () else
                  let val join = emit p Opcode.JUMP (IntInf.fromInt 0)
                      val () = patch (!failures)
                      val () = small p Opcode.FAIL failure
                  in patch [join] end
            in env' end
          fun value env (e as E (p,_,node)) = case node of
              Integer n => ignore (emit p Opcode.INT n)
            | Boolean b => small p Opcode.BOOL (if b then 1 else 0)
            | Unit => simple p Opcode.UNIT
            | String s => stringConstant p s
            | Constructor id => small p Opcode.CONSTRUCTOR id
            | Case (subject,clauses) => matching value true env p subject clauses
            | Variable id => load p env id
            | Builtin n => small p Opcode.BUILTIN n
            | Apply (f,a) => (value env f; value env a; simple p Opcode.CALL)
            | Binary (oper,a,b) =>
                (value env a; value env b;
                 simple p (case oper of "+" => Opcode.ADD | "-" => Opcode.SUB | "*" => Opcode.MUL
                   | "div" => Opcode.DIV | "mod" => Opcode.MOD | "^" => Opcode.CONCAT
                   | "=" => Opcode.EQ | "<>" => Opcode.NE | "<" => Opcode.LT | "<=" => Opcode.LE
                   | ">" => Opcode.GT | ">=" => Opcode.GE
                   | _ => Source.fail p "internal" "unknown binary operator"))
            | If (c,a,b) =>
                let val () = value env c val branch = emit p Opcode.JUMP_FALSE (IntInf.fromInt 0)
                  val () = value env a val join = emit p Opcode.JUMP (IntInf.fromInt 0)
                    val () = branch := IntInf.fromInt (!counter)
                    val () = value env b
                in join := IntInf.fromInt (!counter) end
            | Let (ds,letBody) => value (bindings env ds) letBody
            | Sequence es => sequence value env es
            | Tuple es => (List.app (value env) es; small p Opcode.TUPLE (List.length es))
            | Function {self,param,body} =>
                let val fid = !functionCount val captures = free e
                    val () = if fid >= Source.maxCount then Source.fail p "limit" "too many functions" else ()
                    val () = functionCount := fid+1
                    val () = build fid captures self (SOME param) (SOME body) []
                    val () = List.app (load p env) captures
                in small p Opcode.CLOSURE fid end
          and matching finish joins env p subject clauses =
            let val () = value env subject val source = save p
                val targets = ref ([] : IntInf.int ref list)
                fun clause (pat,body) =
                  let val failures = ref ([] : IntInf.int ref list)
                      val env' = attempt env source pat failures
                      val () = finish env' body
                      val () = if joins then targets := emit p Opcode.JUMP (IntInf.fromInt 0) :: !targets else ()
                  in patch (!failures) end
                val () = List.app clause clauses
                val () = small p Opcode.FAIL 0
            in patch (!targets) end
          and bindings env [] = env
            | bindings env ((pat,e)::rest) = (value env e; bindings (bind 1 env pat) rest)
          and sequence last env es = case es of
              [] => Source.fail Source.start "internal" "empty core sequence"
            | [e] => last env e
            | e::rest => (value env e; simple (Core.position e) Opcode.POP; sequence last env rest)
          and tail env (e as E (p,_,node)) = case node of
              Apply (f,a) => (value env f; value env a; simple p Opcode.TAILCALL)
            | Case (subject,clauses) => matching tail false env p subject clauses
            | If (c,a,b) =>
                let val () = value env c val branch = emit p Opcode.JUMP_FALSE (IntInf.fromInt 0)
                    val () = tail env a val () = branch := IntInf.fromInt (!counter)
                in tail env b end
            | Let (ds,body) => tail (bindings env ds) body
            | Sequence es => sequence tail env es
            | _ => (value env e; simple p Opcode.RETURN)
          val capturedEnv = ListPair.zip (capturedIds,List.tabulate (List.length capturedIds,Environment))
          val env = case selfBinding of NONE => capturedEnv | SOME id => (id,Self)::capturedEnv
          val () = case (parameter,functionBody) of
              (SOME pat,SOME e) => (small (Core.position e) Opcode.LOAD 0; tail (bind 0 env pat) e)
            | (NONE,NONE) => (ignore (bindings env entryDecls); simple Source.start Opcode.HALT)
            | _ => Source.fail Source.start "internal" "invalid core function"
        in functions := (functionId,{locals= !locals,environment=List.length capturedIds,code=List.rev (!code)}):: !functions end
      val () = build 0 [] NONE NONE NONE declarations
      fun function i = case List.find (fn (id,_) => id = i) (!functions) of SOME (_,f) => f
        | NONE => Source.fail Source.start "internal" "missing emitted function"
    in {strings=List.rev (!strings),functions=List.tabulate (!functionCount,function)} end
end
