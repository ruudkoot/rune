(* lex.comments: a comment holds any UTF-8 text in every mode -- café,
   λ, 日本語, 😀 -- the marks LRM ‎, RLM ‏ and ALM ؜, and the other
   default-ignorables: ZWSP ​, ZWJ ‍, ZWNJ ‌, WJ ⁠, VS16 ️,
   U+3164 ㅤ; TAB	, FF and CR LF
   end lines (* nested *) as well *)
val () = print "kept\n"
