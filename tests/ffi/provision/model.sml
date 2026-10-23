structure FfiProvisionTests =
struct
  open BuildCommon
  val count=ref 0
  fun check name condition=(need(condition,"provision fixture: " ^ name);count:= !count+1)
  fun refuses name action=check name ((action();false) handle Failed _=>true | OS.SysErr _=>true)
  fun member name kind link : BuildArchive.member={name=name,kind=kind,link=link,data=""}
  fun run ()=
    let val top="libffi-3.4.6"
        val ()=refuses "headless libffi rejected" (fn()=>ignore(BuildFFIDeps.main["libffi","--headless"]))
        val ()=refuses "headless cross target rejected" (fn()=>ignore(BuildFFIDeps.main["sdl","--headless","--target","windows32"]))
        val ()=List.app(fn name=>refuses("archive path " ^ name)(fn()=>BuildFFIDeps.admitted top(member name #"0" "")))
          ["/tmp/escape","libffi-3.4.6/../escape","libffi-3.4.6/a/../../escape","other/file","libffi-3.4.6/a\\escape"]
        val ()=List.app(fn link=>refuses("archive link " ^ link)(fn()=>BuildFFIDeps.admitted top(member(top ^ "/link")#"2" link)))
          ["/tmp/escape","../../escape","../other/file"]
        val ()=BuildFFIDeps.admitted top(member(top ^ "/directory/")#"5" "")
        val ()=BuildFFIDeps.admitted top(member(top ^ "/directory/link")#"2" "../LICENSE")
        val ()=check "safe directory and internal relative link" true
        val ()=refuses "special archive file" (fn()=>BuildFFIDeps.admitted top(member(top ^ "/device")#"3" ""))
        val directory=privateDirectory(fromRoot "tests/out/provision")"fixtures"
        val archive=directory ^ "/source.tar.gz" val ()=write(archive,"pinned fixture")
        val calls=ref 0
        fun command _ _=(calls:= !calls+1;raise Failed "fixture must not launch a command")
        val ()=check "offline verified cache" (BuildFFIDeps.download archive(hash archive)[]true command=NONE)
        val ()=refuses "corrupt cached archive" (fn()=>ignore(BuildFFIDeps.download archive(String.implode(List.tabulate(64,fn _=> #"0")))[]true command))
        val ()=refuses "offline missing archive" (fn()=>ignore(BuildFFIDeps.download(directory ^ "/missing") (hash archive)[]true command))
        val ()=check "cache checks perform no subprocess work" (!calls=0)
        val prefix=directory ^ "/prefix" val ()=mkdirs prefix val ()=write(prefix ^ "/marker","original")
        fun ownership path=BuildFFIDeps.validatePrefix{directory=path,prefix=prefix,project="libffi",target="native"}
        fun attempt ()=ignore(BuildFFIDeps.main["libffi","--prefix",prefix,"--offline"])
        val ()=refuses "unowned nonempty prefix rejected before commands" attempt
        val ()=check "unowned file is preserved" (read(prefix ^ "/marker")="original")
        fun record path expected=json(path ^ "/rune-ffi-dependency.json")
          (Json.Object[("config",Json.Object[("schema",number 1),("project",str "libffi"),("target",str "native"),("prefix",str expected)]),
            ("outputs",Json.Object[("marker",str(hash(path ^ "/marker")))]),("links",Json.Object[]),("directories",strings[])])
        val ()=record prefix prefix
        val ()=write(prefix ^ "/unrelated-note","keep")
        val ()=refuses "unrecorded file rejected before commands" attempt
        val ()=check "unrecorded file is preserved" (read(prefix ^ "/unrelated-note")="keep")
        val ()=remove(prefix ^ "/unrelated-note")
        val ()=write(directory ^ "/outside","outside")
        val ()=Posix.FileSys.symlink{old="../outside",new=prefix ^ "/unrecorded-link"}
        val ()=refuses "unrecorded symlink rejected before fresh shortcut" attempt
        val ()=check "unrecorded symlink and target are preserved" (isLink(prefix ^ "/unrecorded-link") andalso read(directory ^ "/outside")="outside")
        val ()=OS.FileSys.remove(prefix ^ "/unrecorded-link")
        val ()=record prefix(directory ^ "/other-prefix")
        val ()=refuses "recorded prefix mismatch rejected" attempt
        val ()=record prefix prefix
        val ()=write(prefix ^ "/marker","modified owned bytes")
        val ()=ownership prefix
        val ()=check "modified owned output remains eligible for rebuild" true
        val ()=write(prefix ^ "/marker","original")
        val ()=refuses "failed publication restores prefix" (fn()=>BuildFFIDeps.publish{staged=directory ^ "/absent",prefix=prefix,project="libffi",target="native"})
        val ()=check "old prefix survives failure" (read(prefix ^ "/marker")="original")
        val staged=directory ^ "/stage" val ()=mkdirs staged val ()=write(staged ^ "/marker","replacement")
        val ()=record staged prefix
        val ()=BuildFFIDeps.publish{staged=staged,prefix=prefix,project="libffi",target="native"}
        val ()=check "successful publication replaces whole prefix" (read(prefix ^ "/marker")="replacement" andalso not(exists staged))
        val ()=check "compiler flags change cache identity"
          (BuildFFIDeps.environmentIdentity["CFLAGS=-O0"]<>BuildFFIDeps.environmentIdentity["CFLAGS=-O2"])
        val ()=check "unset and empty flags have distinct identity"
          (BuildFFIDeps.environmentIdentity[]<>BuildFFIDeps.environmentIdentity["CFLAGS="])
        val ()=remove directory
    in say("PASS FFI dependency model: " ^ Int.toString(!count) ^ " checks\n") end
end
val ()=(BuildIO.initialize();FfiProvisionTests.run())
