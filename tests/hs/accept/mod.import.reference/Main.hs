-- rows: mod.flatten.example mod.prelude.default mod.structure.imports.empty
-- Report 5: modules name others by import; the Report's example Main with A.f >> B.f; the Prelude is imported by default
-- (a module with no imports uses map).
module Main (main) where

import qualified A
import qualified B

main :: IO ()
main = A.f >> B.f
