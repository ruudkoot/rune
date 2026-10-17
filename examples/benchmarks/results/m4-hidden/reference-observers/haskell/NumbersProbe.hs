module Main where
import Numbers
import Vectors
import GHC.Float(castFloatToWord32)
samples :: [(String,Number,Number)]
samples=[("zero-zero",read "0",read "0"),("eps-zero",read "0.0001",read "0"),("zero-eps",read "0",read "0.0001"),("minus-eps-zero",read "-0.0001",read "0"),("below-eps",read "0.00009999",read "0")]
word(Tolerant x)=show(castFloatToWord32 x)
emit(name,a,b)=putStrLn(unwords[name,word a,word b,show(a==b),show(a/=b),show(a<b),show(a<=b),show(a>b),show(a>=b),show(compare a b),show(vec[a,0,0]==vec[b,0,0]),show(vec[a,0,0]/=vec[b,0,0])])
main=mapM_ emit samples
