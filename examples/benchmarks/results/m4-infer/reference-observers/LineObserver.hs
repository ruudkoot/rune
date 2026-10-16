module Main where
import Kernel
main = interact (concatMap readInferShow . lines)
