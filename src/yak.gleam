// IMPORtS ---------------------------------------------------------------------

import yak/expr.{Expr}
import yak/env.{Env}

import gleam/list
import gleam/option
import gleam/map.{Map}
import gleam/result

import eval
import eval/context

// TYPES -----------------------------------------------------------------------

pub type Error {
    TypeError(expected: expr.Type, got: expr.Type)
    Exception(message: String)
    OutOfScope(name: String)
}

type Eval(a) =
    eval.Eval(a, Error, Env)

// 

/// A yak script is a collection of expressions evaluated in sequence, and an
/// initial environment containing all of the bindings accessible to the script.
///
/// What we get back is the resulting environment, updated to include any new
/// `Let` bindings that may have been introduced. We also get back a result that
/// tells us whether the script was successful or not. You can check out the
/// [`Error`](#Error) type for a look at what runtime errors are possible in yak.
///
pub fn run (exprs: List(Expr), env: Env) -> #(Env, Result(Expr, Error)) {
    step_all(exprs)
        |> eval.map(list.last)
        |> eval.map(result.unwrap(_, expr.undefined()))
        |> eval.step(env)
}

fn step (expr: Expr) -> Eval(Expr) {
    case expr {
        expr.Block(expressions) ->
            block(expressions)
        
        expr.Call(function, argument) ->
            call(function, argument)
        
        expr.Extern(function) ->
            extern(function)
        
        expr.Fun(name, body) ->
            fun(name, body)
        
        expr.If(condition, then, else) ->
            if_(condition, then, option.unwrap(else, expr.undefined()))
        
        expr.Let(name, body) ->
            let_(name, body)
        
        expr.Lit(literal) ->
            lit(literal)
        
        expr.Var(name) ->
            var(name)
    }
}

fn step_all (exprs: List(Expr)) -> Eval(List(Expr)) {
    list.map(exprs, step)
        |> eval.all
}


fn block (exprs: List(Expr)) -> Eval(Expr) {
    context.get() |> eval.then(fn (env) { 
        step_all(exprs)
            |> eval.map(list.last)
            |> eval.map(result.unwrap(_, expr.undefined()))
            |> context.then_set(env)
    })
}

fn call (function: Expr, argument: Expr) -> Eval(Expr) {
    step(function) |> eval.then(fn (expr) {
        case expr {
            expr.Fun(name, body) -> {
                step(argument) |> eval.then(fn (expr) {
                    expr.substitute(body, name, expr, False)
                        |> step
                })
            }
            
            _ ->
                typeof(expr)
                    |> eval.then(fn (t) { eval.throw(TypeError(expr.FunctionT, t)) })
        }
    })
}

fn extern (function: fn(Map(String, Expr)) -> Expr) -> Eval(Expr) {
    context.get()
        |> eval.map(env.to_map)
        |> eval.map(function)
        |> eval.then(step)
}

fn fun (name: String, body: Expr) -> Eval(Expr) {
    eval.succeed(expr.fun([ name ], body))
}

fn if_ (condition: Expr, then: Expr, else: Expr) -> Eval(Expr) {
    step(condition)
        |> eval.map(expr.coerce_to_boolean)
        |> eval.then(fn (b) {
            case b {
                True ->
                    step(then)

                False ->
                    step(else)
            }
        })
}

fn let_ (name: String, body: Expr) -> Eval(Expr) {
    step(body) |> context.update(fn (env, expr) { 
        env.push(env, name, expr) 
    })
}

fn lit (literal: expr.Literal(Expr)) -> Eval(Expr) {
    case literal {
        expr.Array(elements) ->
            step_all(elements)
                |> eval.map(expr.array)

        expr.Exception(message) ->
            eval.throw(Exception(message))
         
        expr.Record(fields) -> {
            let step_field = fn (field) {
                let #(key, expr) = field
                step(expr) |> eval.map(fn (expr) { #(key, expr) })
            }

            list.map(fields, step_field)
                |> eval.all
                |> eval.map(expr.record)
        }

        _ ->
            eval.succeed(expr.Lit(literal))
    }
}

fn var (name: String) -> Eval(Expr) {
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

fn typeof (expr: Expr) -> Eval(expr.Type) {
    case expr.simple_typeof(expr) {
        option.Some(t) ->
            eval.succeed(t)
        
        option.None ->
            step(expr) |> eval.then(typeof)
    }
}