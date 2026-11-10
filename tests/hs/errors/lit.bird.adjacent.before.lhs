-- Report 9.4: "It is an error for a program line to appear adjacent to a non-blank comment line": a program
-- line, then at once a comment line.

> module Main (main) where

> main :: IO ()
> main = return ()
A comment line.
