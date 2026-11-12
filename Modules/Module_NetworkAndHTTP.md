---
name: Module_NetworkAndHTTP
description: 'HTTP and downloads in AHK v2 — Download(), WinHttp.WinHttpRequest.5.1 over COM, status and timeout handling,
  UTF-8 response decoding, binary bodies via ResponseBody, query-string encoding, Basic and Bearer auth, retry with backoff,
  the native JSON class for request and response bodies, non-blocking requests with SetTimer and WaitForResponse(0),
  and parallel requests. TRIGGER when the request involves: HTTP, REST, API call, "fetch URL", "web request", Download,
  URLDownloadToFile, WinHttp, WinHttpRequest, XMLHTTP, ComObject HTTP, responseText, ResponseBody, setRequestHeader,
  WaitForResponse, Bearer token, "basic auth", "rate limit", "retry request", timeout, "async HTTP", "parallel requests",
  "non-blocking request", "JSON response", "POST JSON", "query string", "URL encode". Not covered: sockets, WebSocket,
  OAuth browser flows, TLS certificate management — see Module_COM.md and Module_DllCall.md for the raw COM and DllCall
  layers; try/catch design — see Module_Errors.md; reading and writing the downloaded file — see Module_FileSystem.md.'
---

# Module_NetworkAndHTTP

## API QUICK-REFERENCE

### Transport choice
| Need | Use | Notes |
|------|-----|-------|
| Save a URL to a file | `Download(url, path)` | Synchronous; blocks the thread; throws on transport or disk failure |
| Any request with headers, body, status | `ComObject("WinHttp.WinHttpRequest.5.1")` | Built into Windows; the default choice |
| Request that must not block | WinHttp `Open(method, url, true)` + `SetTimer` + `WaitForResponse(0)` | See the async tier |
| Browser-like cookies and caching | `ComObject("MSXML2.XMLHTTP.6.0")` | Rarely needed; has `readyState`, no `SetTimeouts`, no `SetCredentials` |

### WinHttp.WinHttpRequest.5.1
| Member | Signature | Notes |
|--------|-----------|-------|
| `SetTimeouts` | `(resolve, connect, send, receive)` | Milliseconds; call before `Open`; 0 means no limit for that phase |
| `Open` | `(method, url, async := false)` | `async := true` returns from `Send` at once |
| `SetRequestHeader` | `(name, value)` | After `Open`, before `Send` |
| `Send` | `([body])` | String body is sent as UTF-8; omit for GET |
| `WaitForResponse` | `([timeoutSecs])` | Returns true when ready, false on timeout; throws on network failure. Pumps messages, so the GUI, hotkeys and timers keep running |
| `Abort` | `()` | Cancels an in-flight request |
| `Status`, `StatusText` | read-only | HTTP 4xx and 5xx do not throw — read `Status` |
| `ResponseText` | read-only | Decoded using the server charset; unreliable when the header is missing or wrong |
| `ResponseBody` | read-only | `ComObjArray` of bytes (VT_UI1); the safe route for binary and for forced UTF-8 |
| `GetAllResponseHeaders`, `GetResponseHeader(name)` | | CRLF-separated text / one value |
| `SetCredentials` | `(user, password, flags)` | flags 0 = server, 1 = proxy |
| `SetProxy` | `(setting, server?, bypass?)` | 0 = default, 1 = none, 2 = named proxy |
| `SetAutoLogonPolicy` | `(policy)` | 0 = always, 1 = intranet only, 2 = never |

WinHttpRequest has no `readyState`, and `ComObjConnect` event sinks do not work with it. Completion is detected only through `WaitForResponse`.

### Native JSON (fork build)
| Call | Result |
|------|--------|
| `JSON.Parse(text)` | Objects become `JSON.Object` (Map-like: `[]`, `Has`, `Get`, `Count`, enumerable), arrays become `JSON.Array` (an `Array`) |
| `JSON.Stringify(value, , indent?)` | Map, Array, `JSON.Object`, and plain objects; `indent` is a width or a string |
| `JSON.Validate(text)` | Returns `{Valid, Pos, Line, Col, Code, Message}`; never throws |
| `JSON.ParseFile(path)` | Parses a file without a `FileRead` round trip |
| `JSONError` | Extends `ValueError`; thrown by `Parse` |

## AHK V2 CONSTRAINTS

- JSON: use the native `JSON` class directly. Do not `#Include` thqby, cJson or JXON — the include only shadows the native class. Stock AHK has no `JSON` class, so code that must also run there includes a pure-AHK `class JSON` that returns plain Map and Array results (thqby's `JSON.ahk` does). In that code stay on the common surface (`JSON.Parse`, `JSON.Stringify`, `[]`, `Has`, `Get`, `for`) and avoid `JSON.Object`, `ParseAt`, `ParseFile`, `Validate` and the `Options` argument.
- JSON `true`, `false` and `null` arrive as `1`, `0` and `""`. AHK has no boolean type, so a plain `1` serializes as the number 1. `Stringify` re-emits `true` for values that were parsed from `true` and are unchanged, and the fork has `JSON.True` and `JSON.False` singletons for building payloads. Code that must run on stock AHK sends `1` or `0` when the API accepts them.
- Check `Status` before trusting `ResponseText`. WinHttp does not throw for 4xx or 5xx.
- Leave the resolve timeout at 0. The AHK documentation sample does, and the OS resolver has its own limit.
- Pass a timeout to `WaitForResponse` and handle a false return. A bare `WaitForResponse()` waits indefinitely.
- Percent-encode query values from their UTF-8 bytes. Encoding per character with `Ord` breaks every non-ASCII character.
- Decode the response yourself with `StrGet(buffer, size, "UTF-8")` when the API is known to be UTF-8. Many JSON APIs omit the charset and `ResponseText` then guesses.
- Do not use `Open(method, url, false)` from a GUI script or any script with timers: the synchronous form blocks the message loop. Use the async form with `WaitForResponse(timeout)`.
- Keep an async request object alive until it finishes. A local COM object freed at function exit cancels the request.
- A BoundFunc stored on the object it binds forms a reference cycle. Delete the timer and clear the property when the request finishes.
- Callbacks are named functions or bound methods. Fat arrows only for single expressions.
- Arrays from JSON are 1-based.
- A refused connection or DNS failure surfaces as a plain `Error` with a COM HRESULT, not an `OSError`, so catch `Error` (or everything) around request calls.
- `for` over a Map visits keys in sorted order, so a query string built from a Map is sorted; do not rely on parameter order.
- Never put secrets in a URL query string, a log line or a `MsgBox`.

## TIER 1 - Download a file

`Download` blocks until the transfer ends and throws on network or disk failure. The file is written to a temporary name first, so a failed or empty transfer never replaces a good file. Do not assume an error page is rejected: a server that answers 404 with HTML can still produce a saved file, which is why the size check and `.part` rename are here.

```ahk
DownloadFile(url, dest) {
    SplitPath(dest, , &dir)
    if dir != "" && !DirExist(dir)
        DirCreate(dir)
    partial := dest ".part"
    try {
        Download(url, partial)
        if FileGetSize(partial) = 0
            throw Error("Empty download", , url)
        FileMove(partial, dest, true)
    } catch as err {
        if FileExist(partial)
            FileDelete(partial)
        throw err
    }
}

try {
    DownloadFile("https://example.com/data.csv", A_Temp "\data.csv")
} catch as err {
    MsgBox("Download failed: " err.Message)
}
```

## TIER 2 - One synchronous-looking request that keeps the GUI alive

`Open(..., true)` with `WaitForResponse(timeout)` waits without freezing the script. The helper returns a Map with the status, the decoded text, the raw bytes and the headers, and throws `TimeoutError` or the COM error on transport failure. HTTP error statuses are returned, not thrown, so the caller decides what a 404 means.

```ahk
HttpRequest(method, url, body := "", headers?, timeoutSec := 30, encoding := "UTF-8") {
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.SetTimeouts(0, 10000, 30000, timeoutSec * 1000)
    whr.Open(method, url, true)
    if IsSet(headers) {
        for name, value in headers
            whr.SetRequestHeader(name, value)
    }
    if body = ""
        whr.Send()
    else
        whr.Send(body)
    if !whr.WaitForResponse(timeoutSec) {
        whr.Abort()
        throw TimeoutError("No response within " timeoutSec " s", , url)
    }
    raw := ResponseBuffer(whr)
    result := Map()
    result["status"] := whr.Status
    result["bytes"] := raw
    result["text"] := raw.Size ? StrGet(raw, raw.Size, encoding) : ""
    result["headers"] := whr.GetAllResponseHeaders()
    return result
}

ResponseBuffer(whr) {
    arr := whr.ResponseBody
    if !(arr is ComObjArray)
        return Buffer(0)
    size := arr.MaxIndex() + 1
    if size <= 0
        return Buffer(0)
    ; The SAFEARRAY data pointer sits after cDims, fFeatures, cbElements and cLocks
    pData := NumGet(ComObjValue(arr), 8 + A_PtrSize, "Ptr")
    buf := Buffer(size)
    DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", pData, "UPtr", size)
    return buf
}

res := HttpRequest("GET", "https://example.com/")
if res["status"] = 200
    MsgBox(SubStr(res["text"], 1, 200))
else
    MsgBox("HTTP " res["status"])
```

Saving a binary body is a write of the buffer, not of the text:

```ahk
SaveBinary(res, path) {
    out := FileOpen(path, "w")
    try
        out.RawWrite(res["bytes"], res["bytes"].Size)
    finally
        out.Close()
}
```

## TIER 3 - Query strings, headers and authentication

Percent-encoding works on UTF-8 bytes, keeping only the RFC 3986 unreserved set.

```ahk
UriEncode(text) {
    if text = ""
        return ""
    size := StrPut(text, "UTF-8") - 1
    buf := Buffer(size)
    StrPut(text, buf, "UTF-8")
    out := ""
    Loop size {
        b := NumGet(buf, A_Index - 1, "UChar")
        if (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
            || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E
            out .= Chr(b)
        else
            out .= Format("%{:02X}", b)
    }
    return out
}

BuildUrl(base, params) {
    query := ""
    for key, value in params
        query .= (query = "" ? "" : "&") UriEncode(String(key)) "=" UriEncode(String(value))
    return query = "" ? base : base (InStr(base, "?") ? "&" : "?") query
}

Base64Utf8(text) {
    size := StrPut(text, "UTF-8") - 1
    src := Buffer(size)
    StrPut(text, src, "UTF-8")
    len := 0
    ; 0x40000001 = CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", src, "UInt", size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &len)
    dst := Buffer(len * 2)
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", src, "UInt", size, "UInt", 0x40000001, "Ptr", dst, "UInt*", &len)
    return StrGet(dst, "UTF-16")
}

BasicAuth(user, password) => "Basic " Base64Utf8(user ":" password)

params := Map()
params["q"] := "autohotkey v2"
params["limit"] := 10
url := BuildUrl("https://api.example.com/search", params)

headers := Map()
headers["Authorization"] := "Bearer " EnvGet("API_TOKEN")
headers["Accept"] := "application/json"
res := HttpRequest("GET", url, , headers)
```

`SetCredentials(user, password, 0)` on the request object is an alternative to the manual Basic header and also answers NTLM and Negotiate challenges; use the header form when the API expects preemptive credentials on the first request.

## TIER 4 - JSON round trip with the native class

Build the payload with Map and Array, send it with a JSON content type, and parse the reply. The code below uses only that common surface, so it also runs on stock AHK with a pure-AHK `class JSON` included.

```ahk
PostJson(url, data, token := "") {
    headers := Map()
    headers["Content-Type"] := "application/json; charset=utf-8"
    headers["Accept"] := "application/json"
    if token != ""
        headers["Authorization"] := "Bearer " token
    res := HttpRequest("POST", url, JSON.Stringify(data), headers)
    if res["status"] < 200 || res["status"] >= 300
        throw Error("HTTP " res["status"], , SubStr(res["text"], 1, 300))
    return res["text"] = "" ? "" : JSON.Parse(res["text"])
}

payload := Map()
payload["name"] := "Alice"
payload["tags"] := ["admin", "ops"]
payload["active"] := 1

try {
    reply := PostJson("https://api.example.com/users", payload, EnvGet("API_TOKEN"))
    if reply is Map || reply is JSON.Object
        MsgBox("Created id " reply["id"])
} catch ValueError as err {
    MsgBox("Reply was not valid JSON: " err.Message)
} catch as err {
    MsgBox("Request failed: " err.Message)
}
```

The `is JSON.Object` test is fork-only; on stock AHK test `reply is Map` alone. Fork-only code can gate untrusted text first and read a file directly:

```ahk
check := JSON.Validate(res["text"])
if !check.Valid
    throw Error("Bad JSON at line " check.Line ": " check.Message)
cfg := JSON.ParseFile(A_ScriptDir "\config.json")
```

Reading fields: use `data["key"]` for required fields, `data.Get("key", default)` for optional ones, and `data.Has("key")` before descending into an optional object. Arrays are 1-based: `data["items"][1]` is the first element.

Do not build JSON by string concatenation. A hand-written escaper misses control characters and Unicode, and `Stringify` already handles both.

## TIER 5 - Retry with backoff and rate limiting

Retry transport failures, 429 and 5xx. Do not retry other 4xx: the request is wrong and will stay wrong. Honour `Retry-After` when the server sends it.

```ahk
HttpWithRetry(method, url, body := "", headers?, maxTries := 4) {
    delay := 500
    Loop maxTries {
        try {
            res := HttpRequest(method, url, body, headers?)
        } catch as err {
            if A_Index = maxTries
                throw err
            Sleep(delay)
            delay *= 2
            continue
        }
        status := res["status"]
        if status != 429 && status < 500
            return res
        if A_Index = maxTries
            return res
        wait := delay
        if RegExMatch(res["headers"], "im)^Retry-After:\s*(\d+)", &m)
            wait := Integer(m[1]) * 1000
        Sleep(wait)
        delay *= 2
    }
}
```

`HttpRequest(method, url, body, headers?)` passes an unset optional parameter through. Spacing calls to a rate-limited API is a `Sleep` between requests, or a stored `A_TickCount` of the last call compared against a minimum interval.

## TIER 6 - Non-blocking and parallel requests

`WaitForResponse(0)` is a poll: it returns at once with true or false. A timer polling it keeps the main thread free, and any number of requests can be in flight. `AsyncRequest` owns its COM object and its timer, reports through a callback with one result Map, and breaks its own reference cycle when finished.

```ahk
class AsyncRequest {
    __New(method, url, onDone, body := "", headers?, timeoutSec := 30) {
        this.onDone := onDone
        this.deadline := A_TickCount + timeoutSec * 1000
        this.whr := ComObject("WinHttp.WinHttpRequest.5.1")
        this.whr.SetTimeouts(0, 10000, 30000, timeoutSec * 1000)
        this.whr.Open(method, url, true)
        if IsSet(headers) {
            for name, value in headers
                this.whr.SetRequestHeader(name, value)
        }
        if body = ""
            this.whr.Send()
        else
            this.whr.Send(body)
        this.tick := this.Poll.Bind(this)
        SetTimer(this.tick, 50)
    }

    Poll() {
        result := Map()
        try {
            if !this.whr.WaitForResponse(0) {
                if A_TickCount < this.deadline
                    return
                this.whr.Abort()
                throw TimeoutError("Request timed out")
            }
            result["status"] := this.whr.Status
            result["text"] := this.whr.ResponseText
        } catch as err {
            result["error"] := err
        }
        this.Finish(result)
    }

    Cancel() {
        if !this.HasProp("tick") || !this.tick
            return
        this.whr.Abort()
        this.Release()
    }

    Finish(result) {
        callback := this.onDone
        this.Release()
        callback(result)
    }

    Release() {
        SetTimer(this.tick, 0)
        this.tick := ""
    }
}
```

The timer holds the BoundFunc, which holds the object, so a request stays alive without the caller storing it. Store it anyway when the caller needs `Cancel()`.

Fan-out with a join: a small class counts completions and fires once when the last one lands. Results are stored by URL, so completion order does not matter.

```ahk
class RequestBatch {
    __New(urls, onAll) {
        this.onAll := onAll
        this.results := Map()
        this.remaining := urls.Length
        this.requests := []
        for url in urls
            this.requests.Push(AsyncRequest("GET", url, this.OnOne.Bind(this, url)))
    }

    OnOne(url, result) {
        this.results[url] := result
        if --this.remaining > 0
            return
        callback := this.onAll
        this.requests := []
        callback(this.results)
    }
}

ShowAll(results) {
    for url, result in results {
        if result.Has("error")
            Print("{} -> error: {}", url, result["error"].Message)
        else
            Print("{} -> HTTP {}", url, result["status"])
    }
}

urls := ["https://example.com/a", "https://example.com/b", "https://example.com/c"]
batch := RequestBatch(urls, ShowAll)
```

Keep the number of simultaneous requests modest (a handful per host); many APIs rate-limit by connection count before they limit by volume.

## ANTI-PATTERNS

| Mistake | Fix |
|---------|-----|
| `ComObjCreate("WinHttp.WinHttpRequest.5.1")` | `ComObject(...)`; the v1 name is gone |
| `#Include` of a JSON library, or hand-built JSON strings | Native `JSON.Parse` and `JSON.Stringify`; a pure-AHK `class JSON` only on stock AHK |
| `JSON.Parse` on stock AHK with nothing included | The class does not exist on stock AHK; include a pure-AHK `class JSON` such as thqby's `JSON.ahk` |
| `return whr.ResponseText` with no status check | Test `Status` first; 4xx and 5xx return normally |
| `whr.ReadyState`, `ComObjConnect(whr, sink)` | Not supported by WinHttpRequest; poll `WaitForResponse(0)` |
| `Open(m, u, false)` in a script with a GUI | `Open(m, u, true)` + `WaitForResponse(timeout)` |
| `Download(url, path)` straight over the final file | Download to `.part`, check the size, then `FileMove` |
| Encoding query values per `Ord(char)` | Encode UTF-8 bytes (`UriEncode` above) |
| Request object in a local variable of the starting function | Hold it in an object that lives until the callback (`AsyncRequest`) |
| `(s, b) => { ... }` as a callback | Named function or `.Bind(this)` method |
| Secrets in the URL or in logs | Put them in headers and mask them in output |

## SEE ALSO

- `Module_Errors.md` - try/catch/finally, error classes, retry-friendly error design.
- `Module_COM.md` - ComObject, ComObjArray and SafeArray details behind `ResponseBody`.
- `Module_DllCall.md` - Buffer, NumGet/NumPut and DllCall used by the Base64 and SafeArray helpers.
- `Module_FileSystem.md` - atomic writes, binary file I/O and encodings for saving responses.
- `Module_TextProcessing.md` - parsing non-JSON response bodies.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
