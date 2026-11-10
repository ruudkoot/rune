-- Report 4.2.1: the translation of a strict constructor uses the Prelude's $! whatever is in scope: one under import
-- Prelude ().
module StrictPrelude where

import Prelude ()

data B = B
data T = T !B

t :: T
t = T B
