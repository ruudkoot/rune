-- rows: lib.locale.export.defaulttimelocale
-- Report 25: module Locale exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Locale (TimeLocale(..), defaultTimeLocale)

t0 :: TimeLocale -> ()
t0 _ = ()

v1 _ = defaultTimeLocale

main :: IO ()
main = return ()
