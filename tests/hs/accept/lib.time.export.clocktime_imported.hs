-- rows: lib.time.export.monthjanuarycfebruarycmarchcaprilcmaycjunecjulyc lib.time.export.daysundaycmondayctuesdaycwednesdaycthursdaycfrid lib.time.export.calendartimecalendartimecctyearcctmonthcctdaycct lib.time.export.timedifftimediffctdyearctdmonthctddayctdhourctdm lib.time.export.getclocktime lib.time.export.addtoclocktime lib.time.export.diffclocktimes lib.time.export.tocalendartime lib.time.export.toutctime lib.time.export.toclocktime lib.time.export.calendartimetostring lib.time.export.formatcalendartime
-- Report 24: module Time exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Time (ClockTime, Month(January,February,March,April,May,June, July,August,September,October,November,December), Day(Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday), CalendarTime(CalendarTime, ctYear, ctMonth, ctDay, ctHour, ctMin, ctSec, ctPicosec, ctWDay, ctYDay, ctTZName, ctTZ, ctIsDST), TimeDiff(TimeDiff, tdYear, tdMonth, tdDay, tdHour, tdMin, tdSec, tdPicosec), getClockTime, addToClockTime, diffClockTimes, toCalendarTime, toUTCTime, toClockTime, calendarTimeToString, formatCalendarTime)

t0 :: ClockTime -> ()
t0 _ = ()

t1 :: Month -> ()
t1 _ = ()
s1_0 _ = January
s1_1 _ = February
s1_2 _ = March
s1_3 _ = April
s1_4 _ = May
s1_5 _ = June
s1_6 _ = July
s1_7 _ = August
s1_8 _ = September
s1_9 _ = October
s1_10 _ = November
s1_11 _ = December

t2 :: Day -> ()
t2 _ = ()
s2_0 _ = Sunday
s2_1 _ = Monday
s2_2 _ = Tuesday
s2_3 _ = Wednesday
s2_4 _ = Thursday
s2_5 _ = Friday
s2_6 _ = Saturday

t3 :: CalendarTime -> ()
t3 _ = ()
s3_0 _ = CalendarTime
s3_1 _ = ctYear
s3_2 _ = ctMonth
s3_3 _ = ctDay
s3_4 _ = ctHour
s3_5 _ = ctMin
s3_6 _ = ctSec
s3_7 _ = ctPicosec
s3_8 _ = ctWDay
s3_9 _ = ctYDay
s3_10 _ = ctTZName
s3_11 _ = ctTZ
s3_12 _ = ctIsDST

t4 :: TimeDiff -> ()
t4 _ = ()
s4_0 _ = TimeDiff
s4_1 _ = tdYear
s4_2 _ = tdMonth
s4_3 _ = tdDay
s4_4 _ = tdHour
s4_5 _ = tdMin
s4_6 _ = tdSec
s4_7 _ = tdPicosec

v5 _ = getClockTime

v6 _ = addToClockTime

v7 _ = diffClockTimes

v8 _ = toCalendarTime

v9 _ = toUTCTime

v10 _ = toClockTime

v11 _ = calendarTimeToString

v12 _ = formatCalendarTime

main :: IO ()
main = return ()
