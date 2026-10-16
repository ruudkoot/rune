module Observer where
import qualified Kernel
import System.Environment
main=do [n]<-getArgs;print(Kernel.permutations[0..read n-1])
