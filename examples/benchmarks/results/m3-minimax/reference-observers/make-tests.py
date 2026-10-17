from pathlib import Path
p=Path(__file__).resolve().parent
p.joinpath('data').mkdir(exist_ok=True)
for name in ['game.txt','cases.stdout']:(p/'data'/name).write_bytes((p/name).read_bytes())
(p/'data/wrong.txt').write_text((p/'game.txt').read_text().replace('XWin','OWin',1))
text=''
for mode,policy in [('Need','BenchNeed'),('Strict','BenchStrict')]:
 text+='structure '+mode+'Minimax=BenchMinimaxFn('+policy+')\nstructure '+mode+'Driver=BenchMinimaxDriverFn('+mode+'Minimax)\n'
 text+='structure '+mode+'Tests =\nstruct\n  structure K='+mode+'Minimax\n  structure Driver='+mode+'Driver\n  structure D='+policy+'\n  val mode="'+mode+'"\n'
 text+=r'''
  fun read path=let val input=TextIO.openIn path val value=TextIO.inputAll input val _=TextIO.closeIn input in value end
  fun board text=K.board(List.tabulate(3,fn i=>List.tabulate(3,fn j=>
    case String.sub(text,3*i+j)of #"X"=>K.X| #"O"=>K.O|_=>K.Empty)))
  fun check line=case String.tokens(fn c=>c= #":")line of [input,static,max,min]=>
    (T.check("minimax/"^mode^"/static/"^input,fn()=>K.showEvaluation(K.static(board input))=static);
     T.check("minimax/"^mode^"/max/"^input,fn()=>K.showEvaluation(K.bestMove K.X K.maximum K.minimum(board input))=max);
     T.check("minimax/"^mode^"/min/"^input,fn()=>K.showEvaluation(K.bestMove K.O K.minimum K.maximum(board input))=min))
    |_=>raise Fail "invalid minimax fixture"
  val _=List.app check(String.tokens(fn c=>c= #"\n")(read "cases.stdout"))
  val _=T.check("minimax/"^mode^"/source-invalid-six-row-branch",fn()=>
    ((K.prog "doesn't happen";false)handle Match=>true))
  val _=T.check("minimax/"^mode^"/complete-game",fn()=>K.prog "1"=read "game.txt")
  val _=T.check("minimax/"^mode^"/other-decimal-input",fn()=>K.prog "250"=read "game.txt")
  val _=T.check("minimax/"^mode^"/driver-zero",fn()=>Driver.run["0","game.txt"]="0:0")
  val _=T.check("minimax/"^mode^"/driver-one",fn()=>Driver.run["1","game.txt"]="1:194")
  val _=T.check("minimax/"^mode^"/driver-repeat",fn()=>Driver.run["2","game.txt"]="2:388")
  val _=T.check("minimax/"^mode^"/wrong-game-rejected",fn()=>
    ((Driver.run["1","wrong.txt"];false)handle Fail _=>true))
  val _=T.check("minimax/"^mode^"/occupied-square",fn()=>
    case D.force(K.place K.O(K.testBoard())(1,2))of K.Nil=>true|_=>false)
  val _=T.check("minimax/"^mode^"/row-major-move-order",fn()=>
    K.foldl(fn(b,values)=>values@[K.showEvaluation(K.static b)])[](K.newPositions K.X(K.testBoard()))=
    ["Score 5","Score 5","Score 4","Score 4","Score 5","Score 4","Score 5"])
  val _=T.check("minimax/"^mode^"/first-board-on-score-tie",fn()=>
    let val a=K.testBoard()val b=K.initial()
        val(selected,e)=K.best K.maximum(K.ofList[a,b])(K.ofList[K.Score 1,K.Score 1])
    in K.showBoard selected=K.showBoard a andalso e=K.Score 1 end)
  val _=T.check("minimax/"^mode^"/custom-player-best",fn()=>
    let val a=K.testBoard()val b=K.initial()
        fun first x _=x
        val(one,_)=K.best first(K.ofList[a,b])(K.ofList[K.Score 1,K.Score 2])
        val(two,_)=K.best first(K.ofList[a,b])(K.ofList[K.Score 2,K.Score 1])
    in K.showBoard one=K.showBoard a andalso K.showBoard two=K.showBoard a end)
  val _=T.check("minimax/"^mode^"/custom-player-recursive-fold",fn()=>
    let val fcalls=ref 0 val gcalls=ref 0
        fun f x _=(fcalls:= !fcalls+1;x)
        fun g _ y=(gcalls:= !gcalls+1;D.force y)
        fun leaf n=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score n),K.empty()))
        val tree=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score 99),K.ofList[leaf 1,leaf 2]))
        val result=K.mise f g tree
    in result=K.Score 1 andalso !fcalls=(if mode="Need"then 1 else 2)
       andalso !gcalls=(if mode="Need"then 0 else 1)end)
  val _=T.check("minimax/"^mode^"/prune-boundary",fn()=>
    let val calls=ref 0
        fun expand n=(calls:= !calls+1;if n<3 then K.ofList[n+1]else K.empty())
        val tree=K.prune 0(K.repeatTree expand expand 0)
        val K.Branch(a,children)=D.force tree
    in D.force a=0 andalso (case D.force children of K.Nil=>true|_=>false)
       andalso !calls=EXPECTED_CALLS end)
'''
 text=text.replace('EXPECTED_CALLS','0'if mode=='Need'else'4')
 text+='end\n'
text+=r'''
structure MinimaxDemand =
struct
  structure K=NeedMinimax
  structure D=BenchNeed
  val _=T.check("minimax/lazy-max-win-skips-tail",fn()=>
    K.maximum K.XWin(D.delay(fn()=>raise Fail "unused score"))=K.XWin)
  val _=T.check("minimax/lazy-min-win-skips-tail",fn()=>
    K.minimum K.OWin(D.delay(fn()=>raise Fail "unused score"))=K.OWin)
  val _=T.check("minimax/lazy-crop-win-skips-child-head",fn()=>
    let val children=D.delay(fn()=>K.Cons(D.delay(fn()=>raise Fail "unused child"),K.empty()))
        val tree=D.delay(fn()=>K.Branch(D.delay(fn()=>K.XWin),children))
        val K.Branch(a,result)=D.force(K.cropTree tree)
    in D.force a=K.XWin andalso(case D.force result of K.Nil=>true|_=>false)end)
  val _=T.check("minimax/strict-score-construction-demands-tail",fn()=>
    ((StrictMinimax.maximum StrictMinimax.XWin(BenchStrict.delay(fn()=>raise Fail "eager score"));false)handle Fail _=>true))
end
'''
(p/'tests.sml').write_text(text)
root=Path.cwd();files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml',str(p/'kernel.sml'),str(p/'driver.sml'),str(p/'tests.sml'),'tests/basis/finish.sml']
(p/'test-sources.txt').write_text(''.join(str(root/f)+'\n'for f in files));(p/'test-data.txt').write_text('game.txt\ncases.stdout\nwrong.txt\n')
