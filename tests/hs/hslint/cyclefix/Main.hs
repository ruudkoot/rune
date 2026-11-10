-- HsLint's second inference over a cycle of modules (the roadmap's D30): under the default,
-- `--cycle-default=module`, Rule 2 holds each module's monomorphic types to the module alone, so
-- B's use may not fix A's n; under `--cycle-default=scc` it may.
module Main (main) where

import A (n)

main :: IO ()
main = print n
