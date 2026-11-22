-- HsLint's second inference over a cycle of modules (the roadmap's D30): A's f and B's g are one
-- declaration group across the modules, unsigned, and are inferred together; each module's
-- restricted binding is fixed by its own module.
module Main (main) where

import A (f, n)
import B (g, m)

main :: IO ()
main = putStrLn (f 3 ++ g 2 ++ show (n, m))
