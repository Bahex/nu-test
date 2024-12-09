# A reporter that collects results into a table

use store.nu

export def create [theme: closure]: nothing -> record {
    {
        start: { store create }
        complete: { store delete }
        success: { store success }
        results: { query-results $theme }
        fire-result: { |row| store insert-result $row }
        fire-output: { |row| store insert-output $row }
    }
}

def query-results [theme: closure]: nothing -> table<suite: string, test: string, result: string, output: string> {
    store query $theme | each { |row|
        {
            suite: $row.suite
            test: $row.test
            result: (format-result $row.result $theme)
            output: $row.output
        }
    }
}

def format-result [result: string, theme: closure]: nothing -> string {
    match $result {
        "PASS" => ({ type: "pass", text: $result } | do $theme)
        "SKIP" => ({ type: "skip", text: $result } | do $theme)
        "FAIL" => ({ type: "fail", text: $result } | do $theme)
        _ => $result
    }
}
