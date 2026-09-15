(* Emits version-1 Rune bytecode from an already type-checked expression. *)
signature RUNE_EMIT =
sig
  val emit : RuneAst.expr -> Word8Vector.vector
end

structure RuneEmit : RUNE_EMIT =
struct
  open RuneAst

  fun u8 n = Word8.fromInt (Int.mod (n, 256))
  fun word32 n =
    let
      val value =
        if n < 0 then IntInf.fromInt n + (4294967296 : IntInf.int)
        else IntInf.fromInt n
      fun byte shift =
        u8 (IntInf.toInt (IntInf.mod (IntInf.div (value, shift), 256)))
    in
      [byte 16777216, byte 65536, byte 256, byte 1]
    end

  fun emit expression =
    let
      fun lookup name [] = raise Fail ("unbound variable: " ^ name)
        | lookup name ((boundName, index) :: rest) =
            if name = boundName then index else lookup name rest
      fun gen (EInt n, _, next) = (word32 1 @ word32 n, next)
        | gen (EBool value, _, next) =
            (word32 2 @ [u8 (if value then 1 else 0)], next)
        | gen (EVar name, environment, next) =
            (word32 3 @ word32 (lookup name environment), next)
        | gen (EBin (operator, left, right), environment, next) =
            let
              val (leftCode, nextLeft) = gen (left, environment, next)
              val (rightCode, nextRight) = gen (right, environment, nextLeft)
              val opcode =
                case operator of
                    Add => 5 | Sub => 6 | Mul => 7 | Div => 8
                  | Eq => 9 | Ne => 10 | Lt => 11 | Le => 12 | Gt => 13 | Ge => 14
            in
              (leftCode @ rightCode @ [u8 opcode], nextRight)
            end
        | gen (ESeq (first, second), environment, next) =
            let
              val (firstCode, nextFirst) = gen (first, environment, next)
              val (secondCode, nextSecond) = gen (second, environment, nextFirst)
            in
              (firstCode @ [u8 17] @ secondCode, nextSecond)
            end
        | gen (ELet (name, value, body), environment, next) =
            let
              val (valueCode, nextValue) = gen (value, environment, next)
              val (bodyCode, nextBody) =
                gen (body, (name, nextValue) :: environment, nextValue + 1)
            in
              (valueCode @ [u8 4] @ word32 nextValue @ bodyCode, nextBody)
            end
        | gen (EIf (condition, whenTrue, whenFalse), environment, next) =
            let
              val (conditionCode, nextCondition) = gen (condition, environment, next)
              val (trueCode, nextTrue) = gen (whenTrue, environment, nextCondition)
              val (falseCode, nextFalse) = gen (whenFalse, environment, nextTrue)
              val falseOffset = 5 + length conditionCode + 5 + length trueCode + 5
              val endOffset = falseOffset + length falseCode
            in
              (conditionCode @ [u8 15] @ word32 falseOffset
               @ trueCode @ [u8 16] @ word32 endOffset @ falseCode, nextFalse)
            end
      val (body, _) = gen (expression, [], 0)
    in
      Word8Vector.fromList
        ([u8 82, u8 85, u8 78, u8 69, u8 1] @ body @ [u8 0])
    end
end
