// IMPORTS ---------------------------------------------------------------------

import yak
import yak/env
import yak/expr
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
        expr.let_("x", expr.number(2.0)),
        expr.let_("y", expr.block([
            expr.let_("x", expr.number(3.0)),
            expr.call(expr.var("core::add"), [ expr.var("x"), expr.number(1.0) ])
        ])),
        expr.call(expr.var("core::add"), [ expr.var("x"), expr.var("y") ])
    ]

    assert #(env, Ok(expr)) = yak.run(script, env)
    
    expr |> should.equal(expr.number(6.0))

    env  |> env.includes("x") |> should.be_true()
    env  |> env.lookup("x")   |> should.equal(option.Some(expr.number(2.0)))
    
    env  |> env.includes("y") |> should.be_true()
    env  |> env.lookup("y")   |> should.equal(option.Some(expr.number(4.0)))
    
    env  |> env.includes("z") |> should.be_false()
}
