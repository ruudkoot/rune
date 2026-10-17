module Main where
import qualified Program as P
import qualified Recorder as R
import System.Environment
import NofibUtils(hash)
import Data.Word(Word64)
main=do
 [mode,file,out]<-getArgs
 input<-unlines . words <$> readFile file
 R.reset
 if mode=="aux"then P.do_auxfns P.stop P.defaultEnv else P.parse_args P.defaultEnv input
 chunks<-R.collect
 writeFile(out++".chunks")(unlines[show text|(_,text)<-chunks])
 writeFile(out++".channels")(unlines[maybe "-" id channel|(channel,_)<-chunks])
 writeFile(out++".hashes")(unlines[show(fromIntegral(hash text)::Word64)|(_,text)<-chunks])
 writeFile(out++".text")(concatMap snd chunks)
 print(length chunks,sum(map(length.snd)chunks))
