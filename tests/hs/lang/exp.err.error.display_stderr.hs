-- Report 3.1: a call to error displays its string; this waits for rhc's standard error, which must hold the line boom
-- (a .stderr-head of rhc's form, written when rhc runs it).
module Main (main) where

main :: IO ()
main = error "boom"
