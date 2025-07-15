
/**
 * Load the Windows App Runtime and add it to the package graph of the current process.
 * @param majorMinorVersion The exact major and minor version to load, such as `"1.6"`.
 * @returns {String} The full package name of the runtime.
 */
UseWindowsAppRuntime(majorMinorVersion) =>
    UseAppxPackage("Microsoft.WindowsAppRuntime." majorMinorVersion "_8wekyb3d8bbwe", majorMinorVersion)


/**
 * Add a package to the package graph of the current process.
 * @param packageFamily The package family name.
 * @param appRuntimeVersionForLoader The major and minor version of the app runtime to
 *  use if the Windows 11 package dependency API is not available, this function has not
 *  already been called, and Microsoft.WindowsAppRuntime.dll has not yet been loaded.
 *  The app runtime itself is not automatically added to the package graph.
 * @returns {String} The full package name of the added package.
 */
UseAppxPackage(packageFamily, appRuntimeVersionForLoader?) {
    static lib := LoadPackageDependencyLib(appRuntimeVersionForLoader?)
    try {
        (lib.TryCreatePackageDependency)(0, packageFamily, 0, 0, 0, 0, 0, &pdid:=0)
        (lib.AddPackageDependency)(pdid, 0, 0, 0, &pname:=0)
        return StrGet(pname)
    }
    finally {
        (pdid ?? 0) && lib.FreeString(pdid)
        (pname ?? 0) && lib.FreeString(pname)
    }
}


/**
 * Get all app packages with the given family name.
 * @param packageFamily 
 * @returns {Array} 
 */
GetPackagesByPackageFamily(packageFamily) {
    ; GetPackagesByPackageFamily: the documentation says to call it with NULL buffers first,
    ; allocate memory and then call again.  But isn't it theoretically possible that the
    ; required buffer size could INCREASE between calls if apps are being installed right now?
    ; So it would seem to be wiser to handle the ERROR_INSUFFICIENT_BUFFER return value and
    ; loop even if non-NULL buffers were passed.  HOWEVER, THE FUNCTION ACTUALLY RETURNS 0 if
    ; it was passed non-NULL buffers, even if they were insufficient!
    np := 16, nc := 1984
    loop {
        buf := Buffer((inp := np) * A_PtrSize + (inc := nc) * 2, 0), pc := buf.ptr + np * A_PtrSize
        DllCall("GetPackagesByPackageFamily", 'str', packageFamily, 'uint*', &np, 'ptr', buf, 'uint*', &nc, 'ptr', pc)
    } until np <= inp && nc <= inc
    a := [], a.Length := np
    Loop np
        a[A_Index] := StrGet(NumGet(buf, (A_Index - 1) * A_PtrSize, 'ptr'))
    return a
}


LoadWindowsAppRuntimeDll(majorMinorVersion?) {
    if (hmod := DllCall("LoadLibrary", 'str', "Microsoft.WindowsAppRuntime.dll", 'ptr'))
        return hmod
    for s in GetPackagesByPackageFamily("Microsoft.WindowsAppRuntime." majorMinorVersion "_8wekyb3d8bbwe")
        if InStr(s, A_PtrSize = 4 ? "_x86_" : "_x64_")
            if DllCall("GetPackagePathByFullName", 'str', s, 'uint*', 260, 'ptr', pathbuf := Buffer(260 * 2)) = 0
                if hmod := DllCall("LoadLibrary", 'str', StrGet(pathbuf) "\Microsoft.WindowsAppRuntime.dll", 'ptr')
                    return hmod
    return 0
}


LoadPackageDependencyLib(majorMinorVersion?) {
    static defs := [
        ["TryCreatePackageDependency", [
            , 'ptr', ; user context (0 = current user)
            , 'str', ; package family name
            , 'int64', ; min version (0 = any)
            , 'int', ; architecture (0 = unspecified; same as current process)
            , 'int', ; lifetimeKind (0 = Process)
            , 'ptr', ; lifetimeArtifact (must be NULL when lifetimeKind = Process)
            , 'int', ; options (0 = None)
            , 'ptr*', ; out: dependency ID
            , 'hresult'
        ]],
        ["AddPackageDependency", [
            , 'ptr', ; dependency ID
            , 'int', ; rank
            , 'int', ; options (0 = None)
            , 'ptr*', ; out: context pointer for RemovePackageDependency
            , 'ptr*', ; out: package full name
            , 'hresult'
        ]]
    ]
    makeFun(hmod, prefix, def) {
        if !(pfn := DllCall("GetProcAddress", 'ptr', hmod, 'astr', prefix . def[1], 'ptr'))
            return false
        def[2][1] := pfn
        return DllCall.Bind(def[2]*)
    }
    hmod := DllCall("LoadLibrary", 'str', "KernelBase.dll", 'ptr')
    if  f1 := makeFun(hmod, "", defs[1])
        f2 := makeFun(hmod, "", defs[2])
    else {
        DllCall("FreeLibrary", 'ptr', hmod)
        if !(hmod := LoadWindowsAppRuntimeDll(majorMinorVersion?))
            throw Error("Microsoft.WindowsAppRuntime.dll must be loaded before calling this function.", -1)
        f1 := makeFun(hmod, "Mdd", defs[1])
        f2 := makeFun(hmod, "Mdd", defs[2])
    }
    if !(f1 && f2)
        throw Error("Essential functions were not found")
    h := {hmod: hmod}
    h.DefineProp(defs[1][1], {call: f1})
    h.DefineProp(defs[2][1], {call: f2})
    h.DefineProp('FreeString', {call: (h, p) {
        static heap := DllCall("GetProcessHeap", 'ptr')
        DllCall("HeapFree", 'ptr', heap, 'uint', 0, 'ptr', p) || throw(OSError(,-1))
    }})
    return h
}
