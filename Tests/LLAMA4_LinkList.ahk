#Requires AutoHotkey v2.0

; Global variable containing a multi-line string of URLs
g_Links := "
(
www.google.com
www.amazon.com
https://github.com/TrueCrimeAudit/ClautoHotkey
https://www.autohotkey.com/boards/viewtopic.php?f=96&t=120588
)"

; Define a class for the Link Manager
class LinkManager {
    links := []
    gui := {}
    listView := ""

    ; Constructor to parse links and create the GUI
    __New() {
        this.ParseLinks()
        this.CreateGui()
    }

    ; Parse the g_Links string into an array of URL objects
    ParseLinks() {
        Loop Parse g_Links, "`n", "`r"
        {
            url := Trim(A_LoopField)
            if (url != "") {
                obj := {url: url, valid: this.ValidateUrl(url), displayName: this.GetDisplayName(url)}
                this.links.Push(obj)
            }
        }
    }

    ; Validate a URL using a regular expression
    ValidateUrl(url) {
        pattern := "i)^(https?:\/\/)?([\w\.-]+)\.([a-z\.]{2,6})(\/[\w\.-]*)*\/?$"
        return RegExMatch(url, pattern) ? true : false
    }

    ; Get the display name for a URL (extract domain or pathname)
    GetDisplayName(url) {
        ; Simple implementation, can be improved
        return url
    }

    ; Create the GUI components and event handlers
    CreateGui() {
        this.gui := Gui("+Resize", "Link Manager")
        this.listView := this.gui.Add("ListView", "r10 w400", ["URL", "Valid"])
        this.gui.Add("Button", "Default", "Open Selected").OnEvent("Click", (*) => this.OpenSelectedLink())
        this.gui.Add("StatusBar")
        this.gui.Show()
        this.PopulateListView()
    }

    ; Populate the ListView with the parsed links
    PopulateListView() {
        this.listView.Delete()
        for link in this.links {
            this.listView.Add("", link.url, link.valid ? "Yes" : "No")
        }
    }

    ; Open the selected link in Microsoft Edge
    OpenSelectedLink() {
        row := this.listView.GetNext()
        if (row) {
            url := this.listView.GetText(row, 1)
            this.OpenInEdge(url)
        }
    }

    ; Open a URL in Microsoft Edge
    OpenInEdge(url) {
        if (!RegExMatch(url, "i)^https?://")) {
            url := "https://" . url  ; Add https:// prefix if missing
        }
        Run("msedge.exe " . url . " --new-tab", , "Hide")
    }
}

; Main code
manager := LinkManager()