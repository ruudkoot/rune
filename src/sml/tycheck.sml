(* Type checking is deliberately separate from bytecode emission so malformed
 * or ill-typed trees cannot reach the bytecode writer. *)
signature RUNE_TYCHECK =
sig
  datatype ty = TInt | TBool
  val check : RuneAst.expr -> ty
end

structure RuneTycheck : RUNE_TYCHECK =
struct
  open RuneAst
  datatype ty = TInt | TBool

  fun sameType (TInt, TInt) = true
    | sameType (TBool, TBool) = true
    | sameType _ = false

  fun typeName TInt = "int"
    | typeName TBool = "bool"

  fun check expression =
    let
      fun lookup name [] = raise Fail ("unbound variable: " ^ name)
        | lookup name ((boundName, ty) :: rest) =
            if name = boundName then ty else lookup name rest
      fun infer (EInt _, _) = TInt
        | infer (EBool _, _) = TBool
        | infer (EVar name, environment) = lookup name environment
        | infer (EBin (operator, left, right), environment) =
            let
              val leftType = infer (left, environment)
              val rightType = infer (right, environment)
              fun requireIntegers () =
                if sameType (leftType, TInt) andalso sameType (rightType, TInt)
                then ()
                else raise Fail "arithmetic operands must be int"
            in
              case operator of
                  Add => (requireIntegers (); TInt)
                | Sub => (requireIntegers (); TInt)
                | Mul => (requireIntegers (); TInt)
                | Div => (requireIntegers (); TInt)
                | Eq =>
                    if sameType (leftType, rightType) then TBool
                    else raise Fail "equality operands must have the same type"
                | Ne =>
                    if sameType (leftType, rightType) then TBool
                    else raise Fail "inequality operands must have the same type"
                | Lt => (requireIntegers (); TBool)
                | Le => (requireIntegers (); TBool)
                | Gt => (requireIntegers (); TBool)
                | Ge => (requireIntegers (); TBool)
            end
        | infer (EIf (condition, whenTrue, whenFalse), environment) =
            let
              val conditionType = infer (condition, environment)
              val trueType = infer (whenTrue, environment)
              val falseType = infer (whenFalse, environment)
            in
              if not (sameType (conditionType, TBool)) then
                raise Fail "if condition must be bool"
              else if not (sameType (trueType, falseType)) then
                raise Fail ("if branches must have the same type ("
                            ^ typeName trueType ^ " and " ^ typeName falseType ^ ")")
              else trueType
            end
        | infer (ELet (name, value, body), environment) =
            let
              val valueType = infer (value, environment)
            in
              infer (body, (name, valueType) :: environment)
            end
        | infer (ESeq (first, second), environment) =
            (infer (first, environment); infer (second, environment))
    in
      infer (expression, [])
    end
end
