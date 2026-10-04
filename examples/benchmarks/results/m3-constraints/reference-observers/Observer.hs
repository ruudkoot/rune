module Main where
import qualified Kernel as K
import System.Environment
main = do
  args <- getArgs
  let n = read (head args)
      methods = [K.bt,K.bm,K.bjbt,K.bjbt',K.fc]
      solutions method = map (reverse . map K.value) (K.search method (K.queens n))
  print (map solutions methods)
