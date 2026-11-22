module M where
f = z where {- c -} z = 1
                    w = 2
g = z where -- c
  z = 1
  w = 2
