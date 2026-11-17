-- One text, two programs: read plain, this module's `a` is "plain"; read
-- literate (A.lhs), its code is what \begin{code} encloses, where `a` is
-- "literate" (build-cache-issues.md, issue 27).
module A where

a :: String
a = "plain"

{-
\begin{code}
module A where

a :: String
a = "literate"
\end{code}
-}
