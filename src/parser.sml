structure Parser =
struct
  open Syntax
  fun parse tokens =
    let
      val remaining = ref tokens
      val depth = ref 0
      fun current () = case !remaining of t::_ => t | [] => (Lexer.EOF, Source.start)
      fun position () = #2 (current ())
      fun spelling () = case #1 (current ()) of Lexer.Word s => s | Lexer.Symbol s => s | _ => ""
      fun is s = spelling () = s
      fun pop () = case !remaining of _::ts => remaining := ts | [] => ()
      fun error msg = Source.fail (position ()) "syntax" msg
      fun expect s = if is s then pop () else error ("expected '" ^ s ^ "'")
      val reserved = ["val", "fn", "fun", "datatype", "case", "of", "in", "end", "if", "then", "else", "let", "andalso", "orelse", "div", "mod"]
      fun name s = not (List.exists (fn x => x = s) reserved)
      fun bindingName () = case #1 (current ()) of Lexer.Word s =>
            if name s andalso s <> "true" andalso s <> "false"
               andalso not (CharVector.exists (fn c => c = #".") s)
            then (pop (); s) else error "expected value binding name"
          | _ => error "expected value binding name"
      fun startsPattern () = case #1 (current ()) of
          Lexer.Number _ => true | Lexer.Text _ => true
        | Lexer.Word s => name s
        | Lexer.Symbol s => s = "(" orelse s = "[" orelse s = "_"
        | _ => false
      fun pattern nesting =
        let val prefix = case #1 (current ()) of Lexer.Word _ => true | _ => false
            val first = atomicPattern nesting
            val left = case first of P (p,Variable s) =>
             if prefix andalso startsPattern () then P (p,ConstructorPattern (s,atomicPattern (nesting+1))) else first
           | _ => first
        in if is "::" then
             let val p = position () val () = pop ()
                 val right = pattern (nesting+1)
             in P (p,ConstructorPattern ("::",P (p,TuplePattern [left,right]))) end
           else left end
      and atomicPattern nesting =
        let val p = position ()
            val () = if nesting > 256 then error "pattern nesting exceeds 256" else ()
        in if is "_" then (pop (); P (p, Wildcard))
           else if is "[" then
             (pop ();
              let fun elements count acc =
                    if count >= 128 then error "list pattern exceeds 128 elements"
                    else let val pat = pattern (nesting+1)
                         in if is "," then (pop (); elements (count+1) (pat::acc))
                            else List.rev (pat::acc) end
                  val ps = if is "]" then [] else elements 0 []
                  val () = expect "]"
              in List.foldr (fn (pat,tail) =>
                   P (p,ConstructorPattern ("::",P (p,TuplePattern [pat,tail]))))
                   (P (p,Variable "nil")) ps end)
           else if is "(" then
             (pop (); if is ")" then (pop (); P (p, UnitPattern))
              else let val first = pattern (nesting+1)
                       fun rest acc = if is "," then (pop (); rest (pattern (nesting+1)::acc))
                         else List.rev acc
                       val ps = rest [first]
                       val () = expect ")"
                   in case ps of [pat] => pat | _ => P (p, TuplePattern ps) end)
           else case #1 (current ()) of
             Lexer.Number n => (pop (); P (p,IntegerPattern n))
           | Lexer.Text s => (pop (); P (p,StringPattern s))
           | Lexer.Word "true" => (pop (); P (p,BooleanPattern true))
           | Lexer.Word "false" => (pop (); P (p,BooleanPattern false))
           | _ => P (p, Variable (bindingName ()))
        end
      fun typeExpression nesting =
        let val p = position ()
            val () = if nesting > 256 then error "type nesting exceeds 256" else ()
            fun typeName () = case #1 (current ()) of
                Lexer.Word s => if name s then (pop (); s) else error "expected type constructor"
              | _ => error "expected type constructor"
            fun app () =
              let val p = position ()
                  val first = case #1 (current ()) of
                      Lexer.TypeVariable s => (pop (); Ty (p,TypeVariable s))
                    | Lexer.Word _ => Ty (p,TypeName (typeName (),[]))
                    | Lexer.Symbol "(" =>
                        (pop (); let val t = typeExpression (nesting+1)
                            fun rest acc = if is "," then
                              (pop (); rest (typeExpression (nesting+1)::acc)) else List.rev acc
                            val ts = rest [t] val () = expect ")"
                         in case ts of [single] => single | _ => Ty (p,TypeName (typeName (),ts)) end)
                    | _ => error "expected payload type"
                  fun loop t = case #1 (current ()) of
                      Lexer.Word s => if name s then (pop (); loop (Ty (p,TypeName (s,[t])))) else t
                    | _ => t
              in loop first end
            val first = app ()
            fun product acc = if is "*" then (pop (); product (app ()::acc)) else List.rev acc
            val parts = product [first]
            val left = case parts of [t] => t | _ => Ty (p,Product parts)
        in if is "->" then (pop (); Ty (p,Arrow (left,typeExpression (nesting+1)))) else left end
      fun startsAtom () = case #1 (current ()) of
          Lexer.Number _ => true | Lexer.Text _ => true
        | Lexer.Word s => name s orelse s = "let"
        | Lexer.Symbol s => s = "(" orelse s = "[" orelse s = "~"
        | _ => false
      fun precedence s = case s of
          "orelse" => 1 | "andalso" => 2
        | "=" => 4 | "<>" => 4 | "<" => 4 | "<=" => 4 | ">" => 4 | ">=" => 4
        | "::" => 5
        | "+" => 6 | "-" => 6 | "^" => 6
        | "*" => 7 | "div" => 7 | "mod" => 7 | _ => ~1
      fun expression minimum =
        let
          val () = depth := !depth+1
          val () = if !depth > 256 then error "expression nesting exceeds 256" else ()
          val p = position ()
          val first = if is "if" andalso minimum <= 2 then
              (pop (); let val c = expression 0
                           val () = expect "then"
                           val a = expression 0
                           val () = expect "else"
                           val b = expression 0
                       in E (p, If (c,a,b)) end)
            else if is "fn" andalso minimum <= 2 then
              (pop (); E (p, Fn (matchClauses ())))
            else if is "case" andalso minimum <= 2 then
              (pop (); let val subject = expression 0 val () = expect "of"
                       in E (p,Case (subject,matchClauses ())) end)
            else application ()
          fun infixes left =
            let val oper = spelling ()
                val prec = precedence oper
                val p = position ()
            in if prec < minimum orelse prec < 0 then left
               else (pop ();
                 let val right = expression (if prec <= 2 orelse oper = "::" then prec else prec+1)
                     val result = case oper of
                       "andalso" => E (p, If (left, right, E (p, Boolean false)))
                     | "orelse" => E (p, If (left, E (p, Boolean true), right))
                     | "::" => E (p,Apply (E (p,Name "::"),E (p,Tuple [left,right])))
                     | _ => E (p, Binary (oper, left, right))
                 in infixes result end)
            end
          val result = infixes first
        in depth := !depth-1; result end
      and application () =
        let val first = atom ()
            fun loop left = if startsAtom () then
              let val right = atom ()
              in loop (E (Syntax.position left, Apply (left,right))) end else left
        in loop first end
      and atom () =
        let val (kind,p) = current ()
        in case kind of
            Lexer.Number n => (pop (); E (p, Integer n))
          | Lexer.Text s => (pop (); E (p, String s))
          | Lexer.Word "true" => (pop (); E (p, Boolean true))
          | Lexer.Word "false" => (pop (); E (p, Boolean false))
          | Lexer.Word "let" =>
              (pop (); let val ds = declarations "in"
                           val () = expect "in"
                           val body = sequence "end"
                           val () = expect "end"
                       in E (p, Let (ds,body)) end)
          | Lexer.Word s => if name s then (pop (); E (p, Name s)) else error "expected expression"
          | Lexer.Symbol "~" => (pop (); E (p, Name "~"))
          | Lexer.Symbol "[" =>
              (pop ();
               let fun elements count acc =
                     if count >= 128 then error "list expression exceeds 128 elements"
                     else let val e = expression 0
                          in if is "," then (pop (); elements (count+1) (e::acc))
                             else List.rev (e::acc) end
                   val es = if is "]" then [] else elements 0 []
                   val () = expect "]"
               in List.foldr (fn (e,tail) =>
                    E (p,Apply (E (p,Name "::"),E (p,Tuple [e,tail]))))
                    (E (p,Name "nil")) es end)
          | Lexer.Symbol "(" =>
              (pop (); if is ")" then (pop (); E (p, Unit))
               else let val first = expression 0
                        fun tuple acc = if is "," then (pop (); tuple (expression 0::acc))
                          else E (p, Tuple (List.rev acc))
                        fun seq acc = if is ";" then (pop (); seq (expression 0::acc))
                          else E (p, Sequence (List.rev acc))
                        val e = if is "," then tuple [first]
                                else if is ";" then seq [first] else first
                        val () = expect ")"
                    in e end)
          | _ => error "expected expression"
        end
      and matchClauses () =
        let fun clause () = let val pat = pattern 0 val () = expect "=>"
                            in (pat,expression 0) end
            val first = clause ()
            fun rest acc = if is "|" then (pop (); rest (clause ()::acc)) else List.rev acc
        in rest [first] end
      and sequence stop =
        let val first = expression 0
            fun loop acc = if is ";" then
                  (pop (); if is stop then error "expected expression after ';'"
                   else loop (expression 0 :: acc))
                else case List.rev acc of [e] => e | es => E (Syntax.position first, Sequence es)
        in loop [first] end
      and declarations stop =
        let
          fun loop acc =
            if is ";" then (pop (); loop acc)
            else if is stop orelse (case #1 (current ()) of Lexer.EOF => true | _ => false)
              then List.rev acc
            else if is "val" then
              let val p = position ()
                  val () = pop ()
                  val binding = pattern 0
                  val () = expect "="
                  val e = expression 0
              in loop (Val (p,binding,e)::acc) end
            else if is "fun" then
              let val p = position () val () = pop () val f = bindingName ()
                  fun parameters count acc = if is "=" then List.rev acc
                    else if count >= 256 then error "fun exceeds 256 parameters"
                    else parameters (count+1) (atomicPattern 0::acc)
                  fun clause cp =
                    let val ps = parameters 0 []
                        val () = if null ps then error "fun requires at least one parameter" else ()
                        val () = expect "="
                    in (cp,ps,expression 0) end
                  val first as (_,ps,_) = clause p
                  val arity = List.length ps
                  fun rest acc = if is "|" then
                    let val () = pop () val cp = position () val name = bindingName ()
                        val () = if name = f then () else
                          Source.fail cp "syntax" "fun clauses must name the same function"
                        val next as (_,params,_) = clause cp
                        val () = if List.length params = arity then () else
                          Source.fail cp "syntax" "fun clauses must have the same number of parameters"
                    in rest (next::acc) end else List.rev acc
              in loop (Fun (p,f,rest [first])::acc) end
            else if is "datatype" then
              let val p = position () val () = pop ()
                  fun variable () = case #1 (current ()) of
                      Lexer.TypeVariable s => (pop (); s) | _ => error "expected type variable"
                  val variables = if is "(" then
                      (pop (); let val first = variable ()
                                   fun rest acc = if is "," then (pop (); rest (variable ()::acc)) else List.rev acc
                                   val vs = rest [first] val () = expect ")"
                               in vs end)
                    else (case #1 (current ()) of Lexer.TypeVariable _ => [variable ()] | _ => [])
                  val t = bindingName () val () = expect "="
                  fun constructor () =
                    let val cp = position () val c = bindingName ()
                        val payload = if is "of" then (pop (); SOME (typeExpression 0)) else NONE
                    in (cp,c,payload) end
                  val first = constructor ()
                  fun rest acc = if is "|" then (pop (); rest (constructor ()::acc)) else List.rev acc
              in loop (Datatype (p,variables,t,rest [first])::acc) end
            else error "expected 'val', 'fun', or 'datatype' declaration"
        in loop [] end
      val ds = declarations ""
      val () = case #1 (current ()) of Lexer.EOF => () | _ => error "unexpected trailing input"
    in ds end
end
