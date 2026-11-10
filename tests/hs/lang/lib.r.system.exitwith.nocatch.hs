-- Report 23: exitWith is no IOError: catch does not see it, and status 0 ends the program normally. It waits for B's primitives for the process and its environment.
module Main (main) where

import System

main :: IO ()
main = do
  catch (exitWith ExitSuccess) (\_ -> putStrLn "caught")
  putStrLn "after"
