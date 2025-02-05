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
        arrow_fat,
        arrow_thin,
        bang,
        brace_left,
        brace_right,
        bracket_left,
        bracket_right,
        carat,
        colon,
        comma,
        comment,
        ellipsis,
        equal,
        greater,
        greater_equal,
        identifier,
        less,
        less_equal,
        literal_number,
        literal_string,
        minus,
        paren_left,
        paren_right,
        period,
        plus,
        question,
        semicolon,
        slash,
        keyword_and,
        keyword_break,
        keyword_case,
        keyword_continue,
        keyword_dynamic,
        keyword_distinct,
        keyword_else,
        keyword_enum,
        keyword_union,
        keyword_fallthrough,
        keyword_fn,
        keyword_for,
        keyword_if,
        keyword_import,
        keyword_in,
        keyword_let,
        keyword_map,
        keyword_match,
        keyword_mut,
        keyword_package,
        keyword_return,
        keyword_struct,
        keyword_or,
        keyword_when,
        keyword_while,
}


keywords :: proc(str: string) -> TokenTag {
        switch str {
        case:
                return nil
        case "and":
                return .keyword_and
        case "break":
                return .keyword_break
        case "case":
                return .keyword_case
        case "continue":
                return .keyword_continue
        case "distinct":
                return .keyword_distinct
        case "dynamic":
                return .keyword_dynamic
        case "else":
                return .keyword_else
        case "enum":
                return .keyword_enum
        case "fallthrough":
                return .keyword_fallthrough
        case "fn":
                return .keyword_fn
        case "for":
                return .keyword_for
        case "if":
                return .keyword_if
        case "import":
                return .keyword_import
        case "in":
                return .keyword_in
        case "let":
                return .keyword_let
        case "match":
                return .keyword_match
        case "map":
                return .keyword_map
        case "mut":
                return .keyword_mut
        case "or":
                return .keyword_or
        case "package":
                return .keyword_package
        case "return":
                return .keyword_return
        case "struct":
                return .keyword_struct
        case "when":
                return .keyword_when
        case "while":
                return .keyword_while
        }
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
        "byte",
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
                slash,
                greater,
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
                        case '/':
                                state = .slash
                                result.tag = .slash
                        case '>':
                                state = .greater
                                result.tag = .greater
                        case '<':
                                state = .less
                                result.tag = .less
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
                                kw := keywords(ident)
                                if kw != nil {
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
                case .greater:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case:
                        case '=':
                                result.tag = .greater_equal
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
                case .slash:
                        lxr.index += 1
                        switch lxr.source[lxr.index] {
                        case:
                        case '/':
                                result.tag = .comment
                                lxr.index += 1
                        }
                        break state_loop
                }
        }
        result.loc.end = lxr.index
        return result
}
