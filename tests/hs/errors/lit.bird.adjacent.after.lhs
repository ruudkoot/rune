-- Report 9.4: "It is an error for a program line to appear adjacent to a non-blank comment line": a comment
-- line, then at once a program line.

> module Main (main) where

A comment line.
> main :: IO ()
> main = return ()
