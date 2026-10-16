module WriterObserver where
import Encode
import WriteRoutines
import System.Environment
import Data.Char
parse "N"=NewWordSize
parse "C"=Clear
parse text=Code(read text)
main=do
 args<-getArgs
 if args==["demand"]then print(take 1(snd(outputCodes[Code(error "unforced")])) )
 else let(bytes,sizes)=outputCodes(map parse args)in print(map ord bytes,sizes)
