module Main where
import System.Random
import Data.List
import System.Environment
steps g=let(x,g')=next g in (x,show g'):steps g'
permutation seed=take 100(nubBy (\a b->fst a==fst b) (zip (randomRs (1::Integer,100) (mkStdGen seed)) [1::Int ..]))
demand seed k=let xs=permutation seed
                  best=maximum(map fst(take k xs))
                  after=dropWhile((<best).fst)(drop k xs)
              in case after of []->(k,False,snd(last xs),snd(last xs))
                               ((v,p):_)->(k,v==100,p,snd(last xs))
main=do
 [mode]<-getArgs
 mapM_ (\seed->case mode of
    "rng"->print(seed,take 10(steps(mkStdGen seed)))
    "permutation"->print(seed,permutation seed)
    "demand"->print(seed,[demand seed k|k<-[35..39]])) [1,2,42,50,5000,50000]
