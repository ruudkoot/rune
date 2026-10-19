module Main where
import Env
import GHC.Float(castFloatToWord32)
main=mapM_(print . castFloatToWord32)(take 10000(random_numbers(9807,65,32975)))
