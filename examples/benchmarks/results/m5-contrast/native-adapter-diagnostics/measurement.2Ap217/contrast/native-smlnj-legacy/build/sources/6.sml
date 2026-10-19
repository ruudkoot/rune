structure BenchSauvolaRealMemo=BenchSauvolaMemoFn(struct
 type key=real*real
 val hash=BenchSauvolaHash.pairReal
 fun equal((a,b),(c,d))=BenchSauvolaHash.equalReal(a,c)andalso BenchSauvolaHash.equalReal(b,d)
end)
