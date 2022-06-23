// IMPORTS ---------------------------------------------------------------------

import gleam/list
import gleam/map.{Map}
import gleam/option.{Option}
import gleam/pair

// TYPES -----------------------------------------------------------------------

///
///
pub type Expr {
    /// A block represents a sequence of yak expressions to be evaluated, with the
    /// final expression being the value of the entire block expression. If the
    /// block is empty, this will evaluate to `Lit(Undefined)`.
    ///
    Block(List(Expr))
    /// Functions in yak are curried, so all function calls take only a single
    /// argument. To call a function with multiple arguments you'd nest `Call`s:
    ///
    /// ```gleam
    /// Call(Call(Var("add"), Var("x")), Var("y"))
    /// ```
    ///
    Call(Expr, Expr)
    /// Externals give us a way to call *Gleam* functions from a yak script. They
    /// take the current environment as a map of bindings to expressions and should
    /// return some other yak expression.
    ///
    /// In yak's core, for example, `core::print` is a binding to an external
    /// that uses Gleam's built-in `debug` function. 
    ///
    Extern(fn (Map(String, Expr)) -> Expr)
    /// As we saw with `Call`, because functions are curried we must nest multiple
    /// `Fun`s together to get a function that has multiple parameters:
    ///
    /// ```gleam
    /// Fun("x", Fun("y", Var("x")))
    /// ```
    ///
    Fun(String, Expr)
    /// Yak's if expressions don't require an `else` branch. If one is missing
    /// but the condition is false, the expression will evaluate to `Lit(Undefined)`.
    ///
    If(Expr, Expr, Option(Expr))
    /// Let expressions introduce a new binding to the environment. Any proceeding
    /// expressions can now access the new binding!
    ///
    /// ```gleam
    /// Block([
    ///     Let("x", Lit(Number(1))),
    ///     Var("x")
    /// ])
    /// ```
    ///
    Let(String, Expr)
    /// See the documentation for [`Literal`](#Literal)s bellow for more details
    /// one what sort of literal values exist in yak.
    ///
    Lit(Literal(Expr))
    Var(String)
}

///
///
/// ❓ Why is this parameterised by a generic `expr`, why not just use `Expr`?
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
    /// Note that this is a list of #(String, expr) pairs and not a map. This
    /// means it's possible to have duplicate keys. When that happens the older
    /// duplicate will still be evaluated but the new one will shadow it, making
    /// it inaccessible.
    ///
    Record(List(#(String, expr)))
    String(String)
    Undefined
}

///
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
pub fn block (exprs: List(Expr)) -> Expr {
    Block(exprs)
}

///
///
pub fn call (fun: Expr, args: List(Expr)) -> Expr {
    case args {
        [ arg, ..rest ] ->
            call(Call(fun, arg), rest)

        [] -> 
            fun
    }
}

///
///
pub fn extern (fun: fn (Map(String, Expr)) -> Expr) -> Expr {
    Extern(fun)
}

///
///
pub fn fun (args: List(String), body: Expr) -> Expr {
    case args {
        [ arg, ..rest ] ->
            Fun(arg, fun(rest, body))

        [] -> 
            body
    }
}

///
///
pub fn if_ (cond: Expr, then: Expr, else: Option(Expr)) -> Expr {
    If(cond, then, else)
}

///
///
pub fn let_ (name: String, value: Expr) -> Expr {
    Let(name, value)
}

///
///
pub fn array (elements: List(Expr)) -> Expr {
    Lit(Array(elements))
}

///
///
pub fn boolean (value: Bool) -> Expr {
    Lit(Boolean(value))
}

///
///
pub fn raise (message: String) -> Expr {
    Lit(Exception(message))
}

///
///
pub fn number (value: Float) -> Expr {
    Lit(Number(value))
}

///
///
pub fn record (fields: List(#(String, Expr))) -> Expr {
    Lit(Record(fields))
}

///
///
pub fn string (value: String) -> Expr {
    Lit(String(value))
}

///
///
pub fn undefined () -> Expr {
    Lit(Undefined)
}

///
///
pub fn var (name: String) -> Expr {
    Var(name)
}

// QUERIES ---------------------------------------------------------------------

/// Get's the type of an expression *without evaluating it*. 
///
pub fn simple_typeof (expr: Expr) -> Option(Type) {
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

/// Recursively substitute some variable with another expression. By passing 
/// `True` as the last parameter, this will also substitute variables that are
/// later shadowed by bindings such as a function argument or a let binding name.
///
/// Be careful when doing this, as you can end up accidentially substituting things
/// you may not have intended and altering the behaviour of your program!
///
pub fn substitute (expr: Expr, name: String, value: Expr, ignore_bindings: Bool) -> Expr {
    case expr {
        Block(expressions) ->
            block(
                list.map(expressions, substitute(_, name, value, ignore_bindings))
            )
        
        Call(function, argument) ->
            call(
                substitute(function, name, value, ignore_bindings),
                [ substitute(argument, name, value, ignore_bindings) ]
            )
        
        Extern(function) ->
            extern(fn (env) {
                map.insert(env, name, value)
                    |> function
            })
        
        // 
        Fun(arg, body) if ignore_bindings || arg != name ->
            fun([ arg ], substitute(body, name, value, ignore_bindings))
        
        If(condition, then, else) ->
            if_(
                substitute(condition, name, value, ignore_bindings),
                substitute(then, name, value, ignore_bindings),
                option.map(else, substitute(_, name, value, ignore_bindings))
            )
        
        Let(name_, body) if ignore_bindings || name_ != name ->
            let_(name_, substitute(body, name, value, ignore_bindings))
        
        Lit(Array(elements)) ->
            array(list.map(elements, substitute(_, name, value, ignore_bindings)))

        Lit(Record(fields)) ->
            record(list.map(fields, pair.map_second(_, substitute(_, name, value, ignore_bindings))))
        
        Var(name_) if name_ == name->
            value

        _ ->
            expr
    }
}

///
///
pub fn coerce_to_boolean (expr: Expr) -> Bool {
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
