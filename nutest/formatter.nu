use errors.nu

# A formatter that preserves the data as-is, including stream metadata, useful for tests.
export def preserved []: nothing -> closure {
    { $in }
}

# A formatter that preserves the data only, useful for querying.
export def unformatted []: nothing -> closure {
    #table<stream: string, items: list<any>> -> list<any>
    {
        $in
            | each { |message| $message.items }
            | flatten
    }
}

# A formatter that formats items as a string against a theme
export def pretty [
    theme: closure
    error_format: string
]: nothing -> closure {

    #table<stream: string, items: list<any>> -> string
    {
        let events  = $in
        $events
            | each { |event| $event | pretty-format-event $theme $error_format }
            | str join "\n"
    }
}

def pretty-format-event [
    theme: closure
    error_format: string
]: record<stream: string, items: list<any>> -> string {

    let event = $in
    match $event {
        { stream: "output", items: $items } => {
            $items | str join "\n"
        }
        { stream: "error", items: $items } => {
            let formatted = $items | each { $in | pretty-format-item $error_format }
            let text = ($formatted | str join "\n")
            { type: "warning", text: $text } | do $theme
        }
    }
}

def pretty-format-item [error_format: string]: any -> any {
    let item = $in
    if ($item | looks-like-error) {
        $item | format-error $error_format
    } else {
        $item
    }
}

def looks-like-error []: any -> bool {
    let value = $in
    if ($value | describe | str starts-with "record") {
        let columns = $value | columns
        ("msg" in $columns) and ("rendered" in $columns) and ("json" in $columns)
    } else {
        false
    }
}

# returns: string|record
def format-error [error_format: string]: record -> any {
    let error = $in
    match $error_format {
        "rendered" => ($error | error-format-rendered)
        "compact" => ($error | error-format-compact)
        "record" => $error
        _ => (error make { msg: $"Unknown error format: ($error_format)" })
    }
}

# Rendered errors have useful info for terminal mode but too much for table data
def error-format-rendered []: record -> string {
    $in.rendered
}

def error-format-compact []: record -> string {
    let error = $in | errors unwrap-error

    let json = $error.json | from json
    let message = $json.msg
    let help = $json | get help?
    let labels = $json | get labels?

    if $help != null {
        $"($message)\n($help)"
    } else if ($labels != null) {
        let detail = $labels | each { |label|
            | get text
            # Not sure why this is in the middle of the error json...
            | str replace --all "originates from here" ''
        } | str join "\n"

        if ($message | str contains "Assertion failed") {
            let formatted = ($detail
                | str replace --all --regex '\n[ ]+Left' "|>Left"
                | str replace --all --regex '\n[ ]+Right' "|>Right"
                | str replace --all --regex '[\n\r]+' '\n'
                | str replace --all "|>" "\n|>")
                | str join ""
            [$message, ...($formatted | lines)] | str join "\n"
         } else {
            [$message, ...($detail | lines)] | str join "\n"
         }
    } else {
        $message
    }
}

