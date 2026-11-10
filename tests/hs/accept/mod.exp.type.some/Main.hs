-- rows: mod.exp.type.some.empty
-- Report 5.2: T(c1, ..., cn) exports the type and the constructors and fields listed; T() the type alone.
module Main (main) where

import M

main :: IO ()
main = print (case C 1 of C n -> n) >> (g `seq` return ())
  where
    g :: Maybe U
    g = Nothing

