# Sige

Sige is a Golang alternative with a fundamentally different take on simplicity. It is opinionated,
procedural, and bare-bones to ensure a uniform developer experience.

## Hello World

```
package main

import "core:fmt"

fn main() {
    let name = "amesaine"
    fmt.println("hello world from {s}", name)
}
```

## What's different from Go?

- Compiles to C
- Interfaces are not first-class citizens
- No degenerate error types
- Unbounded functions (no methods)
- All declarations such as functions, variables, struct fields, etc. are always public.
- Const is default
- No variable shadowing
- Non-stack-capturing closures.

## License

Sige is under the permissive license BSD 3-Clause License.
