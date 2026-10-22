(* libraries: test/unit random compiler *)
structure CompilerSyntaxTests =
struct
  structure S=RuneCompiler.Syntax
  val check=Expect.that
  fun parse text=S.parse {file="edit.sml",text=text,mode="unicode",orPatterns=true,fixity=S.initial}
  fun lossless snapshot=String.concat (List.map #text (S.pieces snapshot))=S.text snapshot
  fun same (left,right)=S.text left=S.text right andalso S.events left=S.events right
    andalso S.pieces left=S.pieces right andalso S.diagnostics left=S.diagnostics right
  fun examples () =
    let val inputs=["", "\239\187\191(* nested (* \206\187 *) comment *)\r\nval x=1\n",
          "val x=\"a\\\n \\b\"\nval y = #\"x\"\n",
          "val x=\"bad\\q\"\nval later=42\n", "(* unterminated (*\nval hidden=1\n",
          "val =\nval later=42\n", "structure S=struct val = val good=1 end\nval later=2\n"]
        val snapshots=List.map parse inputs
        val ()=check ("every input byte is retained",List.all lossless snapshots)
        val ()=check ("valid comments/gaps parse",List.all (null o S.diagnostics) (List.take (snapshots,3)))
        val ()=check ("bad lexemes and syntax have diagnostics",List.all (not o null o S.diagnostics) (List.drop (snapshots,3)))
        val unterminated=List.nth (snapshots,4)
        val ()=check ("comment contents do not become declarations",null (S.events unterminated))
    in check ("later declaration survives recovery",List.exists (fn event:S.event =>
      #kind event="PVar" andalso List.exists (fn value => value="later") (#values event)) (S.events (List.nth (snapshots,5)))) end
  fun reuse () =
    let val original=parse "val x=1\nval y=x+2\nval z=y+3\n"
        val updated=S.edit (original,{start=6,stop=7,text="100",fixity=S.initial})
        val ()=check ("incremental equals fresh with shifted suffix",same (updated,parse (S.text updated)))
        val ()=check ("unchanged declarations reused",#reusedDeclarations (S.work updated)>=1)
        val ()=check ("unchanged token suffix reused",#reusedTokens (S.work updated)>=5)
        val ()=check ("old snapshot retained",S.text original="val x=1\nval y=x+2\nval z=y+3\n")
        val joined=S.edit (original,{start=8,stop=13,text="",fixity=S.initial})
        val ()=check ("declaration-boundary edit matches fresh",same (joined,parse (S.text joined)))
        val nested=parse "structure S=struct val x=1 val y=x+2 val z=y+3 end\n"
        val nestedEdit=S.edit (nested,{start=25,stop=26,text="100",fixity=S.initial})
        val ()=check ("nested declaration edit equals fresh",same (nestedEdit,parse (S.text nestedEdit)))
    in check ("nested declarations reuse",#reusedDeclarations (S.work nestedEdit)>=1) end
  fun fixities () =
    let val left=parse "infix 5 ++\n"
        val right=parse "infixr 5 ++\n"
        fun following fixity=S.parse {file="following.sml",text="val x=1 ++ 2 ++ 3\n",mode="ascii",orPatterns=false,fixity=fixity}
        val first=following (S.fixities left)
        val changed=S.edit (first,{start=0,stop=0,text="",fixity=S.fixities right})
        val ()=check ("cross-file fixity invalidates syntax",S.events first<>S.events changed)
        val ()=check ("cross-file fixity matches fresh",S.events changed=S.events (following (S.fixities right)))
        val ()=check ("fixity affected declaration reparsed",#parsedDeclarations (S.work changed)=1)
        val scoped=parse "local infixr 5 ++ in val a=1 ++ 2 ++ 3 end\nval b=op ++\n"
    in check ("local fixity scope remains valid",null (S.diagnostics scoped)) end
  fun edits () =
    let val seed=ref 19
        fun pick n=(seed:=(!seed*109+89) mod 32749; !seed mod n)
        val alphabet=["val ","x","=","1","\n","(*","*)","\"","\\",";","struct ","end ","infixr 5 ++ "," "]
        fun loop (0,snapshot)=check ("final random edit lossless",lossless snapshot)
          | loop (n,snapshot)=
            let val text=S.text snapshot
                val start=pick (size text+1)
                val stop=start+pick (size text-start+1)
                val replacement=List.nth (alphabet,pick (length alphabet))
                val next=S.edit (snapshot,{start=start,stop=stop,text=replacement,fixity=S.initial})
                val expected=String.substring (text,0,start) ^ replacement ^ String.extract (text,stop,NONE)
                val ()=check ("independent text edit",S.text next=expected)
                val ()=check ("random incremental/fresh syntax",same (next,parse expected))
            in loop (n-1,next) end
    in loop (400,parse "val x=1\nval y=2\n") end
end
structure CompilerSyntaxTestMain=Main (struct
  val name="compiler-syntax"
  val tests=Test.describe "compiler-syntax"
    [Test.it "lossless-and-recovery" CompilerSyntaxTests.examples,
     Test.it "reuse-and-boundaries" CompilerSyntaxTests.reuse,
     Test.it "fixities" CompilerSyntaxTests.fixities,
     Test.it "random-edits" CompilerSyntaxTests.edits]
end)
val ()=CompilerSyntaxTestMain.main ()
