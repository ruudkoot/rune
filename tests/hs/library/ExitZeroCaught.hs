-- exitWith (ExitFailure 0) raises an IOError for which isIllegalOperation holds (overlay ov.system.exitzero, the
-- lead's ruling 57; 23 lets a system prohibit 0): caught, the program goes on (hs/library/exitzero).
module Main (main) where

import IO
import System

main :: IO ()
main = do
  r <- try (exitWith (ExitFailure 0))
  print (either isIllegalOperation (const False) r)
  putStrLn "after"
