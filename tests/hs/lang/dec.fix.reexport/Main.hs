-- rows: dec.fix.notinscope dec.fix.entity
-- Report 4.4.2, 5: a fixity is its entity's: A declares <-> infixr 5, B re-exports it and C, imported as X... X.<->
-- has A's; importing <-> alone brings its fixity; another module's <-> keeps its own, infixl 6.
module Main (main) where

import qualified B as X
import A ((<->))
import qualified C

main :: IO ()
main = print (10 X.<-> 3 X.<-> 2, 10 <-> 3 <-> 2, 10 C.<-> 3 C.<-> 2)
