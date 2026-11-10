-- Module CPUTime, section 26 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module CPUTime ( getCPUTime, cpuTimePrecision ) where

import PreludeRuntime (time_cpu)        -- (rhc's)

-- picoseconds, of the processor time the system counts in microseconds
getCPUTime        :: IO Integer
getCPUTime        =  time_cpu >>= \t -> return (toInteger t * 1000000)
cpuTimePrecision  :: Integer
cpuTimePrecision  =  1000000
