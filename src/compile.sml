structure Compile =
struct
  open Syntax
  datatype ty = TInt | TBool | TString | TUnit | TFunction of ty * ty
  datatype binding = Local of int | Builtin of int
  type instruction = {code : int, operand : IntInf.int ref, pos : Source.pos}
  type program = {locals : int, strings : string list, code : instruction list}
  fun typeName TInt = "int" | typeName TBool = "bool" | typeName TString = "string"
    | typeName TUnit = "unit"
    | typeName (TFunction (a,b)) = "(" ^ typeName a ^ " -> " ^ typeName b ^ ")"
  fun program declarations : program =
    let
      val code = ref ([] : instruction list)
      val counter = ref 0
      val locals = ref 0
      val strings = ref ([] : string list)
      val stringCount = ref 0
      fun emit p opnum operand =
        if !counter >= Source.maxCount then Source.fail p "limit" "too many instructions"
        else let val target = ref operand
             in code := {code=opnum,operand=target,pos=p} :: !code;
                counter := !counter+1; target end
      fun simple p opnum = ignore (emit p opnum 0)
      fun small p opnum n = ignore (emit p opnum (IntInf.fromInt n))
      fun require p expected actual =
        if expected = actual then () else Source.fail p "type"
          ("expected " ^ typeName expected ^ ", got " ^ typeName actual)
      fun lookup p env name = case List.find (fn (s,_) => s = name) env of
          SOME (_,value) => value
        | NONE => Source.fail p (if String.isSubstring "." name then "unsupported" else "scope")
            ("unbound name '" ^ name ^ "'")
      fun expression env depth (E (p,node)) =
        if depth > 256 then Source.fail p "limit" "expression tree exceeds depth 256"
        else let fun sub e = expression env (depth+1) e
        in case node of
            Integer n => (ignore (emit p Opcode.INT n); TInt)
          | Boolean b => (small p Opcode.BOOL (if b then 1 else 0); TBool)
          | Unit => (simple p Opcode.UNIT; TUnit)
          | String s =>
              let val n = !stringCount
              in if n >= Source.maxCount then Source.fail p "limit" "too many string constants" else ();
                 strings := s :: !strings; stringCount := n+1;
                 small p Opcode.STRING n; TString end
          | Name name =>
              let val (t,binding) = lookup p env name
              in (case binding of Local n => small p Opcode.LOAD n
                     | Builtin n => small p Opcode.BUILTIN n); t end
          | Apply (f,a) =>
              let val ft = sub f
                  val at = sub a
              in case ft of TFunction (arg,result) =>
                   (require p arg at; simple p Opcode.CALL; result)
                 | _ => Source.fail p "type" ("cannot apply a value of type " ^ typeName ft) end
          | Binary (oper,a,b) =>
              let val at = sub a
                  val bt = sub b
                  fun arithmetic opcode =
                    (require p TInt at; require p TInt bt; simple p opcode; TInt)
                  fun ordering opcode =
                    (require p TInt at; require p TInt bt; simple p opcode; TBool)
                  fun equality opcode =
                    (require p at bt;
                     case at of TFunction _ => Source.fail p "type" "functions do not admit equality"
                       | _ => (simple p opcode; TBool))
              in case oper of
                  "+" => arithmetic Opcode.ADD | "-" => arithmetic Opcode.SUB
                | "*" => arithmetic Opcode.MUL | "div" => arithmetic Opcode.DIV
                | "mod" => arithmetic Opcode.MOD
                | "^" => (require p TString at; require p TString bt; simple p Opcode.CONCAT; TString)
                | "=" => equality Opcode.EQ | "<>" => equality Opcode.NE
                | "<" => ordering Opcode.LT | "<=" => ordering Opcode.LE
                | ">" => ordering Opcode.GT | ">=" => ordering Opcode.GE
                | _ => Source.fail p "internal" "unknown binary operator" end
          | If (condition,yes,no) =>
              let val () = require (Syntax.position condition) TBool (sub condition)
                  val falseTarget = emit p Opcode.JUMP_FALSE 0
                  val yesType = sub yes
                  val endTarget = emit p Opcode.JUMP 0
                  val () = falseTarget := IntInf.fromInt (!counter)
                  val noType = sub no
                  val () = require p yesType noType
                  val () = endTarget := IntInf.fromInt (!counter)
              in yesType end
          | Let (ds,body) => expression (bindings env (depth+1) ds) (depth+1) body
          | Sequence es =>
              let fun loop [] = (simple p Opcode.UNIT; TUnit)
                    | loop [last] = sub last
                    | loop (first::rest) = (ignore (sub first); simple p Opcode.POP; loop rest)
              in loop es end
        end
      and bindings env depth ds =
        let fun loop env [] = env
              | loop env (Val (p,name,e)::rest) =
                  let val t = expression env depth e
                  in case name of
                      NONE => (simple p Opcode.POP; loop env rest)
                    | SOME s =>
                        let val slot = !locals
                        in if slot >= Source.maxCount then Source.fail p "limit" "too many local slots" else ();
                           locals := slot+1; small p Opcode.STORE slot;
                           loop ((s,(t,Local slot))::env) rest end
                  end
        in loop env ds end
      val basis = [("print", (TFunction (TString,TUnit), Builtin 0)),
                   ("Int.toString", (TFunction (TInt,TString), Builtin 1)),
                   ("not", (TFunction (TBool,TBool), Builtin 2)),
                   ("~", (TFunction (TInt,TInt), Builtin 3))]
      val _ = bindings basis 0 declarations
      val () = simple Source.start Opcode.HALT
    in {locals = !locals, strings = List.rev (!strings), code = List.rev (!code)} end
end
