-- The cycle split: A no longer imports B, so A and B are two units with new names; what Main reads of B is as it
-- was, so Main is taken: under the link of the roadmap's C a usage names no unit, and a client of a split SCC
-- compiles at most once.
module A where

a :: Int
a = 1
