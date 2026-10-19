module States where
import Progfuns
import Tilefuns
import NofibUtils(hash)
import System.Environment(getArgs)
main=do
 [path,prefix]<-getArgs
 text<-readFile path
 let rows=walk([],1,initalist)(lines text)
 writeFile(prefix++".states")(unlines(map show rows))
 print(length rows)
walk state input
 | tilequit state input=[]
 | otherwise=(hash output,next):walk next rest
 where (output,next,rest)=tiletrans state input
