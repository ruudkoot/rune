(* Recursive-descent parser with precedence levels matching the expression
 * grammar: sequencing, comparison, addition, multiplication, and atoms. *)
signature RUNE_PARSER =
sig
  val parse : string -> RuneAst.expr
end

structure RuneParser : RUNE_PARSER =
struct
  open RuneLexer
  open RuneAst

  fun parse source =
    let
      val tokens = ref (lex source)
      fun take () =
        case !tokens of
            [] => raise Fail "unexpected end"
          | token :: rest => (tokens := rest; token)
      fun accept expected =
        case !tokens of
            token :: rest =>
              if token = expected then (tokens := rest; true) else false
          | [] => false
      fun expect token =
        if accept token then () else raise Fail "unexpected token"
      fun atom () =
        case take () of
            TInt n => EInt n
          | TTrue => EBool true
          | TFalse => EBool false
          | TIdent name => EVar name
          | TLParen =>
              let val result = sequence ()
              in expect TRParen; result end
          | TIf =>
              let
                val condition = sequence ()
                val _ = expect TThen
                val whenTrue = sequence ()
                val _ = expect TElse
                val whenFalse = sequence ()
              in
                EIf (condition, whenTrue, whenFalse)
              end
          | TLet =>
              let
                val _ = expect TVal
                val name =
                  case take () of
                      TIdent value => value
                    | _ => raise Fail "expected name"
                val _ = expect TEq
                val value = sequence ()
                val _ = expect TIn
                val body = sequence ()
                val _ = expect TEnd
              in
                ELet (name, value, body)
              end
          | _ => raise Fail "expected expression"
      and product () =
        let
          fun loop left =
            case !tokens of
                TStar :: _ => (take (); loop (EBin (Mul, left, atom ())))
              | TSlash :: _ => (take (); loop (EBin (Div, left, atom ())))
              | _ => left
        in
          loop (atom ())
        end
      and sum () =
        let
          fun loop left =
            case !tokens of
                TPlus :: _ => (take (); loop (EBin (Add, left, product ())))
              | TMinus :: _ => (take (); loop (EBin (Sub, left, product ())))
              | _ => left
        in
          loop (product ())
        end
      and comparison () =
        let
          val left = sum ()
          fun comparisonOperator token =
            case token of
                TEq => SOME Eq
              | TNe => SOME Ne
              | TLt => SOME Lt
              | TLe => SOME Le
              | TGt => SOME Gt
              | TGe => SOME Ge
              | _ => NONE
        in
          case !tokens of
              token :: _ =>
                (case comparisonOperator token of
                    SOME operator => (take (); EBin (operator, left, sum ()))
                  | NONE => left)
            | [] => left
        end
      and sequence () =
        let
          val left = comparison ()
        in
          if accept TSemi then ESeq (left, sequence ()) else left
        end
      val result = sequence ()
    in
      case !tokens of
          [TEOF] => result
        | _ => raise Fail "trailing input"
    end
end
