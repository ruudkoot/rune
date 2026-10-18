module Main where
import WaveSource
import Data.Array
showArray name a=
 let (lo,hi)=bounds a
     (low,high)=bounds(a!lo)
 in do
 putStrLn(unwords["matrix",name,show lo,show hi,show low,show high])
 mapM_ (putStrLn.show) [a!i!j|i<-[lo..hi],j<-[low..high]]
run n=
 let solution@((lu,lv,lh),(ru,rv,rh))=f_solution n
 in do
 putStrLn("steps "++show n)
 putStrLn("sumcode "++f_sumcode(f_output_print solution))
 mapM_ (uncurry showArray)[("lu",lu),("ru",ru),("lv",lv),("rv",rv),("lh",lh),("rh",rh)]
main=mapM_ run [0,1,2,3,8,16,40,80,400]
