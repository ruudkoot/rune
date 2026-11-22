-- rows: R31
-- Report 5.3.1: it is an error to hide what the module does not export (R31: refused, as the text has it).
module Main (main) where

import A hiding (nosuch)

main :: IO ()
main = return ()
