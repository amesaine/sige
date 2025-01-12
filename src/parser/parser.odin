package parser


import "../lexer"
import "core:fmt"


Parser :: struct {
        source:       string,
        tokens:       []lexer.Token,


        // Index of the next token in Parser.tokens.
        // Do tokens_index - 1 to get the current token.
        tokens_index: int,
        nodes:        [dynamic]Node,
        // An array of indices into Parser.nodes or Parser.extra
        extra:        [dynamic]Index,
        scratch:      [dynamic]Index,
}


Node :: struct {
        tag:        NodeTag,


        // An index into Parser.tokens
        main_token: int,


        // lhs and rhs may be an IndexTokens, IndexNodes, IndexExtra.
        // Refer to NodeTag comments for the interpretation of each node.
        args:       struct {
                lhs: Index,
                rhs: Index,
        },
}


Index :: distinct int


// These are aliases instead of distinct types to minimize type casting and serves more as 
// documentation of what array the index is associated with.
IndexTokens :: Index
IndexNodes :: Index
IndexExtra :: Index


// It is a deliberate choice to avoid solutions involving this type. Seems funky every single time.
@(private = "file")
IndexScratch :: Index


NodeTag :: enum {
        // root.args emulate Range.
        // main_token = 0
        // lhs: Range.start
        // rhs: Range.end
        root,
        package_,
        file,


        // let identifier: <?lhs> = <rhs>
        // main_token = "let"
        // lhs: optional IndexNodes.(type)
        // rhs: IndexNodes.(expr)
        decl_let,


        // package <lhs>
        // main_token = "package"
        // lhs is unused, rhs is unused
        decl_package,


        // import <lhs> "foo"
        // main_token = "import"
        // lhs: ?IndexTokens
        // rhs is unused
        decl_import,


        // fn (_ : <lhs>, ..., _ : <lhs+1>) -> (_ : <rhs>, ..., _ : <rhs+1>)
        // main_token = "fn"
        // lhs: ^Range
        // rhs: ^Range
        fn_prototype,


        // fn <lhs> { <rhs> }
        // main_token = "fn"
        // lhs: IndexNodes.(fn_prototype)
        // rhs: IndexNodes.(stmt_block)
        decl_fn,


        // stmt_block.args emulate Range.
        // main token = "{"
        // lhs: Range.start
        // rhs: Range.end
        stmt_block,


        // main token = "if"
        // if <lhs> { <rhs> }
        //       or
        // if let <lhs>; <lhs+1> { <rhs> }
        // lhs: IndexNodes.(expr or decl_let)
        // rhs: IndexNodes.(stmt_block)
        stmt_if,


        // main token = "if"
        // if <lhs> else <rhs>
        // lhs: IndexNodes.(stmt_if)
        // rhs: IndexNodes.(stmt_if_else or stmt_block)
        stmt_if_else,


        // main token = "for"
        // for identifier in <lhs> { <rhs> }
        // lhs: IndexNodes.(expr)
        // rhs: IndexNodes.(stmt_block)
        stmt_for,


        // main token = "for"
        // for identifier in <lhs> { <rhs.a> } else { <rhs.b> }
        // lhs: IndexNodes.(expr)
        // rhs: IndexExtra.(Pair)
        stmt_for_else,


        // main token = "while"
        // while let <?lhs.a>; <lhs.b>; <?lhs.c> for <?lhs.d> { 
        //         <rhs.a>
        // } else {
        //         <?rhs.b>
        // }
        // lhs: ^Range
        //      a: optional stmt_let
        //      b: condition expr
        //      c: optional continue expr
        //      d: optional bound expr
        // rhs: IndexNodes.(Pair)
        //      a: stmt_block
        //      b: optional stmt_block
        stmt_while,


        // main token = "return"
        // return <lhs>
        stmt_return,


        // EXPRESSIONS
        // main token = "("
        // lhs and rhs emulate Range.start and Range.end respectively
        // foo(<lhs>, ..<rhs>)
        expr_call,


        // lhs and rhs are unused
        // as much as possible, Nodes hold an IndexTokens instead of creating an identifier Node
        identifier,
        literal_number,
        literal_string,


        // OPERATORS
        // <lhs> op <rhs>
        op_add,
        op_sub,
        op_less,
        op_less_or_equal,


        // TYPES
        type_builtin,


        // main token = "^"
        // lhs is unused
        // rhs is unused
        ptr,


        // main token = "^"
        // ^mut <lhs>. 
        // lhs is unused
        // rhs is unused
        ptr_mutate,


        // main token = "["
        // []<lhs>. 
        // rhs is unused
        slice,


        // main token = "["
        // []mut <lhs>. 
        // rhs is unused
        slice_mutate,


        // main token = "["
        // [dynamic]<lhs>. 
        // rhs is unused
        slice_dynamic,
}


binding_power := #partial [lexer.TokenTag]int {
        .less       = 5,
        .less_equal = 5,
        .plus       = 6,
        .minus      = 6,
}


nodetag_from_optoken := #partial [lexer.TokenTag]NodeTag {
        .plus       = .op_add,
        .minus      = .op_sub,
        .less       = .op_less,
        .less_equal = .op_less_or_equal,
}


// A range (exclusive) of indices into Parser.extras
// You won't see this get instantiated anywhere. Rather, it gets emulated through indices.
Range :: struct {
        start: Index,
        end:   Index,
}


// Similar to Range but the fields are the direct indices of the items.
// This is used for memory efficiency when you only need to associate 2 items with each other.
// You won't see this get instantiated anywhere. Rather, it gets emulated through indices.
Pair :: struct {
        item1: Index,
        item2: Index,
}


parse :: proc(p: ^Parser) {
        assert(p != nil)
        assert(len(p.nodes) > 0)
        assert(p.nodes[0].tag == .root)


        before := len(p.scratch)
        defer resize(&p.scratch, before)


        loop: for {
                #partial switch peek_tk(p^).tag {
                case:
                        fmt.println(peek_tk(p^))
                        unimplemented()
                case .eof:
                        assert(p.tokens_index == len(p.tokens) - 1)
                        break loop
                case .keyword_package:
                        append(&p.scratch, parse_decl_package(p))
                case .keyword_fn:
                        append(&p.scratch, parse_decl_fn(p))
                case .keyword_let:
                        let := parse_decl_let(p)
                        append(&p.scratch, let)
                }
        }


        stmts := p.scratch[before:]
        append(&p.extra, ..stmts)
        p.nodes[0].args.lhs = Index(len(p.extra) - len(stmts))
        p.nodes[0].args.rhs = Index(len(p.extra))
}


parse_decl_package :: proc(p: ^Parser) -> IndexNodes {
        pkg := expect_next_tk(p, .keyword_package)
        expect_next_tk(p, .identifier)
        return append_node(p, Node{tag = .decl_package, main_token = pkg})
}


// takes a range for both params and return values which is inefficient
// TODO: make other node tags with a fixed param/return length
parse_fn_prototype :: proc(p: ^Parser) -> IndexNodes {
        before := len(p.scratch)
        defer assert(len(p.scratch) == before)


        fn := expect_next_tk(p, .keyword_fn)
        fn_prototype := append_node(p, Node{tag = .fn_prototype, main_token = fn})


        expect_next_tk(p, .identifier)
        expect_next_tk(p, .paren_left)
        {
                defer {
                        range := range_ptr_from_nodes(p, p.scratch[before:])
                        p.nodes[fn_prototype].args.lhs = range
                        resize(&p.scratch, before)
                }
                #partial switch peek_tk(p^).tag {
                case:
                        unimplemented()
                case .identifier:
                        for {
                                expect_next_tk(p, .identifier)
                                expect_next_tk(p, .colon)
                                type := parse_type(p)
                                append(&p.scratch, IndexNodes(type))
                                if !next_tk_is(p, .comma) {
                                        break
                                }
                        }
                case .paren_right:
                        next_tk(p)
                }
        }


        if next_tk_is(p, .arrow_thin) {
                defer {
                        assert(len(p.scratch[before:]) > 0)
                        range := range_ptr_from_nodes(p, p.scratch[before:])
                        p.nodes[fn_prototype].args.rhs = range
                        resize(&p.scratch, before)
                }


                if next_tk_is(p, .paren_left) {
                        defer {
                                expect_next_tk(p, .paren_right)
                                assert(len(p.scratch[before:]) > 1)
                        }
                        for {
                                append(&p.scratch, parse_type(p))
                                if !next_tk_is(p, .comma) {
                                        break
                                }
                        }
                } else {
                        append(&p.scratch, parse_type(p))
                }
        }
        return fn_prototype
}


parse_decl_fn :: proc(p: ^Parser) -> IndexNodes {
        fn := expect_next_tk(p, .keyword_fn)
        decl_fn := append_node(p, Node{tag = .decl_fn, main_token = fn})
        defer assert(p.nodes[decl_fn].args.lhs != p.nodes[decl_fn].args.rhs)


        expect_next_tk(p, .identifier)
        {fn_prototype := parse_fn_prototype(p)
                assert(fn_prototype != 0)
                p.nodes[decl_fn].args.lhs = fn_prototype
        }
        {block := parse_stmt_block(p)
                assert(block < Index(len(p.nodes)))
                p.nodes[decl_fn].args.rhs = IndexNodes(block)}


        return decl_fn
}


parse_type :: proc(p: ^Parser) -> IndexNodes {
        tk := next_tk(p)
        type := append_node(p, {tag = .identifier, main_token = tk})


        #partial switch p.tokens[tk].tag {
        case:
                unimplemented()
        case .identifier:
        case .carat:
                p.nodes[type].tag = .ptr
                if next_tk_is(p, .keyword_mut) {
                        p.nodes[type].tag = .ptr_mutate
                }
                expect_next_tk(p, .identifier)
        case .bracket_left:
                p.nodes[type].tag = .slice
                if next_tk_is(p, .keyword_dynamic) {
                        p.nodes[type].tag = .slice_dynamic
                }
                expect_next_tk(p, .bracket_right)
                if next_tk_is(p, .keyword_mut) {
                        assert(p.nodes[type].tag == .slice)
                        p.nodes[type].tag = .slice_mutate
                }
                expect_next_tk(p, .identifier)
        }
        return IndexNodes(len(p.nodes) - 1)
}


parse_stmt_block :: proc(p: ^Parser) -> IndexNodes {
        before := len(p.scratch)
        defer resize(&p.scratch, before)


        brace_left := expect_next_tk(p, .brace_left)
        stmt_block := append_node(p, Node{tag = .stmt_block, main_token = brace_left})
        defer assert(p.nodes[stmt_block].args.lhs <= p.nodes[stmt_block].args.rhs)


        for !next_tk_is(p, .brace_right) {
                append(&p.scratch, parse_stmt(p))
        }
        stmts := p.scratch[before:]
        append(&p.extra, ..stmts)


        start := IndexExtra(before)
        end := IndexExtra(len(p.extra))
        p.nodes[stmt_block].args.lhs = start
        p.nodes[stmt_block].args.rhs = end


        return stmt_block
}


parse_stmt :: proc(p: ^Parser) -> IndexNodes {
        #partial switch peek_tk(p^).tag {
        case:
                fmt.println(peek_tk(p^))
                unimplemented()
        case .brace_left:
                return parse_stmt_block(p)
        case .keyword_let:
                return parse_decl_let(p)
        case .identifier:
                next_tk(p)
                #partial switch paren := peek_tk(p^); paren.tag {
                case:
                        unimplemented()
                case .paren_left:
                        return parse_fn_call(p)
                }
        case .keyword_if:
                return parse_stmt_if(p)
        case .keyword_for:
                return parse_stmt_for(p)
        case .keyword_while:
                return parse_stmt_while(p)
        case .keyword_return:
                return parse_stmt_return(p)
        }
        return 0
}


parse_stmt_return :: proc(p: ^Parser) -> IndexNodes {
        return_ := expect_next_tk(p, .keyword_return)
        return_value := parse_expr(p)
        stmt_return := append_node(
                p,
                {tag = .stmt_return, main_token = return_, args = {lhs = return_value}},
        )
        return stmt_return
}


parse_stmt_if :: proc(p: ^Parser) -> IndexNodes {
        if_ := expect_next_tk(p, .keyword_if)
        stmt_if := append_node(p, {tag = .stmt_if, main_token = if_})
        is_decl_if_let := next_tk_is(p, .keyword_let)
        if is_decl_if_let {
                p.nodes[stmt_if].args.lhs = parse_decl_let(p)
                expect_next_tk(p, .semicolon)
        }
        if condition := parse_expr(p); !is_decl_if_let {
                p.nodes[stmt_if].args.lhs = condition
        }


        if !next_tk_is(p, .keyword_else) {
                return stmt_if
        }


        simple := append_node(p, p.nodes[stmt_if])
        p.nodes[stmt_if].args.lhs = simple
        if next_tk_is(p, .keyword_if) {
                p.nodes[stmt_if].args.rhs = parse_stmt_if(p)
        } else {
                p.nodes[stmt_if].args.rhs = parse_stmt_block(p)
        }


        return stmt_if
}


parse_stmt_for :: proc(p: ^Parser) -> IndexNodes {
        for_ := expect_next_tk(p, .keyword_for)
        stmt_for := append_node(p, {tag = .stmt_for, main_token = for_})
        expect_next_tk(p, .identifier)
        for !next_tk_is(p, .comma) {
                expect_next_tk(p, .identifier)
        }
        expect_next_tk(p, .keyword_in)
        p.nodes[stmt_for].args = {
                lhs = parse_expr(p),
                rhs = parse_stmt_block(p),
        }
        if next_tk_is(p, .keyword_else) {
                p.nodes[stmt_for].tag = .stmt_for_else
                else_block := parse_stmt_block(p)
                pair := pair_from_nodes(p, p.nodes[stmt_for].args.rhs, else_block)
                p.nodes[stmt_for].args.rhs = pair
        }
        return stmt_for
}


parse_stmt_while :: proc(p: ^Parser) -> IndexNodes {
        while := expect_next_tk(p, .keyword_while)
        stmt_while := append_node(p, {tag = .stmt_while, main_token = while})


        {
                decl_let: IndexNodes
                if next_tk_is(p, .keyword_let) {
                        decl_let = parse_decl_let(p)
                        expect_next_tk(p, .semicolon)
                }
                condition := parse_expr(p)
                continue_expr: IndexNodes
                if next_tk_is(p, .semicolon) {
                        continue_expr = parse_expr(p)
                }
                bound: IndexNodes
                if next_tk_is(p, .keyword_for) {
                        bound = parse_expr(p)
                }
                range := range_ptr_from_nodes(p, {decl_let, condition, continue_expr, bound})
                p.nodes[stmt_while].args.lhs = range
        }
        {
                block := parse_stmt_block(p)
                else_block: IndexNodes
                if next_tk_is(p, .keyword_else) {
                        else_block = parse_stmt_block(p)
                }
                pair_from_nodes(p, block, else_block)
        }
        return stmt_while
}


parse_decl_import :: proc(p: ^Parser) -> IndexNodes {
        import_ := expect_next_tk(p, .keyword_import)
        decl_import := append_node(p, {tag = .decl_import, main_token = import_})
        if next_tk_is(p, .identifier) {
                p.nodes[decl_import].args.lhs = IndexTokens(p.tokens_index - 1)
        }
        expect_next_tk(p, .literal_string)
        return decl_import
}


parse_decl_let :: proc(p: ^Parser) -> IndexNodes {
        let := expect_next_tk(p, .keyword_let)
        decl_let := append_node(p, Node{tag = .decl_let, main_token = let})
        expect_next_tk(p, .identifier)


        if next_tk_is(p, .colon) {
                type := parse_type(p)
                p.nodes[decl_let].args.lhs = type
        }


        expect_next_tk(p, .equal)
        p.nodes[decl_let].args.rhs = parse_expr(p)


        return decl_let
}


parse_expr :: proc(p: ^Parser, min_bp := 0) -> IndexNodes {
        root: IndexNodes


        #partial switch tk := p.tokens[next_tk(p)]; tk.tag {
        case .literal_number:
                root = append_node(p, {tag = .literal_number})
        case .literal_string:
                root = append_node(p, {tag = .literal_string})
        case .identifier:
                p.nodes[root].tag = .identifier
                if peek_tk(p^).tag == .paren_left {
                        root = parse_fn_call(p)
                }
        case:
                unimplemented()
        }


        loop: for {
                tk := peek_tk(p^)
                bp := binding_power[tk.tag]
                if bp == 0 || min_bp > bp {
                        break loop
                }
                i := next_tk(p)


                {old_root := append_node(p, p.nodes[root])
                        p.nodes[root] = {
                                main_token = i,
                                args = {lhs = old_root},
                        }
                }


                #partial switch tk.tag {
                case .plus, .minus, .less_equal, .less:
                        p.nodes[root].tag = nodetag_from_optoken[tk.tag]
                        assert(p.nodes[root].tag != NodeTag.root)
                        right_i := parse_expr(p, bp)
                        p.nodes[root].args.rhs = IndexNodes(right_i)
                case .eof:
                case:
                        unimplemented()
                }
                break
        }
        return root
}


// assumes that the parser is past the function identifier
parse_fn_call :: proc(p: ^Parser) -> (fn_call: IndexNodes) {
        fn_call = append_node(p, Node{tag = .expr_call, main_token = p.tokens_index})


        expect_next_tk(p, .paren_left)
        if next_tk_is(p, .paren_right) {
                return
        }
        defer assert(p.nodes[fn_call].args.lhs < p.nodes[fn_call].args.rhs)


        before := len(p.scratch)
        for {
                append(&p.scratch, parse_expr(p))
                if next_tk_is(p, .paren_right) {
                        break
                }
                expect_next_tk(p, .comma)
        }
        start, end := range_from_nodes(p, p.scratch[before:])
        p.nodes[fn_call].args = {
                lhs = start,
                rhs = end,
        }


        return fn_call
}


peek_tk :: proc(p: Parser) -> lexer.Token {
        assert(len(p.tokens) > 0)
        assert(p.tokens_index < len(p.tokens))
        return p.tokens[p.tokens_index]
}


next_tk :: proc(p: ^Parser) -> int {
        assert(p != nil)
        assert(p^.tokens_index < len(p^.tokens))


        tk_i := p.tokens_index
        p^.tokens_index += 1
        return tk_i
}


ErrorInvalidLiteralNumber :: enum {}
// TODO: base this on some standard (IEEE?)
check_literal_number :: proc(
        number: string,
        loc := #caller_location,
) -> ErrorInvalidLiteralNumber {
        State :: enum {
                start,
                period,
                binary,
                octal,
                decimal,
                hexadecimal,
                prefix_zero,
        }


        index: int
        state := State.start
        state_loop: for index < len(number) {
                #partial switch state {
                case .start:
                        switch number[index] {
                        case:
                                panic("invalid first digit", loc)
                        case '0':
                                state = .prefix_zero
                        case '1' ..= '9':
                                state = .decimal
                        }
                case .prefix_zero:
                        index += 1
                        switch number[index] {
                        case 'b':
                                state = .binary
                                index += 1
                        case 'o':
                                state = .octal
                                index += 1
                        case 'x':
                                state = .hexadecimal
                                index += 1
                        case '0' ..= '9':
                                state = .decimal
                        }
                case .binary:
                        switch number[index] {
                        case '0' ..= '1', '_':
                                index += 1
                        }
                case .octal:
                        switch number[index] {
                        case '0' ..= '7', '_':
                                index += 1
                        }
                case .decimal:
                        switch number[index] {
                        case '0' ..= '9', '_':
                                index += 1
                        }
                case .hexadecimal:
                        switch number[index] {
                        case '0' ..= '9', 'A' ..= 'F', 'a' ..= 'f':
                                index += 1
                        }
                }
        }
        return nil
}


next_tk_is :: proc(p: ^Parser, tag: lexer.TokenTag) -> bool {
        ok := peek_tk(p^).tag == tag
        if ok {
                next_tk(p)
        }
        return ok
}


expect_next_tk :: proc(p: ^Parser, tag: lexer.TokenTag, loc := #caller_location) -> int {
        tk := next_tk(p)
        assert(tk < len(p.tokens), loc = loc)
        assert(p.tokens[tk].tag == tag, loc = loc)
        return tk
}


// Appends multiple nodes to parser.extra. Used for when a list of nodes is not guaranteed
// to be next to each other. 
range_from_nodes :: proc(
        p: ^Parser,
        indices: []IndexNodes,
        loc := #caller_location,
) -> (
        start: IndexExtra,
        end: IndexExtra,
) {
        if len(indices) == 0 {
                return
        }


        start = IndexExtra(len(p.extra))
        end = start + IndexExtra(len(indices))


        append(&p.extra, ..indices)
        return start, end
}


// The range struct itself is stored in parser.extra. The returned index acts as a pointer to the
// range. To visualize:
//      Range{
//              start = parser.extra[ptr],
//              end   = parser.extra[ptr + 1],
//      }
range_ptr_from_nodes :: proc(
        p: ^Parser,
        indices: []IndexNodes,
        loc := #caller_location,
) -> (
        ptr: IndexExtra,
) {
        start, end := range_from_nodes(p, indices)
        append(&p.extra, start, end)
        ptr = IndexExtra(len(p.extra) - 2)
        return ptr
}


// See Pair :: struct {...} for more information.
pair_from_nodes :: proc(
        p: ^Parser,
        node1: IndexNodes,
        node2: IndexNodes,
        loc := #caller_location,
) -> (
        ptr: IndexExtra,
) {
        assert(node1 != node2)
        ptr = IndexExtra(len(p.extra))
        append(&p.extra, node1, node2)
        return ptr
}


// returns the index of the appended node
append_node :: proc(p: ^Parser, node: Node) -> IndexNodes {
        append(&p.nodes, node)
        return IndexNodes(len(p.nodes) - 1)
}
