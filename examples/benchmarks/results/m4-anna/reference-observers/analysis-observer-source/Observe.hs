module Observe where
import BaseDefs
import Parser2
import ReadTable
import MakeDomains
import Dependancy
import LambdaLift5
import qualified Main as AnnaMain
import TypeCheck5
import EtaAbstract
import Data.List(intercalate)
list f xs="["++intercalate ","(map f xs)++"]"
pair a b="("++a++","++b++")"
te(TDefVar n)="V"++show n
te(TDefCons n args)="C"++pair(show n)(list te args)
td(n,vars,cs)="("++intercalate ","[show n,show vars,list(\(c,args)->pair(show c)(list te args))cs]++")"
expr(EVar n)="V"++show n
expr(ENum n)="N"++show n
expr(EConstr n)="C"++show n
expr(EAp a b)="A"++pair(expr a)(expr b)
expr(ELet r bs e)="L("++intercalate ","[show r,list(\(n,e)->pair(show n)(expr e))bs,expr e]++")"
expr(ECase e as)="K"++pair(expr e)(list(\(n,(args,e))->pair(show n)(pair(show args)(expr e)))as)
expr(ELam args e)="F"++pair(show args)(expr e)
program(tds,defs)=pair(list td tds)(list(\(n,(args,e))->pair(show n)(pair(show args)(expr e)))defs)
ti(TVar n)="V"++show n
ti(TArr a b)="A"++pair(ti a)(ti b)
ti(TCons n args)="C"++pair(show n)(list ti args)
ann(t,node)=pair(ti t)(an node)
an(AVar n)="V"++show n
an(ANum n)="N"++show n
an(AConstr n)="C"++show n
an(AAp a b)="A"++pair(ann a)(ann b)
an(ALet r bs e)="L("++intercalate ","[show r,list(\(n,e)->pair(show n)(ann e))bs,ann e]++")"
an(ACase e as)="K"++pair(ann e)(list(\(n,(args,e))->pair(show n)(pair(show args)(ann e)))as)
an(ALam args e)="F"++pair(show args)(ann e)
main=do
 mapM_(\(name,file)->do
   contents<-readFile("../source/"++file)
   let result=program(paSyntax(paLex 1 contents))
   writeFile("../parsed-"++name++".reference")result
   let (tds,defs)=paSyntax(paLex 1 contents)
   writeFile("../dependency-"++name++".reference")(show(mdTypeDependancy tds))
   let (_,(_,atomic))=paParse contents
   let depended=deDependancy atomic
   let merged=llMergeLams depended
   let named=llName merged
   let builtins=filter((=='_').head)(map fst AnnaMain.maBaseAnns)
   let unique=snd(llUnique 0(map(\n->(tail n,n))builtins)named)
   mapM_(\(stage,e)->writeFile("../lift-"++stage++"-"++name++".reference")(expr e))
     [("dependency",depended),("merged",merged),("named",named),("unique",unique)]
   mapM_(\(mode,pretty)->do
       let(e,parameters)=llMain(map fst AnnaMain.maBaseAnns)atomic pretty
       writeFile("../lift-final-"++mode++"-"++name++".reference")(pair(expr e)(show parameters)))
     [("pretty",True),("raw",False)]
   let (tds,_)=paSyntax(paLex 1 contents)
   let(e,_)=llMain(map fst AnnaMain.maBaseAnns)atomic True
   let(words,checked)=tcCheck AnnaMain.maBaseTypes([1],[0])(tds,e)
   let Ok(tree,environment)=checked
   writeFile("../types-"++name++".reference")words
   writeFile("../typed-tree-"++name++".reference")(ann tree)
   writeFile("../eta-tree-"++name++".reference")(ann(eaEtaAbstract tree))
   writeFile("../type-environment-"++name++".reference")(list(\(n,t)->pair(show n)(ti t))environment)
   print(name,length result))
  [("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
 table<-readFile"../source/runtime_files/anna_table"
 writeFile"../lattice-table.reference"(show(rtReadTable table))
 print(length(rtReadTable table))
