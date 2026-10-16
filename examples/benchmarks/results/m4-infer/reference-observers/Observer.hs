module Main where
import Kernel
main = interact (\input -> show testEnv ++ prompt ++ concatMap readInferShow (lines input))
