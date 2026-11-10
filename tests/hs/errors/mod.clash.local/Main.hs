-- Report 5.5.2: the Report's F: a local sin and the Prelude's, sin used unqualified, clash.
module Main (main) where

sin :: Float -> Float
sin x = x

main :: IO ()
main = print (sin 1)
