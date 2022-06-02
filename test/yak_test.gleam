// IMPORTS ---------------------------------------------------------------------

import yak
import yak/ast
import yak/env
import yak/pkg/core

import gleam/option

import gleeunit
import gleeunit/should

// TESTS -----------------------------------------------------------------------

pub fn main () {
    gleeunit.main()
}

pub fn main_test () {
    let env = core.env()
    let script = [
        ast.let_("x", ast.number(2.0)),
        ast.let_("y", ast.block([
            ast.let_("x", ast.number(3.0)),
            ast.call(ast.var("core::add"), [ ast.var("x"), ast.number(1.0) ])
        ])),
        ast.call(ast.var("core::add"), [ ast.var("x"), ast.var("y") ])
    ]

    assert #(env, Ok(expr)) = yak.run(script, env)
    
    expr |> should.equal(ast.number(6.0))

    env  |> env.includes("x") |> should.be_true()
    env  |> env.lookup("x")   |> should.equal(option.Some(ast.number(2.0)))
    
    env  |> env.includes("y") |> should.be_true()
    env  |> env.lookup("y")   |> should.equal(option.Some(ast.number(4.0)))
    
    env  |> env.includes("z") |> should.be_false()
}
