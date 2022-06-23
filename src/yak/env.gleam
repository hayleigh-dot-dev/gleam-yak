// IMPORTS ---------------------------------------------------------------------

import yak/expr.{Expr}

import gleam/list
import gleam/map.{Map}
import gleam/option.{Option}

// TYPES -----------------------------------------------------------------------

/// An environment keeps track of what variables are in scope and what values 
/// they are bound to. It is essentially a stack of bindings
///
pub opaque type Env {
    Empty
    Extend(String, Expr, Env)
}

// CONSTRUCTORS ----------------------------------------------------------------

pub fn new () -> Env {
    Empty
}

pub fn from_list (list: List(#(String, Expr))) -> Env {
    list.fold(list, Empty, fn (env, binding) {
        let #(name, value) = binding

        push(env, name, value)
    })
}

pub fn from_map (map: Map(String, Expr)) -> Env {
    map.fold(map, Empty, push)
}

// QUERIES ---------------------------------------------------------------------

pub fn lookup (env: Env, name: String) -> Option(Expr) {
    case env {
        Empty ->
            option.None
        
        Extend(name_, value, _) if name == name_ ->
            option.Some(value)
        
        Extend(_, _, env) ->
            lookup(env, name)
    }
}

pub fn includes(env: Env, name: String) -> Bool {
    case lookup(env, name) {
        option.Some(_) ->
            True

        option.None ->
            False
    }
}

// MANIPULATIONS ---------------------------------------------------------------

/// Extend the current environment with a new binding.
///
pub fn push (env: Env, name: String, expr: Expr) -> Env {
    Extend(name, expr, env)
}

pub fn merge (env: Env, new: Env) -> Env {
    to_map(new) |> map.fold(env, push)
}

/// Remove the most recent binding from the environment. 
///
pub fn pop (env: Env) -> Env {
    case env {
        Empty ->
            Empty
        
        Extend(_, _, env) ->
            env
    }
}

// CONVERSIONS -----------------------------------------------------------------

/// Flatten an environment into a simple `Map`. This prefers newer bindings to
/// to older ones in cases where a name is shadowed. 
///
pub fn to_map (env: Env) -> Map(String, Expr) {
    case env {
        Empty ->
            map.new()

        Extend(name, value, env) ->
            to_map(env) |> map.insert(name, value)
    }
}