#Requires AutoHotkey v2.1-alpha.30

ReadConfig(path) {
    try {
        return FileRead(path)
    } catch {
    }
}
