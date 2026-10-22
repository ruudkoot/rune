(* Repository replay retains commit provenance and keeps generated-source
   absence distinct from a compiler disagreement. Generators are producers. *)
structure MutationHistory =
struct
  open Incremental
  fun sources state tree =
    if exists (tree ^ "/rune.build") then
      let val result = command state "" ["sh", fromRoot "scripts/build-files.sh", tree ^ "/rune.build"]
      in need (#status result = 0, "cannot enumerate historical compiler sources"); String.tokens Char.isSpace (#output result) end
    else List.map Hosts.trim (List.filter (fn line => Hosts.trim line <> "" andalso not (String.isPrefix "#" (Hosts.trim line)))
                                        (lines (read (tree ^ "/sources.txt"))))
  fun compilerSources compiler =
    let val state = create "mutation-sources" compiler
        val () = reset state
        val files = ["build/config.sml"] @ sources state root @ ["src/main/rune-main.sml"]
        val () = need (List.all (fn file => exists (fromRoot file)) files, "compiler project needs its generated sources; run make gen")
    in List.map (fn file => (file, CachePlant.binary (fromRoot file))) files end
  fun replay (checker : MutationChecks.checker) repo count =
    let val state = create "mutation-history" (#compiler checker)
        val () = reset state
        val result = command state "" ["git","-C",repo,"rev-list","--first-parent","-n",Int.toString count,"HEAD"]
        val () = need (#status result = 0, "cannot enumerate history commits")
        val commits = List.rev (String.tokens Char.isSpace (#output result))
        fun one commit =
          let val tree = #directory checker ^ "/tree"
              val archive = #directory checker ^ "/history.tar"
              val () = (rmTree tree; mkdirs tree)
              val archiveResult = command state "" ["git","-C",repo,"archive",commit,"-o",archive]
              val () = need (#status archiveResult = 0, "cannot archive history commit " ^ commit)
              val extracted = command state "" ["tar","-xf",archive,"-C",tree]
              val () = need (#status extracted = 0, "cannot extract history commit " ^ commit)
              val oldDirectory = !(#directory state)
              val () = #directory state := tree
              val generated = command state "" ["sh","scripts/gen-build-files.sh"]
              val () = #directory state := oldDirectory
          in if #status generated <> 0 orelse not (exists (tree ^ "/build/config.sml")) then
               say ("SKIP mutate history " ^ commit ^ ": its build files could not be made\n")
             else let val files = ["build/config.sml"] @ sources state tree @ ["src/main/rune-main.sml"]
                      val missing = List.filter (fn file => not (exists (tree ^ "/" ^ file))) files
                  in case missing of file :: _ => say ("SKIP mutate history " ^ commit ^ ": commit does not hold " ^ file ^ "\n")
                   | [] => let val p = MutationProject.create (#compiler checker) (#directory checker ^ "/work-history")
                                          (List.map (fn file => (file, CachePlant.binary (tree ^ "/" ^ file))) files) []
                               val result = MutationChecks.check checker p ["commit " ^ commit]
                           in say ("mutate history: " ^ commit ^ " " ^ (if #built result then "a program" else "no program")
                                   ^ ", " ^ Int.toString (#compiled result) ^ " units compiled\n") end end
          end
    in List.app one commits end
end
