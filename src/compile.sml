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
    | TuplePattern ps => List.concat (List.map patternIds ps) | _ => []
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
            | Function {self,param,body} => walk
                (patternIds param @ (case self of NONE => bound | SOME id => id::bound)) body acc
            | Let (ds,body) =>
                let fun bindings currentBound [] a = walk currentBound body a
                      | bindings currentBound ((pat,e)::rest) a =
                          bindings (patternIds pat @ currentBound) rest (walk currentBound e a)
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
          fun emit p opnum operand =
            if !instructions >= Source.maxCount then Source.fail p "limit" "too many instructions"
            else let val target = ref operand
                 in code := {code=opnum,operand=target,pos=p} :: !code;
                    counter := !counter+1; instructions := !instructions+1; target end
          fun simple p opnum = ignore (emit p opnum 0)
          fun small p opnum n = ignore (emit p opnum (IntInf.fromInt n))
          fun load p env id = case lookup p env id of Local n => small p Opcode.LOAD n
            | Environment n => small p Opcode.ENV n | Self => simple p Opcode.SELF
          fun bind env (P (p,_,node)) = case node of
              Bind id =>
                let val n = !locals
                in if n >= Source.maxCount then Source.fail p "limit" "too many local slots" else ();
                   locals := n+1; small p Opcode.STORE n; (id,Local n)::env end
            | Wildcard => (simple p Opcode.POP; env)
            | UnitPattern => (simple p Opcode.CHECK_UNIT; env)
            | TuplePattern ps =>
                let val () = small p Opcode.CHECK_TUPLE (List.length ps)
                    fun loop currentEnv _ [] = currentEnv
                      | loop currentEnv i (pat::rest) =
                          (simple p Opcode.DUP; small p Opcode.GET i;
                           loop (bind currentEnv pat) (i+1) rest)
                    val env' = loop env 0 ps
                in simple p Opcode.POP; env' end
          fun value env (e as E (p,_,node)) = case node of
              Integer n => ignore (emit p Opcode.INT n)
            | Boolean b => small p Opcode.BOOL (if b then 1 else 0)
            | Unit => simple p Opcode.UNIT
            | String s =>
                let val n = !stringCount
                in if n >= Source.maxCount then Source.fail p "limit" "too many string constants" else ();
                   strings := s :: !strings; stringCount := n+1; small p Opcode.STRING n end
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
                let val () = value env c val branch = emit p Opcode.JUMP_FALSE 0
                    val () = value env a val join = emit p Opcode.JUMP 0
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
          and bindings env [] = env
            | bindings env ((pat,e)::rest) = (value env e; bindings (bind env pat) rest)
          and sequence last env es = case es of
              [] => Source.fail Source.start "internal" "empty core sequence"
            | [e] => last env e
            | e::rest => (value env e; simple (Core.position e) Opcode.POP; sequence last env rest)
          and tail env (e as E (p,_,node)) = case node of
              Apply (f,a) => (value env f; value env a; simple p Opcode.TAILCALL)
            | If (c,a,b) =>
                let val () = value env c val branch = emit p Opcode.JUMP_FALSE 0
                    val () = tail env a val () = branch := IntInf.fromInt (!counter)
                in tail env b end
            | Let (ds,body) => tail (bindings env ds) body
            | Sequence es => sequence tail env es
            | _ => (value env e; simple p Opcode.RETURN)
          val capturedEnv = ListPair.zip (capturedIds,List.tabulate (List.length capturedIds,Environment))
          val env = case selfBinding of NONE => capturedEnv | SOME id => (id,Self)::capturedEnv
          val () = case (parameter,functionBody) of
              (SOME pat,SOME e) => (small (Core.position e) Opcode.LOAD 0; tail (bind env pat) e)
            | (NONE,NONE) => (ignore (bindings env entryDecls); simple Source.start Opcode.HALT)
            | _ => Source.fail Source.start "internal" "invalid core function"
        in functions := (functionId,{locals= !locals,environment=List.length capturedIds,code=List.rev (!code)}):: !functions end
      val () = build 0 [] NONE NONE NONE declarations
      fun function i = case List.find (fn (id,_) => id = i) (!functions) of SOME (_,f) => f
        | NONE => Source.fail Source.start "internal" "missing emitted function"
    in {strings=List.rev (!strings),functions=List.tabulate (!functionCount,function)} end
end
