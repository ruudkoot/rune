module Main where
import Prog
main = getContents >>= putStr . prog
