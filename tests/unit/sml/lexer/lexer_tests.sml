structure RuneLexerTests =
struct
  open RuneLexer

  fun tokenName token =
    case token of
        TInt value => "TInt(" ^ Int.toString value ^ ")"
      | TIdent name => "TIdent(" ^ name ^ ")"
      | TTrue => "TTrue"
      | TFalse => "TFalse"
      | TPlus => "TPlus"
      | TMinus => "TMinus"
      | TStar => "TStar"
      | TSlash => "TSlash"
      | TEq => "TEq"
      | TNe => "TNe"
      | TLt => "TLt"
      | TLe => "TLe"
      | TGt => "TGt"
      | TGe => "TGe"
      | TIf => "TIf"
      | TThen => "TThen"
      | TElse => "TElse"
      | TLet => "TLet"
      | TVal => "TVal"
      | TIn => "TIn"
      | TEnd => "TEnd"
      | TSemi => "TSemi"
      | TLParen => "TLParen"
      | TRParen => "TRParen"
      | TEOF => "TEOF"

  fun tokensName tokens =
    "[" ^ String.concatWith ", " (map tokenName tokens) ^ "]"

  fun failCase category name detail =
    raise Fail (category ^ " lexer case '" ^ name ^ "' failed: " ^ detail)

  fun expectTokens (name, source, expected) =
    let
      val actual = lex source
    in
      if actual = expected then ()
      else failCase "positive" name
             ("source=" ^ source ^ ", expected=" ^ tokensName expected ^
              ", actual=" ^ tokensName actual)
    end

  fun expectReject (name, source) =
    let
      val rejected = (lex source; false) handle Fail _ => true | Overflow => true
    in
      if rejected then ()
      else failCase "negative" name ("source was accepted: " ^ source)
    end

  val positiveCases =
    [
      ("empty", "", [TEOF]),
      ("spaces", "   ", [TEOF]),
      ("all-whitespace", " \t\n\r\f", [TEOF]),
      ("integer-zero", "0", [TInt 0, TEOF]),
      ("integer-leading-zeroes", "000007", [TInt 7, TEOF]),
      ("integer-large", "1000000", [TInt 1000000, TEOF]),
      ("identifier", "alpha", [TIdent "alpha", TEOF]),
      ("underscore-identifier", "_private", [TIdent "_private", TEOF]),
      ("identifier-with-digits", "item42", [TIdent "item42", TEOF]),
      ("identifier-with-many-underscores",
       "__a_b__2", [TIdent "__a_b__2", TEOF]),
      ("keyword-true", "true", [TTrue, TEOF]),
      ("keyword-false", "false", [TFalse, TEOF]),
      ("keyword-if", "if", [TIf, TEOF]),
      ("keyword-then", "then", [TThen, TEOF]),
      ("keyword-else", "else", [TElse, TEOF]),
      ("keyword-let", "let", [TLet, TEOF]),
      ("keyword-val", "val", [TVal, TEOF]),
      ("keyword-in", "in", [TIn, TEOF]),
      ("keyword-end", "end", [TEnd, TEOF]),
      ("keyword-prefix-identifiers",
       "trueValue falsehood iffy then_ else1 letx value_in ending",
       [TIdent "trueValue", TIdent "falsehood", TIdent "iffy",
        TIdent "then_", TIdent "else1", TIdent "letx", TIdent "value_in",
        TIdent "ending", TEOF]),
      ("arithmetic", "+ - * /", [TPlus, TMinus, TStar, TSlash, TEOF]),
      ("comparisons", "= <> < <= > >=", 
       [TEq, TNe, TLt, TLe, TGt, TGe, TEOF]),
      ("delimiters", "; ( )", [TSemi, TLParen, TRParen, TEOF]),
      ("compact-expression", "1+2*3-4/5",
       [TInt 1, TPlus, TInt 2, TStar, TInt 3, TMinus, TInt 4, TSlash,
        TInt 5, TEOF]),
      ("comparison-expression", "left<=right<>other>=third",
       [TIdent "left", TLe, TIdent "right", TNe, TIdent "other", TGe,
        TIdent "third", TEOF]),
      ("nested-delimiters", "((1));(2)",
       [TLParen, TLParen, TInt 1, TRParen, TRParen, TSemi, TLParen,
        TInt 2, TRParen, TEOF]),
      ("if-expression", "if x then true else false",
       [TIf, TIdent "x", TThen, TTrue, TElse, TFalse, TEOF]),
      ("let-expression", "let val answer = 42 in answer end",
       [TLet, TVal, TIdent "answer", TEq, TInt 42, TIn,
        TIdent "answer", TEnd, TEOF]),
      ("sequenced-expression", "x;y;z",
       [TIdent "x", TSemi, TIdent "y", TSemi, TIdent "z", TEOF]),
      ("mixed-whitespace", "\nlet\tval  x\r=\n1\f in x end\n",
       [TLet, TVal, TIdent "x", TEq, TInt 1, TIn, TIdent "x", TEnd, TEOF]),
      ("operators-without-spaces", "1<>2<=3>=4=5<6>7",
       [TInt 1, TNe, TInt 2, TLe, TInt 3, TGe, TInt 4, TEq, TInt 5,
        TLt, TInt 6, TGt, TInt 7, TEOF]),
      ("repeated-arithmetic", "1++--**//2",
       [TInt 1, TPlus, TPlus, TMinus, TMinus, TStar, TStar, TSlash,
        TSlash, TInt 2, TEOF]),
      ("keyword-and-operator-boundaries", "let(val)=if(x<>y)then z else 0",
       [TLet, TLParen, TVal, TRParen, TEq, TIf, TLParen, TIdent "x",
        TNe, TIdent "y", TRParen, TThen, TIdent "z", TElse, TInt 0, TEOF]),
      ("long-identifier",
       "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789",
       [TIdent
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789",
        TEOF]),
      ("large-token-stream",
       "1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 ; a ; b ; c ; d",
       [TInt 1, TPlus, TInt 2, TPlus, TInt 3, TPlus, TInt 4, TPlus,
        TInt 5, TPlus, TInt 6, TPlus, TInt 7, TPlus, TInt 8, TPlus,
        TInt 9, TPlus, TInt 10, TSemi, TIdent "a", TSemi, TIdent "b",
        TSemi, TIdent "c", TSemi, TIdent "d", TEOF])
    ]

  val negativeCases =
    [
      ("at-sign", "@"),
      ("hash", "#"),
      ("dollar", "$"),
      ("percent", "%"),
      ("ampersand", "&"),
      ("single-quote", "'"),
      ("double-quote", "\""),
      ("comma", ","),
      ("dot", "."),
      ("colon", ":"),
      ("question-mark", "?"),
      ("backslash", "\\"),
      ("left-bracket", "["),
      ("right-bracket", "]"),
      ("left-brace", "{"),
      ("right-brace", "}"),
      ("pipe", "|"),
      ("exclamation", "!"),
      ("caret", "^"),
      ("tilde", "~"),
      ("invalid-character-after-token", "1 @ 2"),
      ("invalid-character-between-identifiers", "first.second"),
      ("invalid-character-in-identifier", "valid$name"),
      ("invalid-character-in-number", "12.34"),
      ("integer-overflow", "999999999999999999999999999999999999999999"),
      ("invalid-character-at-end", "let val x = 1 in x end @")
    ]

  val _ = app expectTokens positiveCases
  val _ = app expectReject negativeCases
  val _ = print ("lexer tests: " ^ Int.toString (length positiveCases) ^
                 " positive, " ^ Int.toString (length negativeCases) ^
                 " negative passed\n")
end
