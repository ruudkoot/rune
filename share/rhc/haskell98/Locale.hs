-- Module Locale, section 25.1 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002 with its published
-- errata applied: a modified version of the Report's code, which does not
-- define Haskell 98. LICENSE says what was changed; errata.tsv and
-- overlay.tsv list each change, and pristine/ holds the code as printed.

module Locale(TimeLocale(..), defaultTimeLocale) where

data TimeLocale = TimeLocale {
        wDays  :: [(String, String)],   -- full and abbreviated week days
        months :: [(String, String)],   -- full and abbreviated months
        amPm   :: (String, String),     -- AM/PM symbols
        dateTimeFmt, dateFmt,           -- formatting strings
          timeFmt, time12Fmt :: String     
        } deriving (Eq, Ord, Show)

defaultTimeLocale :: TimeLocale 
defaultTimeLocale =  TimeLocale { 
        wDays  = [("Sunday",   "Sun"),  ("Monday",    "Mon"),   
                  ("Tuesday",  "Tue"),  ("Wednesday", "Wed"), 
                  ("Thursday", "Thu"),  ("Friday",    "Fri"), 
                  ("Saturday", "Sat")],

        months = [("January",   "Jan"), ("February",  "Feb"),
                  ("March",     "Mar"), ("April",     "Apr"),
                  ("May",       "May"), ("June",      "Jun"),
                  ("July",      "Jul"), ("August",    "Aug"),
                  ("September", "Sep"), ("October",   "Oct"),
                  ("November",  "Nov"), ("December",  "Dec")],

        amPm = ("AM", "PM"),
        dateTimeFmt = "%a %b %e %H:%M:%S %Z %Y",
        dateFmt = "%m/%d/%y",
        timeFmt = "%H:%M:%S",
        time12Fmt = "%I:%M:%S %p"
        }
