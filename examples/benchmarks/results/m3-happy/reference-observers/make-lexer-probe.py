from pathlib import Path
import json,subprocess
p=Path(__file__).resolve().parent
text=r'''fun quote s=
 let fun esc #"\""="\\\""|esc #"\\"="\\\\"|esc c=
       if Char.ord c<32 then
         let val h=String.map Char.toLower(Int.fmt StringCvt.HEX(Char.ord c))
         in "\\u"^String.implode(List.tabulate(4-String.size h,fn _=> #"0"))^h end
       else String.str c
 in "\""^String.translate esc s^"\""end
fun array xs="["^String.concatWith","xs^"]"
fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
functor HappyLexerProbeFn(structure D:BENCH_SUSPEND val label:string)=
struct
 structure X=BenchHappyLexerFn(D)
 fun rank id=case id of X.Id=>0|X.TokenType=>1|X.TokenSpec=>2|X.Name=>3|X.Partial=>4|X.Lexer=>5
   |X.ImportedIdentity=>6|X.Monad=>7|X.Nonassoc=>8|X.Left=>9|X.Right=>10|X.Prec=>11|X.Expect=>12
   |X.Error=>13|X.AttributeType=>14|X.Attribute=>15|X.Code=>16|X.Colon=>17|X.SemiColon=>18
   |X.DoubleColon=>19|X.DoublePercent=>20|X.Bar=>21|X.Number=>22
 fun emit(token,line)=array(case token of
    X.Info(s,id)=>[quote"I",Int.toString(rank(D.force id)),quote(X.string s),Int.toString line]
   |X.Num(n,id)=>[quote"N",Int.toString(rank(D.force id)),Int.toString(D.force n),Int.toString line]
   |X.KW id=>[quote"K",Int.toString(rank(D.force id)),Int.toString line]
   |X.EOF=>[quote"E",Int.toString line])
 fun collect chars line=X.lexer(fn token=>fn rest=>fn at=>
   case token of X.EOF=>X.return[(token,at)]rest at
    |_=>X.fmap(fn tail=>(token,at)::tail)collect rest at)chars line
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/lexer-data/"
       val result=case collect(X.input(read(root^name^".input")))1 of
          X.Ok tokens=>array(List.map emit tokens)
         |X.Failed message=>array[quote"error",quote(X.string message)]
       val expected=read(root^name^".reference")
       val _=if result^"\n"=expected then print("PASS "^label^" "^name^"\n")
         else let val f=TextIO.openOut(root^name^"-"^label^".actual")
              in TextIO.output(f,result^"\n");TextIO.closeOut f;raise Fail("lexer mismatch "^label^" "^name)end
   in()end
 val _=List.app one CASES
end
structure NeedProbe=HappyLexerProbeFn(structure D=BenchNeed val label="need")
structure StrictProbe=HappyLexerProbeFn(structure D=BenchStrict val label="strict")
'''
cases=json.loads((p/'lexer-cases.json').read_text())
text=text.replace('CASES','['+','.join(json.dumps(name)for name in cases)+']')
(p/'lexer-probe.sml').write_text(text)
root=Path.cwd()
files=[root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/suspend.sml',root/'examples/benchmarks/shared/hartel-ida-finite.sml',p/'lexer.sml',p/'lexer-probe.sml']
with(p/'lexer-probe-build.log').open('w')as log:subprocess.run(['bin/rune',*map(str,files),'-o',str(p/'lexer-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'lexer-probe.log').open('w')as log:subprocess.run(['bin/runevm',str(p/'lexer-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print((p/'lexer-probe.log').read_text())
