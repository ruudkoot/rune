-- rows: N10 N22 deviation
-- Report 6.4.3, read with the sources' correction 2a78309 (N22): 0**y is 1 if y is 0, and 0 otherwise. rhc's (**)
-- on Double is IEEE's pow, as every implementation's is, which gives Infinity at a negative y: a deviation from the
-- corrected sentence, on the ground "wrong" (D13b; tests/hs2010/deviations.tsv).
main :: IO ()
main = do
  print (0 ** 0 :: Double)
  print (0 ** 2 :: Double)
  print (0 ** (-1) :: Double)
