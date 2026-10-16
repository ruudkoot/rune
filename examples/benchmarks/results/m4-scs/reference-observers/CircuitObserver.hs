module Main where
import Parse
import Types
import Data.Ratio
import System.Environment
rat x=show(numerator x)++" "++show(denominator x)
pair(t,v)=rat(toRational t)++" "++rat(toRational v)
element e=case e of
 Conductor x->"g "++rat x
 Resistor x->"r "++rat x
 Capacitor(c,q)->"c "++rat c++" "++rat q
 Inductor(l,f)->"l "++rat l++" "++rat f
 Vsource xs->"v "++show(length xs)++" "++unwords(map pair xs)
 Isource xs->"i "++show(length xs)++" "++unwords(map pair xs)
 Junction(c,r,q)->"j "++rat c++" "++rat r++" "++rat q
main=do
 [path]<-getArgs
 text<-readFile path
 let [(circuit,names)]=parse_circuit text
 print names
 mapM_ (\(i,p,m,e)->putStrLn(unwords[show i,show p,show m,element e])) circuit
