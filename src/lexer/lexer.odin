package lexer


Lexer :: struct {
        source: string,
        index:  int,
}


Token :: struct {
        tag: TokenTag,
        loc: struct {
                start: int,
                end:   int,
        },
}


TokenTag :: enum {
        eof,
        bang,
        question,
        identifier,
        literal_number,
        literal_string,
        plus,
        minus,
        arrow_thin,
        arrow_fat,
        equal,
        less,
        less_equal,
        semicolon,
        colon,
        comma,
        period,
        ellipsis,
        carat,
        paren_left,
        paren_right,
        brace_left,
        brace_right,
        bracket_left,
        bracket_right,
        keyword_and,
        keyword_case,
        keyword_continue,
        keyword_dynamic,
        keyword_else,
        keyword_enum,
        keyword_fn,
        keyword_for,
        keyword_if,
        keyword_import,
        keyword_in,
        keyword_let,
        keyword_match,
        keyword_mut,
        keyword_package,
        keyword_return,
        keyword_struct,
        keyword_or,
        keyword_undefined,
        keyword_when,
        keyword_while,
}


keywords := map[string]TokenTag {
        "and"       = .keyword_and,
        "continue"  = .keyword_continue,
        "dynamic"   = .keyword_dynamic,
        "else"      = .keyword_else,
        "enum"      = .keyword_enum,
        "fn"        = .keyword_fn,
        "for"       = .keyword_for,
        "if"        = .keyword_if,
        "import"    = .keyword_import,
        "in"        = .keyword_in,
        "let"       = .keyword_let,
        "match"     = .keyword_match,
        "mut"       = .keyword_mut,
        "or"        = .keyword_or,
        "package"   = .keyword_package,
        "return"    = .keyword_return,
        "struct"    = .keyword_struct,
        "undefined" = .keyword_undefined,
        "when"      = .keyword_when,
        "while"     = .keyword_while,
}


types := []string {
        "any",
        "typeid",
        "bool",


        // String
        "string",
        "rune",


        // Floats
        "float",
        "f16",
        "f32",
        "f64",


        // Unsigned Integers
        "int",
        "u8",
        "u16",
        "u32",
        "u64",


        // Signed Integers
        "sint",
        "i8",
        "i16",
        "i32",
        "i64",
}


next :: proc(lxr: ^Lexer) -> Token {
        LexerState :: enum {
                start,
                literal_number,
                literal_string,
                identifier,
                minus,
                less,
                period,
        }


        result := Token {
                tag = .eof,
                loc = {start = lxr.index},
        }


        state := LexerState.start
        state_loop: for lxr.index < len(lxr.source) {
                switch state {
                case .start:
                        switch lxr.source[lxr.index] {
                        case:
                                unimplemented()
                        case ' ', '\t', '\n', '\r':
                                lxr.index += 1
                                result.loc.start = lxr.index
                        case 'a' ..= 'z', 'A' ..= 'Z', '_':
                                state = .identifier
                                result.tag = .identifier
                        case '0' ..= '9':
                                state = .literal_number
                                result.tag = .literal_number
                        case '"':
                                state = .literal_string
                                result.tag = .literal_string
                        case '.':
                                state = .period
                                result.tag = .period
                        case '+':
                                result.tag = .plus
                                lxr.index += 1
                                break state_loop
                        case '-':
                                state = .minus
                                result.tag = .minus
                        case '!':
                                result.tag = .bang
                                lxr.index += 1
                                break state_loop
                        case '?':
                                result.tag = .question
                                lxr.index += 1
                                break state_loop
                        case '=':
                                result.tag = .equal
                                lxr.index += 1
                                break state_loop
                        case '<':
                                state = .less
                                result.tag = .less
                        case ',':
                                result.tag = .comma
                                lxr.index += 1
                                break state_loop
                        case '^':
                                result.tag = .carat
                                lxr.index += 1
                                break state_loop
                        case ';':
                                result.tag = .semicolon
                                lxr.index += 1
                                break state_loop
                        case ':':
                                result.tag = .colon
                                lxr.index += 1
                                break state_loop
                        case '(':
                                result.tag = .paren_left
                                lxr.index += 1
                                break state_loop
                        case ')':
                                result.tag = .paren_right
                                lxr.index += 1
                                break state_loop
                        case '{':
                                result.tag = .brace_left
                                lxr.index += 1
                                break state_loop
                        case '}':
                                result.tag = .brace_right
                                lxr.index += 1
                                break state_loop
                        }
                case .literal_number:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case:
                                break state_loop
                        case '_', '0' ..= '9':
                        }
                case .literal_string:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case '\n':
                                panic("string literal unterminated")
                        case '"':
                                lxr.index += 1
                                break state_loop
                        case:
                        }
                case .identifier:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case:
                                ident := lxr.source[result.loc.start:lxr.index]
                                kw, ok := keywords[ident]
                                if ok {
                                        result.tag = kw
                                }
                                break state_loop
                        case 'a' ..= 'z', 'A' ..= 'Z', '_':
                        }
                case .minus:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case:
                        case '>':
                                result.tag = .arrow_thin
                                lxr.index += 1
                        }
                        break state_loop
                case .less:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case:
                        case '=':
                                result.tag = .less_equal
                                lxr.index += 1
                        }
                        break state_loop
                case .period:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case:
                        case '.':
                                result.tag = .ellipsis
                                lxr.index += 1
                        }
                        break state_loop
                }
        }
        result.loc.end = lxr.index
        return result
}
