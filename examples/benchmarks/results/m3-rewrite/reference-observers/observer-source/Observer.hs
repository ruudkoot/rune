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
 mapM_ (\s->putStrLn(s++" -> "++render(R.simplify(R.super_reduce R.group_completion)(R.parse s)))) terms
terms=["E","a","I(a)","E*a","a*E","I(I(a))","I(a)*a","a*I(a)","(a*b)*c","I(a*b)","I((a*b)*c)","a*(I(a)*b)","I(a)*(a*b)","I(I(a*b))","I(E)","I(a)*(a*(b*I(b)))"]
