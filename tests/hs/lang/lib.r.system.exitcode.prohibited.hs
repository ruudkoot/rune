-- rows: R37
-- Report 23 (R37; ruling 49 makes the row a run, the lead's ruling 57 rhc's choice): some exit codes may be
-- prohibited, 0 on a POSIX system for one, and the Report does not say what exitWith (ExitFailure 0) then does. rhc
-- prohibits 0, as GHC and Hugs stop on it: exitWith (ExitFailure 0) raises an IOError, an illegal operation, which
-- catch sees, and which, uncaught, ends the program as a failure, status 1, what was written first flushed.
module Main (main) where

import IO
import System

main :: IO ()
main = do
  putStrLn "before"
  r <- try (exitWith (ExitFailure 0))
  either (print . isIllegalOperation) (const (putStrLn "no error")) r
  exitWith (ExitFailure 0)
  putStrLn "after"
