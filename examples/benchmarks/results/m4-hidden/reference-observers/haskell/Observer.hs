module Main where
import Numbers
import Vectors
import Hide
import EdgePlate
import Geometric
import Postscript
import NofibUtils
import GHC.Float(castFloatToWord32)
import System.Environment
word(Tolerant x)=show(castFloatToWord32 x)
point v=unwords(map word[x v,y v,z v])
edge e=point(s e)++" "++point(t e)
main=do
 [file,out]<-getArgs
 input<-readFile file
 let object=map read(lines input)
 let view=vec[2,10,3]
 let rotated=rot view object
 let(base,factor)=getExtremes(concat rotated)
 let raw=hideObj(makeObject rotated)
 let result=scale factor base raw
 let text=draw result
 if text/=hiddenline view object then error "observer pipeline differs"else return()
 writeFile(out++".ps")text
 writeFile(out++".edges")(unlines(map edge result))
 writeFile(out++".raw-edges")(unlines(map edge raw))
 writeFile(out++".rotated")(unlines(map point(concat rotated)))
 putStrLn(unwords["result",show(length result),show(length text),show(hash text)] )
 putStrLn("scale "++point base++" "++word factor)
