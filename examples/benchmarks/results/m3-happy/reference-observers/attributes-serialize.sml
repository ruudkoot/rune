  fun jsonText value=jsonQuote(X.string value)
  fun jsonTag name fields=jsonArray(jsonQuote name::fields)
  fun jsonToken token=case token of LBrace=>jsonTag"{"[]|RBrace=>jsonTag"}"[]
    |Where=>jsonTag"where"[]|Semicolon=>jsonTag";"[]|Eq=>jsonTag"="[]
    |SelfRef s=>jsonTag"self"[jsonText s]
    |SubRef(n,s)=>jsonTag"sub"[Int.toString(D.force n),jsonText s]
    |RightRef s=>jsonTag"right"[jsonText s]
    |Unknown s=>jsonTag"unknown"[jsonText s]|EOF=>jsonTag"eof"[]
  fun jsonTokens tokens=jsonArray(List.map jsonToken(F.toList tokens))
  fun jsonRule rule=case rule of
     SelfAssign(s,ts)=>jsonTag"SelfAssign"[jsonText s,jsonTokens ts]
    |SubAssign((n,s),ts)=>jsonTag"SubAssign"[Int.toString(D.force n),jsonText s,jsonTokens ts]
    |RightmostAssign(s,ts)=>jsonTag"RightmostAssign"[jsonText s,jsonTokens ts]
    |Conditional ts=>jsonTag"Conditional"[jsonTokens ts]
  fun lexAll chars line=
    let fun loop reversed chars=
          case uncons chars of NONE=>X.Ok(F.fromList(List.rev reversed))
           |_=>lexer(fn token=>fn rest=>fn nextLine=>loop(token::reversed)rest)chars line
    in loop[]chars end
  fun json mode input=
    if mode="tokens"then
      (case lexAll(X.text input)0 of X.Ok values=>jsonTokens values
       |X.Failed message=>jsonTag"error"[jsonText message])
    else(case parse(X.text input)0 of X.Ok values=>jsonArray(List.map jsonRule(F.toList values))
       |X.Failed message=>jsonTag"error"[jsonText message])
