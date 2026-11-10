-- rows: R77
-- Report 2.3, 2.4: varsym excludes dashes, so `--` is no operator and `F.--` no qvarsym; the longest lexeme
-- at `F` is the qvarsym `F.-`, then `-`. With F's `-` binding looser than negation, `1 F.-- 2` is
-- `1 F.- (-2)`; read as `F` then `.--`, or as one qualified `--`, it names nothing.
module Main (main) where

import qualified F

main :: IO ()
main = print (1 F.-- 2)
