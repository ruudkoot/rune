-- One text whose readings import otherwise: read plain, this module
-- imports nothing; read literate (A.lhs, step 7), it imports B, which the
-- header kept of the plain reading does not say (build-cache-issues.md,
-- issue 27; HU15).
module A where

a :: String
a = "plain, alone"

{-
\begin{code}
module A where

import B

a :: String
a = "literate, with " ++ b
\end{code}
-}
