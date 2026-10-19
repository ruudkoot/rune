(* Paul Sanders's fixed-12-bit prefix-tree LZW, parameterized by demand. *)
functor BenchCompressFn (D : BENCH_SUSPEND) =
struct
  datatype treeNode = PTNil | PT of prefix D.t * treeNode D.t * treeNode D.t
  and prefix = PTE of char D.t * int D.t * treeNode D.t
  type tree = treeNode D.t
  datatype 'a node = Nil | Cons of 'a D.t * 'a node D.t
  type 'a stream = 'a node D.t
  fun emptyTree () = D.delay(fn () => PTNil)
  fun empty () = D.delay(fn () => Nil)
  fun value x = D.delay(fn () => x)
  fun insert key code table = D.delay(fn () =>
    case D.force table of
      PTNil => PT(value(PTE(value key,value code,emptyTree())),emptyTree(),emptyTree())
    | PT(entry,left,right) =>
        let val PTE(k,_,_) = D.force entry
        in case Char.compare(key,D.force k) of
            LESS => PT(entry,insert key code left,right)
          | GREATER => PT(entry,left,insert key code right)
          | EQUAL => PT(entry,left,right)
        end)
  val balancedKeys =
    [128,64,32,16,8,4,2,1,0,3,6,5,7,12,10,9,
     11,14,13,15,24,20,18,17,19,22,21,23,28,26,25,27,
     30,29,31,48,40,36,34,33,35,38,37,39,44,42,41,43,
     46,45,47,56,52,50,49,51,54,53,55,60,58,57,59,62,
     61,63,96,80,72,68,66,65,67,70,69,71,76,74,73,75,
     78,77,79,88,84,82,81,83,86,85,87,92,90,89,91,94,
     93,95,112,104,100,98,97,99,102,101,103,108,106,105,107,110,
     109,111,120,116,114,113,115,118,117,119,124,122,121,123,126,125,
     127,192,160,144,136,132,130,129,131,134,133,135,140,138,137,139,
     142,141,143,152,148,146,145,147,150,149,151,156,154,153,155,158,
     157,159,176,168,164,162,161,163,166,165,167,172,170,169,171,174,
     173,175,184,180,178,177,179,182,181,183,188,186,185,187,190,189,
     191,224,208,200,196,194,193,195,198,197,199,204,202,201,203,206,
     205,207,216,212,210,209,211,214,213,215,220,218,217,219,222,221,
     223,240,232,228,226,225,227,230,229,231,236,234,233,235,238,237,
     239,248,244,242,241,243,246,245,247,252,250,249,251,254,253,255] : int list
  val initial = List.foldr(fn (code,table) => insert (Char.chr code) code table)
    (emptyTree()) balancedKeys
  (* The tuple is shared; updated path nodes can remain unforced at EOF. *)
  fun codeString input index oldCode nextCode table = D.delay(fn () =>
    if index=String.size input then (index,oldCode,emptyTree()) else
    let val character = String.sub(input,index)
    in case D.force table of
        PTNil =>
          if D.force nextCode>=4096 then (index,oldCode,emptyTree())
          else (index,oldCode,D.delay(fn () =>
            PT(value(PTE(value character,nextCode,emptyTree())),emptyTree(),emptyTree())))
      | PT(entry,left,right) =>
          let val PTE(key,code,extension) = D.force entry
          in case Char.compare(character,D.force key) of
              LESS =>
                let val (rest,result,updated) = D.force(codeString input index oldCode nextCode left)
                in (rest,result,D.delay(fn () => PT(entry,updated,right))) end
            | GREATER =>
                let val (rest,result,updated) = D.force(codeString input index oldCode nextCode right)
                in (rest,result,D.delay(fn () => PT(entry,left,updated))) end
            | EQUAL =>
                let val (rest,result,updated) = D.force(codeString input (index+1) code nextCode extension)
                in (rest,result,D.delay(fn () =>
                  PT(value(PTE(key,code,updated)),left,right))) end
          end
    end)
  fun encodeFrom input index nextCode table = D.delay(fn () =>
    if index=String.size input then Nil else
    let val result = codeString input index (value 0) nextCode table
        val head = D.delay(fn () => let val (_,code,_) = D.force result in D.force code end)
        val tail = D.delay(fn () =>
          let val (rest,_,updated) = D.force result
              val next = D.delay(fn () => D.force nextCode+1)
          in D.force(encodeFrom input rest next updated) end)
    in Cons(head,tail) end)
  fun encode input = encodeFrom input 0 (value 256) initial
  fun prepend head tail = D.delay(fn () => Cons(head,tail))
  fun pack codes = D.delay(fn () => case D.force codes of
      Nil => Nil
    | Cons(x,rest) => case D.force rest of
        Nil => Cons(D.delay(fn () => D.force x div 16),
          prepend (D.delay(fn () => D.force x mod 16)) (empty()))
      | Cons(y,tail) => Cons(D.delay(fn () => D.force x div 16),
          prepend (D.delay(fn () => (D.force x mod 16)*16+D.force y div 256))
            (prepend (D.delay(fn () => D.force y mod 256)) (pack tail))))
  fun toList stream =
    case D.force stream of Nil => [] | Cons(head,tail) => D.force head :: toList tail
  fun compress input = String.implode(List.map Char.chr(toList(pack(encode input))))
end
