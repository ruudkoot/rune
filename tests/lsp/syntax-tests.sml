structure RuneLspSyntaxDifferential =
struct
  val check=Expect.that
  fun read path=let val input=TextIO.openIn path in TextIO.inputAll input before TextIO.closeIn input end
  fun parse (file,text,mode,orPatterns)=CompilerSyntax.parse
    {file=file,text=text,mode=mode,orPatterns=orPatterns,fixity=Fixity.initial}
  fun compare (file,text,mode,orPatterns) = CompilerSession.owned (fn () =>
    let val source=Source.fromStringIn (mode,file,text)
        val ()=Parser.orPatterns:=orPatterns
        val batch=(SOME (Parser.parseFile source),NONE) handle Error.CompileError problem => (NONE,SOME problem)
        val editor=parse (file,text,mode,orPatterns)
        val ()=check (file ^ ": lossless",String.concat (List.map #text (CompilerSyntax.pieces editor))=text)
    in case batch of (SOME program,_) =>
         (check (file ^ ": accepted without recovery",null (CompilerSyntax.problems editor));
          check (file ^ ": constructor/scalar/span structure",SyntaxAst.shape program=SyntaxAst.shape (CompilerSyntax.bridge editor));
          check (file ^ ": topdec boundaries",List.all (fn stop => Parser.endsTopdec {file=file,start=stop,stop=stop}) (CompilerSyntax.ends editor)))
       | (_,SOME expected) => check (file ^ ": compiler rejection represented",List.exists (fn problem => problem=expected) (CompilerSyntax.problems editor))
       | _ => raise Fail "missing batch verdict" end)
  fun corpus () =
    let val stream=OS.FileSys.openDir "tests/lang"
        fun files acc=case OS.FileSys.readDir stream of NONE => acc | SOME name =>
          files (if String.isSuffix ".sml" name then ("tests/lang/" ^ name)::acc else acc)
        val files=files [] before OS.FileSys.closeDir stream
        fun test file=let val text=read file in compare (file,text,Source.Ascii,false);
          compare (file,text,Source.Unicode Source.Utf8,true);
          compare (file,Source.latin1ToUtf8 text,Source.Unicode Source.Latin1,false) end
    in List.app test files end
  fun frontend () = List.app (fn file => compare (file,read file,Source.Ascii,false))
    ["lib/compiler/frontend/parser.sml","lib/compiler/frontend/lexer.sml","lib/compiler/frontend/ast.sml",
     "lib/compiler/syntax/parser.sml","lib/compiler/syntax/incremental.sml"]
  fun mutations () =
    let val original="signature S=sig type t val x:t end\nfunctor F()=struct datatype t=C val x=C end\nstructure A:>S=F()\nval r={x=1,y=2}\n"
        val ()=List.app (fn at => compare ("mutated.sml",String.substring (original,0,at) ^ String.extract (original,at+1,NONE),Source.Ascii,false))
          (List.tabulate (size original,fn i => i))
    in () end
  fun editTraces () = CompilerSession.owned (fn () =>
    let val original="infixr 5 ++\nfun op ++ (a,b)=a+b\n"
          ^ "signature S=sig type t val x:t end\nfunctor F()=struct datatype t=C val x=C end\n"
          ^ "structure A:>S=F()\nlocal infix 6 ++ in val a=1 ++ 2 ++ 3 end\n"
          ^ "structure Nested=struct val r={x=1,y=2} val {x,y}=r fun f n=let val a=n+1 val b=a+2 in b end end\n"
          ^ "val s=\"a\\\n \\b\" (* nested (* comment *) end *)\n"
        val originalTree=parse ("trace.sml",original,Source.Ascii,false)
        val seed=ref 37
        fun pick n=(seed:=(!seed*109+89) mod 32749; !seed mod n)
        val replacements=["","x"," ","(*","*)","\"","\\","end","infixr","8","\n"]
        fun verify tree =
          let val text=CompilerSyntax.text tree
              val fresh=parse ("trace.sml",text,Source.Ascii,false)
              val ()=check ("edit trace: full syntax",SyntaxAst.shape (CompilerSyntax.bridge tree)=SyntaxAst.shape (CompilerSyntax.bridge fresh))
              val ()=check ("edit trace: diagnostics",CompilerSyntax.problems tree=CompilerSyntax.problems fresh)
              val ()=check ("edit trace: topdecs",CompilerSyntax.ends tree=CompilerSyntax.ends fresh)
              val ()=check ("edit trace: lossless pieces",CompilerSyntax.pieces tree=CompilerSyntax.pieces fresh)
              val ()=check ("edit trace: outgoing fixity",StringMap.listItemsi (#table (CompilerSyntax.fixity tree))=
                StringMap.listItemsi (#table (CompilerSyntax.fixity fresh)))
          in compare ("trace.sml",text,Source.Ascii,false) end
        fun loop (0,tree)=verify tree
          | loop (n,tree)=
            let val start=pick (size original+1)
                val stop=Int.min (size original,start+pick 2)
                val replacement=List.nth (replacements,pick (length replacements))
                val updated=CompilerSyntax.edit (tree,{start=start,stop=stop,text=replacement,fixity=Fixity.initial})
                val expected=String.substring (original,0,start) ^ replacement ^ String.extract (original,stop,NONE)
                val ()=check ("edit trace: independent replacement",CompilerSyntax.text updated=expected)
                val ()=verify updated
                val reverted=CompilerSyntax.edit (updated,{start=start,stop=start+size replacement,
                  text=String.substring (original,start,stop-start),fixity=Fixity.initial})
                val ()=verify reverted
            in loop (n-1,reverted) end
    in loop (500,originalTree) end)
end
structure RuneLspSyntaxDifferentialMain=Main (struct
  val name="lsp-syntax-differential"
  val tests=Test.describe "lsp-syntax-differential"
    [Test.it "language-corpus" RuneLspSyntaxDifferential.corpus,
     Test.it "compiler-frontend" RuneLspSyntaxDifferential.frontend,
     Test.it "deletion-mutations" RuneLspSyntaxDifferential.mutations,
     Test.it "randomized-edit-undo" RuneLspSyntaxDifferential.editTraces]
end)
val ()=RuneLspSyntaxDifferentialMain.main ()
