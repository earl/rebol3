REBOL [title: "A tiny static HTTP server" author: 'abolka date: 2009-11-04]

crlf2bin: to binary! join-of crlf crlf
code-map: make map! [200 "OK" 400 "Forbidden" 404 "Not Found"]
mime-map: make map! [
    "html" "text/html" "css" "text/css" "js" "application/javascript"
    "gif" "image/gif" "jpg" "image/jpeg" "png" "image/png"
    "r" "text/plain" "r3" "text/plain" "reb" "text/plain"

]
error-template: trim/auto copy {
    <html><head><title>$code $text</title></head><body><h1>$text</h1>
    <p>Requested URI: <code>$uri</code></p><hr><i>shttpd.r</i> on
    <a href="http://www.rebol.com/rebol3/">REBOL 3</a> $r3</body></html>
}

error-response: func [code uri /local values] [
    values: [code (code) text (code-map/:code) uri (uri) r3 (system/version)]
    reduce [code "text/html" reword error-template compose values]
]

start-response: func [port res /local code text type body] [
    set [code type body] res
    write port ajoin ["HTTP/1.0 " code " " code-map/:code crlf]
    write port ajoin ["Content-type: " type crlf]
    write port ajoin ["Content-length: " length? body crlf]
    write port crlf
    ;; Manual chunking is only necessary because of several bugs in R3's
    ;; networking stack (mainly cc#2098 & cc#2160; in some constellations also
    ;; cc#2103). Once those are fixed, we should directly use R3's internal
    ;; chunking instead: `write port body`.
    port/locals: copy body
]

send-chunk: func [port] [
    ;; Trying to send data >32'000 bytes at once will trigger R3's internal
    ;; chunking (which is buggy, see above). So we cannot use chunks >32'000
    ;; for our manual chunking.
    unless empty? port/locals [write port take/part port/locals 32'000]
]

handle-request: func [config req /local uri type file data ext] [
    parse to-string req ["get " ["/ " | copy uri to " "]]
    uri: default ["index.html"]
    parse uri [some [thru "."] copy ext: to end (type: select mime-map ext)]
    type: default ["application/octet-stream"]
    if not exists? file: config/root/:uri [return error-response 404 uri]
    if error? try [data: read file] [return error-response 400 uri]
    reduce [200 type data]
]

awake-client: func [event /local port res] [
    port: event/port
    print ["Event type: " event/type]
    switch event/type [
        read [
            either find port/data crlf2bin [
                res: handle-request port/locals/config port/data
                start-response port res
            ] [
                read port
            ]
        ]
        wrote [
            either empty? port/locals [
                close port
            ][
                send-chunk port
            ]
        ]
        close [close port]
    ]
]

awake-server: func [event /local client] [
    if event/type = 'accept [
        client: first event/port
        client/awake: :awake-client
        read client
    ]
]

serve: func [web-port web-root /local listen-port] [
    listen-port: open rejoin [tcp://: web-port]
    listen-port/locals: make object! compose/deep [config: [root: (web-root)]]
    listen-port/awake: :awake-server
    print ajoin ["serving on port " web-port "..."]
    wait listen-port
]

serve 8080 system/options/path
