; This is a minimal version of AppPackage.ahk which only supports Windows 11.

/**
 * Load the Windows App Runtime and add it to the package graph of the current process.
 * @param majorMinorVersion The exact major and minor version to load, such as `"1.6"`.
 * @returns {String} The full package name of the runtime.
 */
UseWindowsAppRuntime(majorMinorVersion) =>
    UseAppxPackage("Microsoft.WindowsAppRuntime." majorMinorVersion "_8wekyb3d8bbwe")


/**
 * Add a package to the package graph of the current process.
 * @param packageFamily The package family name.
 * @returns {String} The full package name of the added package.
 */
UseAppxPackage(packageFamily, unused?) {
    try {
        DllCall("KernelBase.dll\TryCreatePackageDependency"
            , 'ptr', 0, 'str', packageFamily, 'int64', 0, 'int', 0, 'int', 0
            , 'ptr', 0, 'int', 0, 'ptr*', &pdid := 0, 'hresult')
        DllCall("KernelBase.dll\AddPackageDependency"
            , 'ptr', pdid, 'int', 0, 'int', 0, 'ptr*', 0, 'ptr*', &pname := 0, 'hresult')
        return StrGet(pname)
    }
    finally {
        (pdid ?? 0) && FreeString(pdid)
        (pname ?? 0) && FreeString(pname)
    }
    FreeString(p) {
        static heap := DllCall("GetProcessHeap", 'ptr')
        DllCall("HeapFree", 'ptr', heap, 'uint', 0, 'ptr', p) || throw(OSError(,-1))
    }
}