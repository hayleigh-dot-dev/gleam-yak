// IMPORTS ---------------------------------------------------------------------

import yak/expr.{Expr}
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
fn print () -> Expr {
    expr.fun([ "x" ], expr.extern(fn (env) {
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
fn add () -> Expr {
    expr.fun([ "x", "y" ], expr.extern(fn (env) {
        assert Ok(x) = map.get(env, "x")
        assert Ok(y) = map.get(env, "y")

        case x, y {
            expr.Lit(expr.Number(x)), expr.Lit(expr.Number(y)) ->
                expr.number(x +. y)
            
            expr.Lit(expr.Number(_)), _ ->
                expr.raise("...")

            _, _ ->
                expr.raise("...")
        }
    }))
}