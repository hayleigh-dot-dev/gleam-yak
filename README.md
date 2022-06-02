# yak

[![Package Version](https://img.shields.io/hexpm/v/yak)](https://hex.pm/packages/yak)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/yak/)

A small embeddable scripting language for Gleam.

> ❗️ This package is written in *pure Gleam* so you can use it whether you're
> targetting Erlang **or** JavaScript.

## Quick start

```gleam
import yak
import yak/ast
import yak/pkg/core

pub fn main () {
    let script = [
        ast.let_("greeting", ast.string("Hello, world!")),
        ast.call(ast.var("core::print"), [ast.var("greeting")])
    ]

    yak.run(script, core.env())
    // => "Hello, world!"
}
```

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add yak
```

and its documentation can be found at <https://hexdocs.pm/yak>.

## FAQ

> Why is it called yak?

Gleam's mascot is a star named Lucy. Originally I was going to call the language
lucy, but that seemed a bit too on the nose. [Lucy & Yak](https://lucyandyak.com/)
are a clothing brand popular within queer circles and Gleam is gay as heck so it
seemed appropriate. 🏳️‍🌈

> What is the syntax / how do I write yak?

Right now, this package does not come with a parser or make any assertions on what
syntax might be appropriate: this is by design! Yak is supposed to be a minimal
embeddable scripting language for your Gleam programs, but how that yak code is
produced is up to you.

Maybe you want to provide more powerful configuration options to users of your
Web app, or maybe you utilise Gleam's type safety in some circumstances but throw
together quick scripts in others? How yak might look or be written might change
drastically depending on circumstance – I hope the community can help make some
packages for the most common use cases!
