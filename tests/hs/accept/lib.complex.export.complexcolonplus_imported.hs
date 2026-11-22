-- rows: lib.complex.export.realpart lib.complex.export.imagpart lib.complex.export.conjugate lib.complex.export.mkpolar lib.complex.export.cis lib.complex.export.polar lib.complex.export.magnitude lib.complex.export.phase
-- Report 13.1: module Complex exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Complex (Complex((:+)), realPart, imagPart, conjugate, mkPolar, cis, polar, magnitude, phase)

t0 :: Complex Double -> ()
t0 _ = ()
s0_0 _ = (:+)

v1 _ = realPart

v2 _ = imagPart

v3 _ = conjugate

v4 _ = mkPolar

v5 _ = cis

v6 _ = polar

v7 _ = magnitude

v8 _ = phase

main :: IO ()
main = return ()
