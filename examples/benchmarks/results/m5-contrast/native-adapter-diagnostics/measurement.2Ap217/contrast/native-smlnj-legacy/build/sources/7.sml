structure BenchSauvolaIntMemo=BenchSauvolaMemoFn(struct
 type key=int*int
 val hash=BenchSauvolaHash.pairInt
 fun equal((a,b),(c,d))=a=c andalso b=d
end)
