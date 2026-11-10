-- Report 9.3, equation 12: L [] [] = []: a module wholly in explicit braces ends with no context open.
module Main (main) where { main :: IO (); main = return () }
