structure FulsomWord64Probe=struct
 structure W=Word64
 val maximum:W.word=0wxFFFFFFFFFFFFFFFF
 val sign:W.word=0wx8000000000000000
 val modulus=valOf(IntInf.fromString"18446744073709551616")
 val wanted=valOf(IntInf.fromString"18446744073709551615")
 val _=print("literal="^W.toString maximum^"\ntoLargeInt="^IntInf.toString(W.toLargeInt maximum)^"\nmasked="^W.toString(W.andb(maximum,sign))^"\n")
 val _=T.check("word64/toLargeInt-all-ones",fn()=>W.toLargeInt maximum=wanted)
 val _=T.check("word64/fromLargeInt-all-ones",fn()=>W.fromLargeInt wanted=maximum)
 val _=T.check("word64/sign-mask",fn()=>W.andb(maximum,sign)=sign)
 val _=T.check("word64/signed-conversion",fn()=>IntInf.-(W.toLargeInt maximum,modulus)=IntInf.fromInt(~1))
end
