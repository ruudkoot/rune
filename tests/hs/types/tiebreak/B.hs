module B (g) where

import A

default (Int, Float)

g b v = if b then f (not b) else truncate v
