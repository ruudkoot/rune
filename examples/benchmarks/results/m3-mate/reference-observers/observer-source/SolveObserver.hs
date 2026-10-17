module Main where
import Problem
import Solution
main = getContents >>= \input -> let (bd,(c,n))=readProblem input in putStr (solve bd c n)
