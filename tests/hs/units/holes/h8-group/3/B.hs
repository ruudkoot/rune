-- A body edit in the cycle: its unit compiled, and no client.
module B where

import A

data U = M T | E

b :: U
b = E
