-- exitWith (ExitFailure 0) uncaught (overlay ov.system.exitzero, the lead's ruling 57): the program ends as a failure,
-- status 1, its output written by 21's close and flush (R37), and nothing after it runs (hs/library/exitzero).
module Main (main) where

import System

main :: IO ()
main = do
  putStr "before"
  exitWith (ExitFailure 0)
  putStrLn "never"
