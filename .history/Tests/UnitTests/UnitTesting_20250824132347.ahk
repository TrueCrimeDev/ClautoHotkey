#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

TestSuiteExtractor()

class TestSuiteExtractor {
    __New() {
        this.baseDir := A_ScriptDir
        this.markdownFile := this.baseDir . "\Test.md"
        this.ProcessMarkdown()
    }
    
    ProcessMarkdown() {
        if !FileExist(this.markdownFile) {
            MsgBox("Test.md not found in: " . this.baseDir)
            return
        }
        
        content := FileRead(this.markdownFile)
        blocks := this.ExtractCodeBlocks(content)
        
        successCount := 0
        for block in blocks {
            if this.SaveCodeBlock(block["filename"], block["code"])
                successCount++
        }
        
        MsgBox("Extracted " . successCount . " test files from Test.md")
    }
    
    ExtractCodeBlocks(content) {
        blocks := []
        lines := StrSplit(content, "`n", "`r")
        currentHeader := ""
        inCodeBlock := false
        codeBuffer := ""
        
        for line in lines {
            if RegExMatch(line, "^#{1,6}\s*\d*\.?\s*(.+)$", &headerMatch) {
                currentHeader := this.CleanHeaderForFilename(headerMatch[1])
            }
            else if line = "``````cpp" || line = "````cpp" {
                inCodeBlock := true
                codeBuffer := ""
            }
            else if inCodeBlock && (line = "``````" || line = "````") {
                if currentHeader != "" && codeBuffer != "" {
                    blocks.Push(Map(
                        "filename", currentHeader,
                        "code", RTrim(codeBuffer, "`n`r")
                    ))
                }
                inCodeBlock := false
                codeBuffer := ""
            }
            else if inCodeBlock {
                codeBuffer .= line . "`n"
            }
        }
        
        return blocks
    }
    
    CleanHeaderForFilename(header) {
        cleaned := header
        cleaned := RegExReplace(cleaned, "^\d+\.?\s*", "")
        cleaned := RegExReplace(cleaned, "[^\w\s-]", "")
        cleaned := Trim(cleaned)
        cleaned := RegExReplace(cleaned, "\s+", "")
        
        if cleaned = ""
            cleaned := "Unnamed"
        
        return cleaned . ".ahk"
    }
    
    SaveCodeBlock(filename, code) {
        filepath := this.baseDir . "\" . filename
        
        try {
            if FileExist(filepath) {
                result := MsgBox("File " . filename . " already exists. Overwrite?", "Confirm", "YesNo")
                if result != "Yes"
                    return false
            }
            
            FileOpen(filepath, "w").Write(code)
            return true
        } catch Error as e {
            MsgBox("Failed to save " . filename . ": " . e.Message)
            return false
        }
    }
}