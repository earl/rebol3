REBOL [
    title: "Extension Loader -- improved loading of native extensions"
    author: "Andreas Bolka"
    name: extload
    type: module
    needs: [2.100.110]
    exports: [translate-extension]
    rights: {
        Copyright (C) 2011 Andreas Bolka <a AT bolka DOT at>
        Licensed under the terms of the Apache License, Version 2.0
    }
]

;; --- Helpers ----------------------------------------------------------------

invert-file-types: funct [
    "Map file types as known in system/options/file-types to their suffix(es)."
    /types "Override system/options/file-types"
        file-types [block!] "Structure: [%.ext1 ... %.extN typeA %.extM ...]"
] [
    default file-types system/options/file-types
    types: map []
    here: prev: file-types
    forall here [
        if word? type: first here [
            types/(type): copy/part prev here
            prev: next here
        ]
    ]
    types
]

;; --- Exports ----------------------------------------------------------------

translate-extension: funct [
    "Translate a generic extension name to platform-specfic names."
    extension [file! string! word!]
    /generic "Override the generic suffix"
        suffix [file!] "Default: %.rx"
    /platform "Override the platform-specific suffixes"
        suffixes [block!] "Default: from system/options/file-types"
] [
    extension: to file! extension
    default suffix %.rx
    default suffixes pick invert-file-types 'extension

    ;; Default to generic suffix, if no platform-specific ones are provided.
    ;; (This also handles 'extension not found in system/options/file-types.)
    if empty? suffixes [suffixes: reduce [suffix]]

    ;; Leave non-%.rx names alone ...
    unless suffix = suffix? extension [
        return reduce [extension]
    ]

    ;; ... but translate %.rx into all platform-specific suffixes.
    clear find/last extension suffix
    map-each suffix suffixes [join extension suffix]
]

lib/load-extension: funct/with [
    "Low level extension module loader (for DLLs)."
    name [file! binary!] "DLL file or UTF-8 source"
    /dispatch {Specify native command dispatch (from hosted extensions)}
        function [handle!] "Command dispatcher (native)"
] [
    if binary? name [
        return apply :load-extension* [name dispatch function]
    ]

    foreach filename filenames: translate-extension name [
        if ext: attempt [apply :load-extension* [filename dispatch function]] [
            return ext
        ]
    ]

    cause-error 'access 'no-extension filenames
] [
    load-extension*: :lib/load-extension
]

;; --- Tests ------------------------------------------------------------------

#test [

original-module-paths: system/options/module-paths
original-file-types: system/options/file-types

tests: [
    ;; -- translate-extension

    ;; setup
    [system/options/file-types: [%.rx %.qux extension]]

    ;; filenames ending in the generic suffix are translated
    [[%foo.rx %foo.qux] = translate-extension %foo.rx]

    ;; filenames not ending in the generic suffix are left as-is
    [[%foo] = translate-extension %foo]
    [[%foo.bar] = translate-extension %foo.bar]
    [[%foo.rx.bar] = translate-extension %foo.rx.bar]

    ;; generic suffix and/or platform suffixes can be overridden
    [[%foo.rx %foo.qux] =
        translate-extension/generic %foo.r3x %.r3x]
    [[%foo.bar %foo.baz] =
        translate-extension/platform %foo.rx [%.bar %.baz]]
    [[%foo.bar %foo.baz] =
        translate-extension/generic/platform %foo.r3x %.r3x [%.bar %.baz]]

    ;; if platform suffixes are empty, generic suffix is used as fallback
    [system/options/file-types: []]

    [[%foo.rx] = translate-extension %foo.rx]
    [[%foo.r3x] = translate-extension/generic/platform %foo.r3x %.r3x []]

    ;; teardown
    [system/options/file-types: :original-file-types]
]

foreach t tests [print either do t ['ok] [join "FAILED:" mold t]]

] ; #test
