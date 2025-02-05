package parser


import "../lexer"


Index :: distinct u32


// These are aliases instead of distinct types to minimize type casting and serves more as 
// documentation of what array the index is associated with.
IndexTokens :: Index
IndexNodes :: Index
IndexExtra :: Index
IndexPaths :: Index


// It is a deliberate choice to avoid solutions involving this type. Seems funky every single time.
@(private = "file")
IndexScratch :: Index


AstPackage :: struct {
        path_abs: string,
        imports:  []AstPackage,
        files:    []AstFile,
}


AstFile :: struct {
        path_abs: string,
        source:   string,
        tokens:   []lexer.Token,
        tk:       int,
        nodes:    []Node,


        // An array of indices into ParserFile.nodes or ParserFile.extra
        extra:    []Index,
        scratch:  []Index,
}


ParserPackage :: struct {
        path_abs: string,
        imports:  [dynamic]AstPackage,
        files:    [dynamic]AstFile,
}


ParserFile :: struct {
        fullpath: string,
        source:   string,
        tokens:   []lexer.Token,


        // Index of the next token in ParserFile.tokens.
        // Do tk - 1 to get the current token.
        // int type only because this field isnt prone to confusion in usage
        tk:       int,
        nodes:    [dynamic]Node,


        // An array of indices into ParserFile.nodes or ParserFile.extra
        extra:    [dynamic]Index,
        scratch:  [dynamic]Index,
}


Node :: struct {
        tag:        NodeTag,


        // An index into ParserFile.tokens.
        main_token: int,


        // lhs and rhs may be an IndexTokens, IndexNodes, IndexExtra.
        // Refer to NodeTag comments for the interpretation of each node.
        args:       struct {
                lhs: Index,
                rhs: Index,
        },
}


#assert(size_of(NodeTag) == size_of(byte))
NodeTag :: enum {
        INVALID,


        // main_token is the file's absolute path
        // lhs: Range.start(IndexExtra)
        // rhs: Range.end(IndexExtra)
        root,


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


        // struct ?identifier { <rhs> }
        // main_token = "struct"
        // lhs: IndexExtra.(Range.start)
        // rhs: IndexExtra.(Range.end)
        decl_struct,


        // enum(?identifier) ?identifier { <rhs> }
        // main_token = "enum"
        // lhs: IndexExtra.(Range.start)
        // rhs: IndexExtra.(Range.end)
        decl_enum,


        // union(?enum || ?identifier) ?identifier { <rhs> }
        // main_token = "union"
        // lhs: IndexExtra.(Range.start)
        // rhs: IndexExtra.(Range.end)
        decl_union,


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
        stmt_match,
        stmt_case,


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


// A range (exclusive) of indices into ParserFile.extras
Range :: struct {
        start: Index,
        end:   Index,
}


/// Similar to Range but the fields are the direct indices of the items.
/// It's more memory efficient than Range when you only need to associate 2 items with each other.
Pair :: struct {
        item1: Index,
        item2: Index,
}
