structure GeneratedScalarsClient =
struct
  fun run path =
    let val session=GeneratedScalars.openSession {libraries=[path]}
        val ()=if GeneratedScalars.add session {first=17,second=25}=42 then () else raise Fail "generated record input"
        val ()=if GeneratedScalars.bits session 0wxF0000000=0wx70000000 then () else raise Fail "generated unsigned projection"
        val ()=if Real.abs(GeneratedScalars.fraction session 1.5-1.75)<0.000001 then () else raise Fail "generated floating projection"
        val ()=if GeneratedScalars.invert session false andalso not(GeneratedScalars.invert session true) then () else raise Fail "generated bool projection"
    in GeneratedScalars.closeSession session;print "PASS generated scalar calls and record projection\n" end
end
val ()=case CommandLine.arguments() of [path]=>GeneratedScalarsClient.run path | _=>raise Fail "expected generated subject path"
