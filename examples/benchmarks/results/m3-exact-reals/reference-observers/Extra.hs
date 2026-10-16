module Main where
import Kernel
import Control.Monad
samples :: [(String,CR)]
samples=[("pi",pi),("third",1/3),("negative-third",-1/3),("sqrt-half",sqrt(1/2)),("sin-quarter",sin(pi/4)),("cos-quarter",cos(pi/4)),("sin-negative-quarter",sin(-pi/4)),("atan-minus-five",atan(-5)),("atan-minus-one",atan(-1)),("atan-minus-half",atan(-1/2)),("atan-zero",atan 0),("atan-fifth",atan(1/5)),("atan-one",atan 1),("atan-five",atan 5)]
emit (name,value)=do
 forM_ [0,1,2,8,32,137] $ emitBits name value
 putStrLn(name++" text "++get_str 40 value)
emitBits name value p=putStrLn(name++" bits "++show p++" "++show(bits p value))
main=mapM_ emit samples
