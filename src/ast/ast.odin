package ast


Ast :: struct {
        source: string,
        tokens: []lexer.Token,
        nodes:  []parser.Node,


        // An array of indices into Ast.nodes or Ast.Extra itself
        extra:  []IndexNodes,
}


Index :: parser.Index
IndexTokens :: parser.Index
IndexNodes :: parser.Index
IndexExtra :: parser.Index


dump :: proc(ast: Ast) {
        fmt.println(ast.source)
        for x, i in ast.tokens {
                fmt.print('[')
                fmt.println(i, x, sep = "] ")
        }
        fmt.println()
        for x, i in ast.nodes {
                fmt.print('[')
                fmt.println(i, x, sep = "] ")
        }
        fmt.println()
        for x, i in ast.extra {
                fmt.printfln("[%d] %d", i, x)
        }
        fmt.println("===========")
}


init :: proc(source: string, allocator := context.allocator) -> Ast {
        lxr := lexer.Lexer {
                source = source,
        }


        tokens := make([dynamic]lexer.Token)
        for {
                tk := lexer.next(&lxr)
                append(&tokens, tk)
                if tk.tag == .eof {
                        break
                }
        }


        p := parser.Parser {
                source = source,
                tokens = tokens[:],
                nodes  = make([dynamic]parser.Node),
                extra  = make([dynamic]IndexNodes),
        }
        append(&p.nodes, parser.Node{tag = .root})
        parser.parse(&p)


        ast := Ast {
                source = source,
                tokens = tokens[:],
                nodes  = p.nodes[:],
                extra  = p.extra[:],
        }


        return ast
}


destroy :: proc(p: ^Ast) -> runtime.Allocator_Error {
        delete(p.tokens) or_return
        delete(p.nodes) or_return
        delete(p.extra) or_return
        return nil
}


to_string :: proc(ast: Ast, w: io.Writer) -> io.Error {
        root := ast.nodes[0]
        assert(root.tag == .root)


        io.write_byte(w, '(') or_return
        global_stmts := ast.extra[root.args.lhs:root.args.rhs]
        for i in global_stmts {
                fmt.wprintln(w)
                to_string_recursive(ast, IndexNodes(i), w) or_return
        }
        fmt.wprintln(w)
        io.write_byte(w, ')') or_return


        return nil
}


to_string_recursive :: proc(ast: Ast, node: IndexNodes, w: io.Writer) -> io.Error {
        assert(int(node) < len(ast.nodes))
        assert(node != 0)
        node := ast.nodes[node]


        is_atom_node := node.args == {}
        {
                tk := ast.tokens[node.main_token_i]
                str := ast.source[tk.loc.start:tk.loc.end]


                if !is_atom_node {
                        io.write_byte(w, '(')
                }
                n := io.write_string(w, str) or_return
                assert(n == len(str))
        }
        if is_atom_node {
                return nil
        }


        io.write_byte(w, ' ') or_return
        #partial switch node.tag {
        case:
                fmt.println(node.tag)
                unimplemented()
        case .decl_package:
                ident := ast.tokens[node.args.lhs]
                io.write_string(w, ast.source[ident.loc.start:ident.loc.end])
        case .decl_fn:
                if node.args.lhs != 0 {
                        extra := nodes_from_subrange(
                                ast,
                                start = IndexExtra(node.args.lhs),
                                end = IndexExtra(node.args.lhs + 2),
                        )
                        for node in extra {
                                to_string_recursive(ast, IndexNodes(node), w)
                                io.write_byte(w, ' ') or_return
                        }
                }
                to_string_recursive(ast, node.args.rhs, w)
        case .decl_let:
                ident := ast.tokens[node.args.lhs]
                io.write_string(w, ast.source[ident.loc.start:ident.loc.end])
                io.write_byte(w, ' ')
                to_string_recursive(ast, node.args.rhs, w) or_return
        case .stmt_block:
                stmts := ast.extra[node.args.lhs:node.args.rhs]
                for stmt in stmts {
                        to_string_recursive(ast, IndexNodes(stmt), w) or_return
                }
        case .stmt_if:
                to_string_recursive(ast, node.args.lhs, w)
                to_string_recursive(ast, node.args.rhs, w)
        case .stmt_return:
                to_string_recursive(ast, node.args.lhs, w) or_return
        case .expr_call:
                ident := ast.tokens[node.main_token_i - 1]
                io.write_string(w, ast.source[ident.loc.start:ident.loc.end])
                io.write_byte(w, ' ')
                call_args := nodes_from_subrange(ast, node.args.lhs, node.args.rhs)
                for arg in call_args {
                        to_string_recursive(ast, IndexNodes(arg), w) or_return
                        io.write_byte(w, ' ')
                }
        case .op_add, .op_sub, .op_less_or_equal, .op_less:
                to_string_recursive(ast, node.args.lhs, w) or_return
                io.write_byte(w, ' ')
                to_string_recursive(ast, node.args.rhs, w) or_return
        }
        io.write_byte(w, ')') or_return
        return nil
}


nodes_from_subrange :: proc(
        tree: Ast,
        start, end: IndexExtra,
        loc := #caller_location,
) -> []IndexNodes {
        assert(int(start) < len(tree.extra), loc = loc)
        assert(start < end, loc = loc)


        assert(int(start) < len(tree.extra), loc = loc)
        assert(int(end) < len(tree.extra), loc = loc)
        nodes := tree.extra[start:end]
        return nodes
}


Decl_Fn_Node :: struct {
        identifier: IndexTokens,
        params:     []IndexNodes,
        stmt_block: IndexNodes,
}


import "../lexer"
import "../parser"
import "base:runtime"
import "core:fmt"
import "core:io"
