-- rows: R33
-- Report 5: main is exported by Main, and need not be defined there: imported and exported again (R33: the
-- text says export).
module Main (main) where

import Other (main)
