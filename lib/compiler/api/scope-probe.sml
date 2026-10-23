(* Bounded syntax probes for an unfinished cursor position. These texts are
   private to a scope query: neither their types nor their diagnostics are
   published as facts about the original source. The compiler still supplies
   every binding; a probe never constructs an environment itself. *)
structure CompilerScopeProbe =
struct
  val marker="runeCompletionHole"
  fun texts {file,text,mode,offset} =
    if offset<0 orelse offset>size text then [] else
    let val prefix=String.substring (text,0,offset)
        val suffix=String.extract (text,offset,NONE)
        val (lexemes,_,_)=CompilerSyntax.lexical
          {file=file,text=prefix,mode=mode,previous=NONE,change=NONE}
        fun one ((_,item:CompilerSyntax.lexeme),stack) = case #token item of
            SOME Token.LET => "end"::stack | SOME Token.LOCAL => "end"::stack
          | SOME Token.STRUCT => "end"::stack | SOME Token.SIG => "end"::stack
          | SOME Token.LPAREN => ")"::stack | SOME Token.LBRACKET => "]"::stack
          | SOME Token.LBRACE => "}"::stack
          | SOME Token.END => pop ("end",stack) | SOME Token.RPAREN => pop (")",stack)
          | SOME Token.RBRACKET => pop ("]",stack) | SOME Token.RBRACE => pop ("}",stack)
          | _ => stack
        and pop (closing,first::rest)=if closing=first then rest else first::rest
          | pop (_,[])=[]
        val stack=Vector.foldl one [] lexemes
        val closing=if suffix="" andalso length stack<=128 then " " ^ String.concatWith " " stack else ""
        val direct=prefix ^ marker ^ suffix ^ closing
        val declaration=prefix ^ "\nval _ = " ^ marker ^ suffix ^ closing
    in if length stack>128 then [] else
       [(direct,offset),(declaration,offset+9)] end
end
