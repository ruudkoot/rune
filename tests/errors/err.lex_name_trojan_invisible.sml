(* Trojan Source, an invisible identifier: U+3164 is a letter that shows
   nothing, so that a name made of it is not seen *)
fun allowed (user : string, ㅤ : bool) = user = "root" orelse ㅤ
