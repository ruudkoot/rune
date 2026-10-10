(* History: entries kept in a file shared by the sessions.

   Implements: HISTORY *)
structure History :> HISTORY =
struct
  type history = {file : string option, limit : int, entries : string vector ref, read : Position.int ref}

  fun env name = case OS.Process.getEnv name of SOME "" => NONE | v => v

  fun defaultFile () =
    case env "XDG_STATE_HOME" of
      SOME d => SOME (OS.Path.concat (d, "rune/history"))
    | NONE =>
        case env "LOCALAPPDATA" of
          SOME d => SOME (OS.Path.concat (d, "rune/history"))
        | NONE =>
            case env "HOME" of
              SOME d => SOME (OS.Path.concat (d, ".local/state/rune/history"))
            | NONE => NONE

  fun escape e =
    String.translate (fn #"\n" => "\\n" | #"\r" => "\\r" | #"\\" => "\\\\" | c => String.str c) e

  fun unescape l =
    let
      fun go ([], acc) = String.implode (rev acc)
        | go (#"\\" :: #"n" :: rest, acc) = go (rest, #"\n" :: acc)
        | go (#"\\" :: #"r" :: rest, acc) = go (rest, #"\r" :: acc)
        | go (#"\\" :: #"\\" :: rest, acc) = go (rest, #"\\" :: acc)
        | go (c :: rest, acc) = go (rest, c :: acc)
    in
      go (String.explode l, [])
    end

  fun entries (h : history) = !(#entries h)

  (* the last limit of a list of entries *)
  fun lastOf (limit, es) = if List.length es > limit then List.drop (es, List.length es - limit) else es

  fun linesOf text = List.filter (fn l => l <> "") (String.fields (fn c => c = #"\n") text)

  fun readFile path =
    let val i = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end

  fun size path = OS.FileSys.fileSize path handle OS.SysErr _ => Position.fromInt 0

  fun makeDirectories dir =
    if dir = "" orelse OS.FileSys.access (dir, []) then ()
    else (makeDirectories (OS.Path.dir dir); OS.FileSys.mkDir dir handle OS.SysErr _ => ())

  (* the file rewritten with its last limit entries, when it has more than
     twice that *)
  fun trim (path, limit, es) =
    if List.length es <= 2 * limit then ()
    else
      let
        val tmp = path ^ ".new"
        val out = BinIO.openOut tmp
      in
        BinIO.output (out, Byte.stringToBytes (String.concat (map (fn e => escape e ^ "\n") (lastOf (limit, es)))));
        BinIO.closeOut out;
        OS.FileSys.rename {old = tmp, new = path}
      end
      handle IO.Io _ => () | OS.SysErr _ => ()

  fun load {file, limit} =
    case file of
      NONE => {file = NONE, limit = limit, entries = ref (Vector.fromList []), read = ref (Position.fromInt 0)}
    | SOME path =>
        let
          val text = readFile path handle IO.Io _ => ""
          val es = map unescape (linesOf text)
          val () = trim (path, limit, es)
        in
          {file = file, limit = limit, entries = ref (Vector.fromList (lastOf (limit, es))), read = ref (size path)}
        end

  fun refresh (h : history) =
    case #file h of
      NONE => ()
    | SOME path =>
        let val now = size path
        in
          if now = !(#read h) then ()
          else
            let
              val text = readFile path handle IO.Io _ => ""
              val fresh = if now < !(#read h) orelse Position.fromInt (String.size text) < !(#read h) then text
                          else String.extract (text, Position.toInt (!(#read h)), NONE)
              val old = if now < !(#read h) then [] else Vector.foldr (op ::) [] (!(#entries h))
            in
              #entries h := Vector.fromList (lastOf (#limit h, old @ map unescape (linesOf fresh)));
              #read h := Position.fromInt (String.size text)
            end
        end

  fun add (h : history, e) =
    let
      val () = refresh h
      val es = !(#entries h)
      val n = Vector.length es
    in
      if e = "" orelse (n > 0 andalso Vector.sub (es, n - 1) = e) then ()
      else
        (#entries h := Vector.fromList (lastOf (#limit h, Vector.foldr (op ::) [] es @ [e]));
         case #file h of
           NONE => ()
         | SOME path =>
             (let
                val () = makeDirectories (OS.Path.dir path)
                val out = BinIO.openAppend path
              in
                BinIO.output (out, Byte.stringToBytes (escape e ^ "\n"));
                BinIO.closeOut out;
                #read h := size path
              end
              handle IO.Io _ => () | OS.SysErr _ => ()))
    end
end
