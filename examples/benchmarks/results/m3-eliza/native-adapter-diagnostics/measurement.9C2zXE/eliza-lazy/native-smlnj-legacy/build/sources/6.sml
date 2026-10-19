functor BenchElizaFn (D : BENCH_SUSPEND) =
struct
  datatype queueNode = QCons of string * queueNode BenchLazy.delay
  type queue = queueNode BenchLazy.delay
  type state = ((string list * queue) list * queue) D.t
  datatype textNode = TNil | TCons of char * textNode D.t
  type text = textNode D.t

  fun cycle items =
    let val holder = ref NONE
        fun build [] = raise Fail "Eliza empty reply cycle"
          | build [first] = QCons (first, valOf (!holder))
          | build (first :: rest) =
              QCons (first, BenchLazy.delay (fn () => build rest))
        val root = BenchLazy.delay (fn () => build items)
        val _ = holder := SOME root
    in root end

  val initial : state = D.delay (fn () =>
    (List.map (fn (key, messages) =>
       (String.tokens Char.isSpace key, cycle messages)) BenchElizaData.responses,
     cycle BenchElizaData.repeated))

  fun punctuation c =
    List.exists (fn p => p = c) [#" ", #".", #"!", #"?", #","]
  fun trim text =
    let val n = String.size text
        fun left i =
          if i < n andalso punctuation (String.sub (text, i)) then left (i + 1)
          else i
        val first = left 0
        fun right i =
          if i >= first andalso punctuation (String.sub (text, i))
          then right (i - 1) else i
        val last = right (n - 1)
    in if last < first then ""
       else String.substring (text, first, last - first + 1)
    end
  fun uppercase text = String.map Char.toUpper text
  fun prefix [] _ = true
    | prefix _ [] = false
    | prefix (x :: xs) (y :: ys) = x = y andalso prefix xs ys

  fun conjugate default tail =
    let val words = if List.null tail then default else tail
        fun change word =
          let val key = uppercase word
              fun lookup [] = word
                | lookup ((name, value) :: rest) =
                    if key = name then value else lookup rest
          in lookup BenchElizaData.conjugates end
        val words = List.map change words
        val words = case List.rev words of
            "I" :: rest => List.rev ("me" :: rest) | _ => words
        fun join [] = ""
          | join [first] = first
          | join (first :: rest) = first ^ " " ^ join rest
    in join words end

  datatype replyNode = RNil | RCons of string D.t * replyNode D.t
  fun replies key words =
    let fun tails [] = D.delay (fn () => RNil)
          | tails (tail as _ :: rest) = D.delay (fn () =>
              if prefix key (List.map uppercase tail)
              then RCons
                (D.delay (fn () => conjugate words (List.drop (tail, List.length key))),
                 tails rest)
              else D.force (tails rest))
    in tails words end

  fun response template suffix =
    if String.size template > 0 andalso String.sub (template, 0) = #"?"
    then String.extract (template, 1, NONE) ^ " " ^ D.force suffix ^ "?"
    else if String.size template > 0 andalso String.sub (template, 0) = #"."
    then String.extract (template, 1, NONE) ^ " " ^ D.force suffix ^ "."
    else template

  fun answer state words =
    let val (table, repeated) = D.force state
        fun choose [] = raise Fail "Eliza missing fallback"
          | choose ((entry as (key, queue)) :: rest) =
              case D.force (replies key words) of
                RNil =>
                  let val result = D.delay (fn () => choose rest)
                  in (D.delay (fn () => D.force (#1 (D.force result))),
                      D.delay (fn () => entry :: D.force (#2 (D.force result))))
                  end
              | RCons (suffix, _) =>
                  let val QCons (template, next) = BenchLazy.force queue
                  in (D.delay (fn () => response template suffix),
                      D.delay (fn () => (key, next) :: rest)) end
        val (message, next) = choose table
    in (message, D.delay (fn () => (D.force next, repeated))) end

  fun repeated state =
    let val (table, queue) = D.force state
        val QCons (message, next) = BenchLazy.force queue
    in (D.delay (fn () => message), D.delay (fn () => (table, next))) end
  fun appendChars [] rest = rest
    | appendChars (c :: cs) rest =
        D.delay (fn () => TCons (c, appendChars cs rest))
  fun session state previous [] = D.delay (fn () => TNil)
    | session state previous (words :: rest) = D.delay (fn () =>
        let val (message, next) =
              if previous = words then repeated state else answer state words
        in D.force (appendChars (String.explode (D.force message ^ "\n\n"))
             (session next words rest))
        end)
  fun prepare lines = List.filter (fn words => not (List.null words))
    (List.map (fn line => String.tokens Char.isSpace (trim line)) lines)
  fun take 0 _ = []
    | take _ [] = []
    | take n (first :: rest) = first :: take (n - 1) rest
  fun conversation lines count = session initial [] (prepare (take count lines))
  fun app emit text = case D.force text of
      TNil => () | TCons (c, rest) => (emit c; app emit rest)
  fun length text =
    let fun loop count text = case D.force text of
            TNil => count | TCons (_, rest) => loop (count + 1) rest
    in loop 0 text end
end
