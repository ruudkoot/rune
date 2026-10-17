module Main where
import Knights
import System.Environment
main = getArgs >>= putStr . printTour
