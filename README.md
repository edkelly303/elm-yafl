# Yafl: Yet another form library

## DISCLAIMER

This package is experimental, and the API is likely to change. It's also pretty 
weird. I would *not* recommend using it in production.

## What does it do?

This package allows you to create
[`Widget`](https://package.elm-lang.org/packages/edkelly303/elm-yafl/latest/Yafl#Widget)s,
which are essentially miniature Elm applications, and convert them into
[`Field`](https://package.elm-lang.org/packages/edkelly303/elm-yafl/latest/Yafl#Field)s
which can then be composed to create HTML forms.

`Widget`s can use _any_ Elm types as their `Msg` and `Model` types, and they can
send `Cmd`s and receive `Sub`s, just like a full-scale Elm `Program`. This gives
you a lot of flexibility to design rich user interface components, because you
have the full power of the Elm architecture at your disposal. 

`Field`s can be composed using standard functional combinators such as `map`,
`map2`, `andMap` and `andThen`. These combinators make it easy to create forms
for complex data structures by composing simpler `Field`s, without too much
wiring or boilerplate.

## What's nice about it?

* Custom `Widget`s with whatever types you like
* Composable API built on familiar functional combinators
* Minimal wiring and boilerplate
* Built-in validation
* Built-in "actor model" for communicating between `Field`s

## What's... less nice about it?

* You'll have to build your own `Widget`s.
  * But there are some simple  examples in the repo that you can copy as a
    starting-point.
* The `Msg` and `Model` types for your forms can look a bit unusual, as they are
  built on nested tuples like `( Maybe String, ( Maybe Int, () ) )`. 
  * They are a lot less weird than certain other form packages, <cough>
    `edkelly303/elm-any-type-forms` </cough>. More on this later!
* The type signatures of some of the functions for converting `Widget`s to
  `Field`s are quite terrifying
  * But you don't need to understand the types (I certainly don't), and in
    practice they are quite easy to use.

## Getting started

Until I have time to write a proper tutorial, here's a taste of what it looks
like to use this package:

Let's say we want to create a form for this very boring `User` type:

```elm
module Example exposing (..)

type alias User = 
    { firstName : String
    , lastName : String
    , isAdmin : Bool 
    }
```

### Step 1: Define your `Widget`s

First, we'll need some `Widget`s for the primitive types (`String` and `Bool`).
They are just like little Elm apps! But in addition to `init`, `update`, `view`
and `subscriptions`, they also have a `submit` function and a `label`:

```elm
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl

stringWidget =
    { init = ( "", Cmd.none )
    , update = \msg model -> ( msg, Cmd.none )
    , view =
        \{ label } model ->
            [ H.label [ HA.for label ] [ H.text label ]
            , H.input
                [ HA.id label
                , HA.type_ "text"
                , HA.value model
                , HE.onInput identity
                ]
                []
            ]
    , subscriptions = \model -> Sub.none
    , submit = \model -> Ok model
    , label = "String"
    }

boolWidget =
    { init = ( False, Cmd.none )
    , update =
        \msg model ->
            ( msg, Cmd.none )
    , view =
        \{ label } model ->
            [ H.label [ HA.for label ] [ H.text label ]
            , H.input
                [ HA.id label
                , HA.type_ "checkbox"
                , HA.checked model
                , HE.onCheck identity
                ]
                []
            ]
    , subscriptions = \model -> Sub.none
    , submit = \model -> Ok model
    , label = "Bool"
    }


-- DOC TESTS
stringWidget --: Yafl.Widget String String String
boolWidget --: Yafl.Widget Bool Bool Bool
```

### Step 2: Convert `Widget`s into `Field`s

Next, we define the `Field`s we're going to use in our form. (You might have a
big library of `Widget`s, but if you only need to use a handful of them in your
form, there's no need to include them all).

```elm
import Example exposing (..)
import Yafl

fields = 
    Yafl.defineFields
        (\string bool -> {string = string, bool = bool})
        |> Yafl.addWidget stringWidget
        |> Yafl.addWidget boolWidget
        |> Yafl.endFields

-- Defining the fields will also define the `Model` and `Msg` 
-- types for our form:

type alias FormModel = 
    ( Maybe String, (Maybe Bool, () ) )

type alias FormMsg =
    ( Maybe String, (Maybe Bool, () ) )


-- DOC TESTS
fields --: { string : Yafl.Field FormModel FormMsg Yafl.NoAddress String String, bool : Yafl.Field FormModel FormMsg Yafl.NoAddress Bool Bool }
```

Now whenever we need a `String` field, we can use `fields.string`, and if we
need a `Bool` field, it's just `fields.bool`.

### Step 3: Customize your `Field`s

Each field needs a label, and we might also want to add some validation, so:

```elm
import Example exposing (..)
import Yafl

nonEmptyString =
    fields.string
        |> Yafl.andThen 
            (\string -> 
                if String.isEmpty string then 
                    Yafl.fail "This field must not be blank"
                else    
                    Yafl.succeed string
            )

firstName =
    nonEmptyString
        |> Yafl.label "What is the user's first name?"

lastName =
    nonEmptyString
        |> Yafl.label "What is the user's last name?"

isAdmin =
    fields.bool
        |> Yafl.label "Is the user an admin?"


-- DOC TESTS
nonEmptyString --: Yafl.Field FormModel FormMsg Yafl.NoAddress String String
firstName --: Yafl.Field FormModel FormMsg Yafl.NoAddress String String
lastName --: Yafl.Field FormModel FormMsg Yafl.NoAddress String String
isAdmin --: Yafl.Field FormModel FormMsg Yafl.NoAddress Bool Bool
```

### Step 4: Compose the `Field`s to create a form

We can use a combination of `succeed` and `andMap` to compose our `Field`s into
a `User` type:

```elm
import Example exposing (..)
import Yafl

user = 
    Yafl.succeed User
        |> Yafl.andMap firstName
        |> Yafl.andMap lastName
        |> Yafl.andMap isAdmin


-- DOC TESTS
user --: Yafl.Field FormModel FormMsg Yafl.NoAddress Never User
```

### Step 5: Integrate the form into your Elm application

This isn't a very realistic example, but it should get you up and running:

```elm
import Example exposing (..)
import Yafl
import Browser
import Html as H

main = 
    Browser.element
        { init = \flags -> Yafl.init user
        , update = \msg model -> Yafl.update user msg model
        , view = \model -> H.form [] (Yafl.view user model)
        , subscriptions = \model -> Yafl.subscriptions user model
        }

-- DOC TESTS
main --: Program () (Yafl.Model FormModel) (Yafl.Msg FormMsg )
```

For a slightly larger-scale example, take a look at the
[`examples`](https://github.com/edkelly303/elm-yafl/tree/main/examples) folder.

## Not forms again?! Why are you doing this?

I guess you could say that I have... _form_ for creating form packages in Elm.
My previous attempt was
[`edkelly303/elm-any-type-forms`](https://package.elm-lang.org/packages/edkelly303/elm-any-type-forms/latest),
which similarly allowed you to create widgets with arbitrary `model` and `msg`
types and compose them into forms. However, the approach I took in that package
had some serious shortcomings:

### 1. Userland type complexity

With `elm-any-type-forms`, the types of the forms became more complex every time
you added a new field. For a type as simple as:

```elm
type Foo
    = Foo String
    | Bar Int
```

The resulting form's `model` type was:

```elm
type alias FormModel =
    ( Control.CustomType
        ( Control.Variant (Control.Arg String Control.EndVariant)
            ( Control.Variant (Control.Arg String Control.EndVariant)
                Control.EndCustomType
            )
        )
    )
```

And this got worse every time you added a variant to a custom type or field to a
record.

The key insight for `elm-yafl` was that the complexity of the types doesn't need
to increase with the _number of fields_ in the form - it only needs to increase
when you add a new _type of widget_ to the form. 

For example, once you've added a `String` widget type to your `fields`
definition, you can include as many `String` fields in your form as you like
without blowing up your `msg` and `model` types.

So, with elm-yafl, our `Foo` form's `model` could be as simple as:

```elm
type alias FormModel =
    ( Maybe String, ( Maybe Int, () ) )
```

And even if the definition of `Foo` changed to:

```elm
type Foo
    = Foo String
    | Bar Int
    | Baz String String String String
    | Qux Int Int Int Int
```

The `FormModel` type would remain exactly the same.

### 2. API type complexity and hideous error messages

In `elm-any-type-forms`, the type signatures of many of the functions are
completely insane - in some cases, they are literally hundreds of lines of code.

In fact, the type annotations got so long that the Elm 0.19.1 compiler refused
to allow me to publish the package, so I had to use an earlier compiler version
to get it (thank you Dillon Kearns for teaching me this trick!)

If you misused any of these functions, the compiler would often spend several
seconds printing out literally thousands of lines of error messages, which
was... somewhat offputting for most users?

In `elm-yafl`, there are only three functions that have crazy type signatures:
`defineFields`, `addWidget` and `endFields` - and the longest is _only_ 81 lines
of code. 

These functions only need to be used once per project, and they are
designed to be difficult to misuse, so it's less likely that users will be
confronted with bizarre error messages.

### 3. Lack of inter-field communication

Wolfgang Schuster once asked me whether it was possible for the state of a field
in `elm-any-type-forms` to depend on the state of another field. I didn't have a
good answer. If you wanted widgets that were interdependent, your only real
option was to create a custom field from scratch.

With `elm-yafl`, we now have a mechanism for fields to communicate with each
other through message passing. At the top level of your app, you can
[`intercept`](https://package.elm-lang.org/packages/edkelly303/elm-yafl/latest/Yafl#intercept)
messages that a field is sending to itself, and then
[`send`](https://package.elm-lang.org/packages/edkelly303/elm-yafl/latest/Yafl#send)
messages to another field via the Elm runtime.

### Trade-offs

There _are_ some cool features of `elm-any-type-forms` that haven't made it into
`elm-yafl`. 

* I haven't included integrated debouncing, because I'm currently thinking this
might be better left in userland. 

* Fields are not bidirectional - you can't instantly load a `User` value into a
  `User` field. I think this was a feature that sounded super-cool, but wasn't
  terribly useful in the real world. Nevertheless, loading data into a form is
  more of a hassle in `elm-yafl`.

* Multi-field validation is still possible, but currently there's no way to
  specify which field(s) should display the error message. This is something I
  might add in future versions if I can think of an API that isn't too
  complicated.

There are various other things I'd like to add, but I'm dogfooding the current
version first to see what my real-world requirements are. (If I'd done this with
`elm-any-type-forms`, I could have saved myself a lot of work!)