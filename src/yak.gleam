// IMPORTS ---------------------------------------------------------------------

import yak/ast.{Ast}
import yak/env.{Env}

import gleam/list
import gleam/option
import gleam/map.{Map}
import gleam/result

import eval
import eval/context

// TYPES -----------------------------------------------------------------------

pub type Error {
    TypeError(expected: ast.Type, got: ast.Type)
    Exception(message: String)
    OutOfScope(name: String)
}

type Eval(a) =
    eval.Eval(a, Error, Env)

// 

pub fn run (exprs: List(Ast), env: Env) -> #(Env, Result(Ast, Error)) {
    step_all(exprs)
        |> eval.map(list.last)
        |> eval.map(result.unwrap(_, ast.undefined()))
        |> eval.step(env)
}

fn step (expr: Ast) -> Eval(Ast) {
    case expr {
        ast.Block(expressions) ->
            block(expressions)
        
        ast.Call(function, argument) ->
            call(function, argument)
        
        ast.Extern(function) ->
            extern(function)
        
        ast.Fun(name, body) ->
            fun(name, body)
        
        ast.If(condition, then, else) ->
            if_(condition, then, option.unwrap(else, ast.undefined()))
        
        ast.Let(name, body) ->
            let_(name, body)
        
        ast.Lit(literal) ->
            lit(literal)
        
        ast.Var(name) ->
            var(name)
    }
}

pub fn step_all (exprs: List(Ast)) -> Eval(List(Ast)) {
    list.map(exprs, step)
        |> eval.all
}


fn block (exprs: List(Ast)) -> Eval(Ast) {
    context.get() |> eval.then(fn (env) { 
        step_all(exprs)
            |> eval.map(list.last)
            |> eval.map(result.unwrap(_, ast.undefined()))
            |> context.then_set(env)
    })
}

fn call (function: Ast, argument: Ast) -> Eval(Ast) {
    step(function) |> eval.then(fn (expr) {
        case expr {
            ast.Fun(name, body) -> {
                step(argument) |> eval.then(fn (expr) {
                    ast.substitute(body, name, expr)
                        |> step
                })
            }
            
            _ ->
                typeof(expr)
                    |> eval.then(fn (t) { eval.throw(TypeError(ast.FunctionT, t)) })
        }
    })
}

fn extern (function: fn(Map(String, Ast)) -> Ast) -> Eval(Ast) {
    context.get()
        |> eval.map(env.to_map)
        |> eval.map(function)
        |> eval.then(step)
}

fn fun (name: String, body: Ast) -> Eval(Ast) {
    eval.succeed(ast.fun([ name ], body))
}

fn if_ (condition: Ast, then: Ast, else: Ast) -> Eval(Ast) {
    step(condition)
        |> eval.map(ast.coerce_to_boolean)
        |> eval.then(fn (b) {
            case b {
                True ->
                    step(then)

                False ->
                    step(else)
            }
        })
}

fn let_ (name: String, body: Ast) -> Eval(Ast) {
    step(body) |> context.update(fn (env, expr) { 
        env.push(env, name, expr) 
    })
}

fn lit (literal: ast.Literal(Ast)) -> Eval(Ast) {
    case literal {
        ast.Array(elements) ->
            step_all(elements)
                |> eval.map(ast.array)

        ast.Exception(message) ->
            eval.throw(Exception(message))
         
        ast.Record(fields) -> {
            let step_field = fn (field) {
                let #(key, expr) = field
                step(expr) |> eval.map(fn (expr) { #(key, expr) })
            }

            list.map(fields, step_field)
                |> eval.all
                |> eval.map(ast.record)
        }

        _ ->
            eval.succeed(ast.Lit(literal))
    }
}

fn var (name: String) -> Eval(Ast) {
    context.get()
        |> eval.map(env.lookup(_, name))
        |> eval.then(fn (expr) {
            case expr {
                option.Some(expr) ->
                    eval.succeed(expr)
                
                option.None ->
                    eval.throw(OutOfScope(name))
            }
        })
}

// QUERIES ---------------------------------------------------------------------

fn typeof (expr: Ast) -> Eval(ast.Type) {
    case ast.simple_typeof(expr) {
        option.Some(t) ->
            eval.succeed(t)
        
        option.None ->
            step(expr) |> eval.then(typeof)
    }
}

// MEMES -----------------------------------------------------------------------

pub fn shave () {
    shave()
}
