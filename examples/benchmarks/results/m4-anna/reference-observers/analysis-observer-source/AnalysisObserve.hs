module AnalysisObserve where
import BaseDefs
import Parser2
import LambdaLift5
import TypeCheck5
import EtaAbstract
import TExpr2DExpr
import DomainExpr
import ReadTable
import StrictAn6
import qualified Main as A
import qualified DomainObserver as O
import Data.List(intercalate)
info(SAResult n d r)="R("++intercalate ","[show n,show d,O.r r]++")"
info(SASearch m n size count)="S("++intercalate ","[case m of Safe->"s";Live->"l",show n,show size,show count]++")"
info(SASizes n used unused)="Z("++intercalate ","[show n,show used,show unused]++")"
info(SAHExpr _ _) = error"unexpected show expression"
info(SAGiveUp ns)="G"++show ns
run table contents=
 let (dar,(tds,expr))=paParse contents
     (lifted,params)=llMain(map fst A.maBaseAnns)expr True
     (_,checked)=tcCheck A.maBaseTypes([1],[0])(tds,lifted)
     Ok(tree,environment)=checked
     darAug=(False,["bool"]):dar
     definitions=("bool",[],[("True",[]),("False",[])]):tds
     deScheme(Scheme _ e)=e
     env=environment++map(\(n,s)->(n,deScheme s))A.maBaseTypes
     simple=map(\(n,t)->(n,tx2dx darAug t))env
     domains=map(\(n,d)->(n,dxApplyDSubst_2 d))simple
     statics=(simple,domains,saMkCargs definitions,params,bdDefaultSettings,(10000,10000,0,1000000,20),table)
     groups=saMkGroups(tx2dxAnnTree darAug(eaEtaAbstract tree))
 in unlines(map info(saUndoCAFkludge(saGroups statics A.maBaseAnns groups)))
main=do
 table<-fmap rtReadTable(readFile"../source/runtime_files/anna_table")
 mapM_(\(profile,file)->do
   contents<-readFile("../source/"++file)
   let result=run table contents
   writeFile("../analysis-"++profile++".reference")result
   print(profile,length result))
  [("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
