-- rows: lib.r.system.getenv.err
-- Report 23: getEnv of a variable that is set, and of one that is not, which fails with isDoesNotExistError. It waits for B's primitives for the process and its environment.
module Main (main) where

import System
import IO

main :: IO ()
main = do
  p <- getEnv "PATH"
  print (not (null p))
  r <- try (getEnv "RHC_NO_SUCH_VARIABLE_9")
  print (either isDoesNotExistError (const False) r)
