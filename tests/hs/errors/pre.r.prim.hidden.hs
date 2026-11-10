-- Report 8: PreludeBuiltin is no part of the language: no module of that name can be imported.
module Main (main) where

import PreludeBuiltin

main :: IO ()
main = return ()
