-- rows: mod.adt.newtype
-- Report 5.8: the Report's Stack, over data and over newtype, exported without its constructors.
module Main (main) where

import qualified Stack as S
import qualified NStack as N

main :: IO ()
main = S.pop (S.push (1 :: Int) S.empty) `seq` N.pop (N.push (1 :: Int) N.empty) `seq` return ()
