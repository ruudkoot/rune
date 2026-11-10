-- Report 5.6.1: an explicit import of the Prelude replaces the implicit one: import Prelude ().
module Main (main) where

import Prelude ()

main = map
