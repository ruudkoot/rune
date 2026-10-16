module Main where
import Kernel ()
import Parse
import Type
import Environment
import InferMonad
import Substitution
main=do
 print (useP False (lexactlyP (starP alphaP `thenP` (\_ -> litP 'a' `eachP` (const True)))) "a")
 let s1=extendSub emptySub "x" (TVar "y")
 let s2=extendSub s1 "y" (TCon "List" [TVar "z"])
 let s3=extendSub s2 "x" (TVar "w")
 print [(x,show(lookupSub s3 x)) | x<-domSub s3]
 let env=extendLocal (makeEnv [("x",All [] (TVar "a"))]) "x" (TVar "b")
 print (freeTVarEnv env)
