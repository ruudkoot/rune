module Main where
import qualified Rewrite as R
import Data.List(sortOn)
render (R.Var n)=n
render (R.Func f xs)=f++"("++comma(map render xs)++")"
comma []=""
comma [x]=x
comma(x:xs)=x++","++comma xs
rules(R.Return xs)=xs
rules(R.Switch xs d)=concatMap (rules.snd) xs++rules d
main=do
 mapM_ (\e->putStrLn(show(R.eqno e)++" "++render(R.lhs e)++"="++render(R.rhs e))) (sortOn R.eqno (rules R.group_completion))
 terms<-lines <$> readFile "terms.in"
 mapM_ (\s->putStrLn(s++" -> "++render(R.simplify(R.super_reduce R.group_completion)(R.parse s)))) terms