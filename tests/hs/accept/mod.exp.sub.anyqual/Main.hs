-- Report 5.2: a subordinate name in scope under a qualified name only: the Report's A( Mb.Maybe( Nothing, Just ) ).
module Main (main) where

import qualified Prelude as P
import Prelude (IO, print, return)
import A2

main :: IO ()
main = print (Just 1 :: P.Maybe P.Int)
