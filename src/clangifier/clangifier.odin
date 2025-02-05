package clangifier


import "../ast"
import "../parser"
import "core:fmt"
import "core:io"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"


OUT_BASE_DIR :: "./sige-out"


generate_from_ast :: proc(tree: ast.Ast, w: io.Writer) {
        root := tree.nodes[0]
        assert(root.tag == .root)
        stmts := ast.nodes_from_subrange(tree, root.args.lhs, root.args.rhs)
        for stmt in stmts {
                node := tree.nodes[stmt]
                generate(w, tree, node, .decl_fn)
        }
}


generate :: proc(w: io.Writer, tree: ast.Ast, node: parser.Node, tag: parser.NodeTag) {
        assert(node.tag == tag)
        #partial switch tag {
        case:
                unimplemented()
        case .decl_fn:
                fn_data := ast.nodes_from_subrange(tree, node.args.lhs, node.args.rhs)
        }
}


// caller must call os2.close
create_src_and_header_from_sige :: proc(
        target: string, // relative path
        loc := #caller_location,
) -> (
        src: ^os2.File,
        header: ^os2.File,
) {
        assert(target != "", loc = loc)
        assert(!filepath.is_abs(target), loc = loc)
        defer {
                assert(src != nil, loc = loc)
                assert(header != nil, loc = loc)
                assert(src != header, loc = loc)
        }
        context.allocator = context.temp_allocator


        target_dir := filepath.dir(target)
        target_stem := filepath.stem(target)
        out_dir := filepath.join({OUT_BASE_DIR, target_dir})


        err_s: os2.Error
        src, err_s = os2.create(filepath.join({out_dir, strings.join({target_stem, ".c"}, "")}))
        if err_s != nil {
                crash(err_s)
        }


        err_h: os2.Error
        header, err_h = os2.create(filepath.join({out_dir, strings.join({target_stem, ".h"}, "")}))
        if err_h != nil {
                crash(err_s)
        }


        return src, header
}


crash :: proc(err: any, loc := #caller_location) {
        fmt.panicf("%s\n\t%q\n", loc, err)
}
