-- Report 5.2: a field exported as f, as T(f), as T(..) and by module M: each importer uses it.
module Main (main) where

import qualified M1
import qualified M2
import qualified M3
import qualified M4

main :: IO ()
main = print (M1.f M1.mk, M2.f M2.mk, M3.f M3.mk, M4.f M4.mk)
