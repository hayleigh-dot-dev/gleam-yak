// IMPORTS ---------------------------------------------------------------------

import yak/ast.{Ast}
import yak/env.{Env}

import gleam/io
import gleam/map

//

///
///
pub fn env () -> Env {
    env.from_list([
        #("core::print", print()),
        #("core::add", add())
    ])
}

//

///
///
fn print () -> Ast {
    ast.fun([ "x" ], ast.extern(fn (env) {
        // If `x` isn't in the environment at this point, then we have an
        // implementation error in the interpreter – we don't want to raise a
        // yak error here we want things to break!
        assert Ok(x) = map.get(env, "x")

        io.debug(x)
    }))
}

//

///
///
fn add () -> Ast {
    ast.fun([ "x", "y" ], ast.extern(fn (env) {
        assert Ok(x) = map.get(env, "x")
        assert Ok(y) = map.get(env, "y")

        case x, y {
            ast.Lit(ast.Number(x)), ast.Lit(ast.Number(y)) ->
                ast.number(x +. y)
            
            ast.Lit(ast.Number(_)), _ ->
                ast.raise("...")

            _, _ ->
                ast.raise("...")
        }
    }))
}