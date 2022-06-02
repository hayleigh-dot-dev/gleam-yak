// IMPORTS ---------------------------------------------------------------------

import gleam/list
import gleam/map.{Map}
import gleam/option.{Option}
import gleam/pair

// TYPES -----------------------------------------------------------------------

///
///
pub type Ast {
    Block(List(Ast))
    Call(Ast, Ast)
    Extern(fn (Map(String, Ast)) -> Ast)
    Fun(String, Ast)
    If(Ast, Ast, Option(Ast))
    Let(String, Ast)
    Lit(Literal(Ast))
    Var(String)
}

///
///
/// ❓ Why is this parameterised by a generic `expr`, why not just use `Ast`?
/// We want to be able to use the same type for both the literal expressions and
/// literal _patterns_. It would be weird if our array patterns had expressions
/// inside and not other patterns, so instead of duplicating these variants in the
/// `Pattern` type we can just parameterise over the internal values instead.
///
pub type Literal(expr) {
    Array(List(expr))
    Boolean(Bool)
    Exception(String)
    Number(Float)
    Record(List(#(String, expr)))
    String(String)
    Undefined
}

pub type Type {
    ArrayT
    BooleanT
    ExternT
    FunctionT
    NumberT
    RecordT
    StringT
    UndefinedT
}

// CONSTRUCTORS ----------------------------------------------------------------

///
///
pub fn block (exprs: List(Ast)) -> Ast {
    Block(exprs)
}

///
///
pub fn call (fun: Ast, args: List(Ast)) -> Ast {
    case args {
        [ arg, ..rest ] ->
            call(Call(fun, arg), rest)

        [] -> 
            fun
    }
}

///
///
pub fn extern (fun: fn (Map(String, Ast)) -> Ast) -> Ast {
    Extern(fun)
}

///
///
pub fn fun (args: List(String), body: Ast) -> Ast {
    case args {
        [ arg, ..rest ] ->
            Fun(arg, fun(rest, body))

        [] -> 
            body
    }
}

///
///
pub fn if_ (cond: Ast, then: Ast, else: Option(Ast)) -> Ast {
    If(cond, then, else)
}

///
///
pub fn let_ (name: String, value: Ast) -> Ast {
    Let(name, value)
}

///
///
pub fn array (elements: List(Ast)) -> Ast {
    Lit(Array(elements))
}

///
///
pub fn boolean (value: Bool) -> Ast {
    Lit(Boolean(value))
}

///
///
pub fn raise (message: String) -> Ast {
    Lit(Exception(message))
}

///
///
pub fn number (value: Float) -> Ast {
    Lit(Number(value))
}

///
///
pub fn record (fields: List(#(String, Ast))) -> Ast {
    Lit(Record(fields))
}

///
///
pub fn string (value: String) -> Ast {
    Lit(String(value))
}

///
///
pub fn undefined () -> Ast {
    Lit(Undefined)
}

///
///
pub fn var (name: String) -> Ast {
    Var(name)
}

// QUERIES ---------------------------------------------------------------------

/// Get's the type of an expression *without evaluating it*. 
///
pub fn simple_typeof (expr: Ast) -> Option(Type) {
    case expr {
        Extern(_) ->
            option.Some(ExternT)

        Fun(_, _) ->
            option.Some(FunctionT)

        Lit(Array(_)) ->
            option.Some(ArrayT)

        Lit(Boolean(_)) ->
            option.Some(BooleanT)

        Lit(Number(_)) ->
            option.Some(NumberT)

        Lit(Record(_)) ->
            option.Some(RecordT)

        Lit(String(_)) ->
            option.Some(StringT)

        Lit(_) ->
            option.Some(UndefinedT)

        _ ->
            option.None
    }
}

// MANIPULATiONS ---------------------------------------------------------------

///
///
pub fn substitute (expr: Ast, name: String, value: Ast) -> Ast {
    case expr {
        Block(expressions) ->
            block(
                list.map(expressions, substitute(_, name, value))
            )
        
        Call(function, argument) ->
            call(
                substitute(function, name, value),
                [ substitute(argument, name, value) ]
            )
        
        Extern(function) ->
            extern(fn (env) {
                map.insert(env, name, value)
                    |> function
            })
        
        Fun(arg, body) ->
            fun([ arg ], substitute(body, name, value))
        
        If(condition, then, else) ->
            if_(
                substitute(condition, name, value),
                substitute(then, name, value),
                option.map(else, substitute(_, name, value))
            )
        
        Let(name_, body) if name_ != name ->
            let_(name_, substitute(body, name, value))
        
        Lit(Array(elements)) ->
            array(list.map(elements, substitute(_, name, value)))

        Lit(Record(fields)) ->
            record(list.map(fields, pair.map_second(_, substitute(_, name, value))))
        
        Var(name_) if name_ == name->
            value

        _ ->
            expr
    }
}

///
///
pub fn coerce_to_boolean (expr: Ast) -> Bool {
    case expr {
        Extern(_) ->
            True

        Fun(_, _) ->
            True

        Lit(Array([])) ->
            False
        
        Lit(Array(_)) ->
            True
    
        Lit(Boolean(b)) ->
            b
        
        Lit(Number(0.0)) ->
            False
        
        Lit(Number(_)) ->
            True
        
        Lit(Record([])) ->
            False

        Lit(Record(_)) ->
            True
        
        Lit(String("")) ->
            False

        Lit(String(_)) ->
            True

        _ ->
            False
    }
}
