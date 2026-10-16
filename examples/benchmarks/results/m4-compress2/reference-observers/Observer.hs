module Observer where
import qualified Kernel
import System.Environment
import System.IO
main=do
 hSetBinaryMode stdin True
 hSetBinaryMode stdout True
 [cut]<-getArgs
 input<-getContents
 putStr(Kernel.compress(take(max 0(length input-read cut))input))
