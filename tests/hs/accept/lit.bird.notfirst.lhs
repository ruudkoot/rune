-- Report 9.4: a line is program only where > is its first character: the line " > x" below is comment.

> module Main (main) where

 > this is not program

> main :: IO ()
> main = return ()
