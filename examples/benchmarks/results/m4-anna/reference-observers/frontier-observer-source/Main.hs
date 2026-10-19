module Main where
import BaseDefs
import AbstractVals2
import AbstractMisc
import FrontierDATAFN2
import qualified DomainObserver as O
import Data.List(intercalate)
cases=[(Func[d]d,HLam["x"](HVar"x"))|d<-[Two,Lift1[Two],Lift2[Two],Lift1[Two,Two]]]
 ++[(Func[d,d]d,HLam["x","y"](HMeet[HVar"x",HVar"y"]))|d<-[Two,Lift1[Two],Lift2[Two]]]
main=mapM_ run[(mode,naive,d,e)|mode<-[Safe,Live],naive<-[False,True],(d,e)<-cases]
 where run(mode,naive,d@(Func args _),e)=do
        let Rep low=avBottomR d
            Rep high=avTopR d
            (rep,memo)=fdFind mode e d args args (fsBounds high low) id naive (error"unused") []
        putStrLn(O.pair(O.rep rep)(O.list(\(args,result)->O.pair(O.list O.r args)(O.r result))memo))
       fsBounds(RepTwo(Min1Max0 n _ z))(RepTwo(Min1Max0 _ o _))=RepTwo(Min1Max0 n o z)
       fsBounds(Rep1 a xs)(Rep1 b ys)=Rep1(bound a b)(zipWith fsBounds xs ys)
       fsBounds(Rep2 a b xs)(Rep2 c d ys)=Rep2(bound a c)(bound b d)(zipWith fsBounds xs ys)
       bound(Min1Max0 n _ z)(Min1Max0 _ o _)=Min1Max0 n o z
