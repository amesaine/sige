// sige is built with these flags
// "-strict-style -vet -vet-unused-procedures -vet-cast -disallow-do"


package main


import "ast"
import "clangifier"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:os/os2"
import "core:path/filepath"


main :: proc() {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        defer mem.tracking_allocator_destroy(&track)
        context.allocator = mem.tracking_allocator(&track)
        defer {
                for _, leak in track.allocation_map {
                        fmt.printf("%v leaked %m\n", leak.location, leak.size)
                }
                for bad_free in track.bad_free_array {
                        fmt.printf(
                                "%v allocation %p was freed badly\n",
                                bad_free.location,
                                bad_free.memory,
                        )
                }
        }


        proj_init()


        assert(os.args[1] == "build")
        assert(os.is_dir(os.args[2]))
        dir, err_open := os.open(os.args[2])
        if err_open != nil {
                crash(err_open)
        }
        files, err_read := os.read_dir(dir, 0)
        if err_read != nil {
                crash(err_read)
        }
        defer os.file_info_slice_delete(files)
        for file in files {
                context.allocator = context.temp_allocator
                if file.is_dir {
                        fmt.printfln("Skipped directory %s", file.name)
                        continue
                }
                if filepath.ext(file.name) != ".sige" {
                        continue
                }
                // TODO: filename validation


                data :=
                        os.read_entire_file_from_filename(file.fullpath) or_else fmt.panicf(
                                "could not read %s",
                                file.fullpath,
                        )
                tree := ast.init(string(data))


                cwd, err_gwd := os2.get_working_directory(context.allocator)
                if err_gwd != nil {
                        crash(err_gwd)
                }
                file_relpath, err_rel := filepath.rel(cwd, file.fullpath)
                if err_rel != nil {
                        crash(err_rel)
                }
                src, header := clangifier.create_src_and_header_from_sige(file_relpath)
                defer {
                        os2.close(src)
                        os2.close(header)
                }
                clangifier.generate_from_ast(tree, src.stream)
        }
}


crash :: proc(err: any, loc := #caller_location) {
        fmt.panicf("%s\n\t%q\n", loc, err)
}


sige_out :: "./sige-out"
proj_init :: proc() {
        err_mkdir := os2.make_directory(sige_out)
        #partial switch t in err_mkdir {
        case os2.General_Error:
                if t != .Exist {
                        crash(err_mkdir)
                }
        case nil:
        case:
                crash(t)
        }
}
