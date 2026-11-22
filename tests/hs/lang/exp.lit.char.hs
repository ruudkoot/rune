-- Report 3.2: a character literal is a Char and takes no class method: with nothing of the Prelude imported unqualified
-- (5.6.1: the qualified import is the only import of it).
module Main (main) where

import qualified Prelude as P

c = 'a'

main :: P.IO ()
main = P.print c
