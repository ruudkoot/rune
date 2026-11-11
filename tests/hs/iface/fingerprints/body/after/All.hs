-- A body's edit moves nothing: f's type is written, and no fixity, type or instance changes.
module All (f, g) where

f :: Int -> Int
f x = x * 2 + 1

g :: Int
g = 3
