module Observer where
import qualified Main
import Control.Monad.Trans.State
import System.Environment
main=do
 [mode]<-getArgs
 if mode=="all" then print(execStateT (Main.solve (transpose(map reverse words)) (reverse "NINETY") 0) Main.initState)
 else putStr(Main.puzzle words "NINETY")
 where
 words=["THIRTY","TWELVE","TWELVE","TWELVE","TWELVE","TWELVE"]
 transpose ([]:_)=[]
 transpose rows=map head rows:transpose(map tail rows)
