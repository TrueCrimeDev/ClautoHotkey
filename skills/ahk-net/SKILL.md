---
name: ahk-net
description: >
  HTTP and downloads for AHK v2 — Download(), WinHttp over COM, status and timeout handling, UTF-8
  response decoding, binary bodies, query-string encoding, Basic and Bearer auth, retry with backoff,
  the native JSON class for request and response bodies, and non-blocking or parallel requests.
  TRIGGER when: user says "HTTP", "REST", "API call", "fetch a URL", "web request", "download a file",
  "POST JSON", "Bearer token", "basic auth", "retry request", "rate limit", "async HTTP",
  "parallel requests", "URL encode", "WinHttpRequest", "XMLHTTP".
  Examples: "call a REST API and parse the JSON", "download a file with progress safety",
  "send a POST with a Bearer token", "fire ten requests in parallel"
---

# AHK v2 Networking and HTTP

Load `${CLAUDE_PLUGIN_ROOT}/Modules/Module_NetworkAndHTTP.md`. For saving or reading the result, also load
`${CLAUDE_PLUGIN_ROOT}/Modules/Module_FileSystem.md`.

## Critical rules

1. Use the native `JSON` class for bodies. Never `#Include` a JSON library. Hub scripts that must also run on stock AHK use the `Lib/HubJSON.ahk` subset (`Parse`, `Stringify`, `[]`, `Has`, `Get`).
2. Decode text responses from `ResponseBody` as UTF-8. `ResponseText` guesses the charset and breaks on non-ASCII when the header is missing.
3. `WaitForResponse` returns false on timeout and throws on a network failure. Handle both.
4. A 404 or 500 is a normal return with a status code, not an exception. Check `Status` before parsing.
5. Download to a `.part` file and rename it when the size check passes.
6. Set timeouts on every request. Never block the message loop with a long synchronous call in a GUI script.

TLS certificate management, sockets and WebSockets are outside this module.
