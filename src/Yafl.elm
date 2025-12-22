module Yafl exposing
    ( Widget
    , Field, defineFields, addWidget, addWidgetWithConfig, endFields
    , Model, Msg, init, load, update, ViewConfig, view, Wizard, viewWizard, Feedback, subscriptions, submit
    , succeed, fail, failAt
    , map, contraMap
    , andMap, andThen
    , choice, option
    , label, htmlBefore, htmlAfter
    , error, errorAt, warning, warningAt
    , HasId, NoId, identifier, intercept, send, isFormValid
    , studio, toDOT
    )

{-| This library helps you build user input forms in Elm by creating and
composing self-contained [`Widget`](#Widget)s.


## Table of contents


### [Creating Widgets](#creating-widgets)

[`Widget`](#Widget)


### [Turning Widgets into Fields](#turning-widgets-into-fields)

[`Field`](#Field), [`defineFields`](#defineFields), [`addWidget`](#addWidget),
[`addWidgetWithConfig`](#addWidgetWithConfig), [`endFields`](#endFields)


### [Turning Fields into forms](#turning-fields-into-forms)

[`Model`](#Model), [`Msg`](#Msg), [`init`](#init), [`load`](#load),
[`update`](#update), [`ViewConfig`](#ViewConfig), [`view`](#view),
[`Wizard`](#Wizard), [`viewWizard`](#viewWizard), [`Feedback`](#Feedback),
[`subscriptions`](#subscriptions), [`submit`](#submit)


### [Combining Fields](#combining-fields)

[`succeed`](#succeed), [`fail`](#fail), [`failAt`](#failAt), [`map`](#map),
[`andMap`](#andMap), [`andThen`](#andThen), [`choice`](#choice),
[`option`](#option)


### [Customizing Fields](#customizing-fields)

[`label`](#label), [`htmlBefore`](#htmlBefore), [`htmlAfter`](#htmlAfter)


### [Validating Fields](#validating-fields)

[`error`](#error), [`errorAt`](#errorAt), [`warning`](#warning), [`warningAt`](#warningAt)


### [Communicating between Fields](#communicating-between-fields)

[`HasId`](#HasId), [`NoId`](#NoId), [`identifier`](#identifier),
[`intercept`](#intercept), [`send`](#send)


### [Testing and debugging](#debugging)

[`studio`](#studio), [`toDOT`](#toDOT)


# Creating Widgets

[_Back to top_](#table-of-contents)

[`Widget`](#Widget)s are the basic building blocks of this package. Each widget
is effectively a little Elm application, with its own `init`, `update`, `view`
and `subscriptions` functions, plus a couple of extra features.

This package doesn't supply any prebuilt widgets. Every app is unique, and it's
unlikely that a prebuilt widget would precisely fit your use case. But the point
is, this package gives you the power to create _any_ types of widgets you
choose, and compose them together very easily with minimal boilerplate.

Nevertheless, we'll provide some code samples for a few simple widgets that we
can use in the code snippets in these docs.

    module Examples exposing (..)

    import Html as H
    import Html.Attributes as HA
    import Html.Events as HE
    import Yafl

    {-| A basic `Widget` that produces a `String`. Its internal
    `model` and `msg` types are also `String`s.
    -}
    stringWidget : Yafl.Widget String String String
    stringWidget =
        { init = ( "", Cmd.none )
        , update = \msg model -> ( msg, Cmd.none )
        , view =
            \{ label, id, feedback } model ->
                [ H.label [ HA.for id ] [ H.text label ]
                , H.input
                    [ HA.id id
                    , HA.type_ "text"
                    , HA.value model
                    , HE.onInput identity
                    ]
                    []
                , H.ul [] (List.map (\f -> H.li [] [ H.text f ]) feedback)
                ]
        , subscriptions = \model -> Sub.none
        , submit = \model -> Ok model
        , label = "String"
        }

    {-| A `Widget` that produces an `Int`, based on the counter
    example from the Elm Guide. Its internal `model` type is an
    `Int`, but its `msg` type is a custom type.
    -}
    type CounterMsg
        = Increment
        | Decrement

    counterWidget : Yafl.Widget () Int CounterMsg Int
    counterWidget () =
        { init = ( 0, Cmd.none )
        , update =
            \msg model ->
                case msg of
                    Increment ->
                        ( model + 1, Cmd.none )

                    Decrement ->
                        ( model - 1, Cmd.none )
        , view =
            \{ label, id } model ->
                [ H.label [ HA.for id ] [ H.text label ]
                , H.fieldset
                    [ HA.id id ]
                    [ H.button [ HA.type_ "button", HE.onClick Decrement ] [ H.text "-" ]
                    , H.output [] [ H.text (String.fromInt model) ]
                    , H.button [ HA.type_ "button", HE.onClick Increment ] [ H.text "+" ]
                    ]
                ]
        , subscriptions = \_ -> Sub.none
        , submit = \model -> Ok model
        , label = "Counter"
        }

@docs Widget


# Turning Widgets into Fields

[_Back to top_](#table-of-contents)

Before we can use our [`Widget`](#Widget)s to create a form, we need to convert them into
[`Field`](#Field)s. This conversion process effectively combines the internal `model` and
`msg` types of each widget to create composite types that we can use as the
top-level `model` and `msg` for the entire form.

We perform this conversion using three functions: [`defineFields`](#defineFields), [`addWidget`](#addWidget),
and [`endFields`](#endFields). The type signatures for these three functions are extremely
terrifying, but fortunately we don't need to understand them - just follow the
example below:

    module Examples exposing (Model, Msg, fields)

    import Yafl exposing (addWidget, defineFields, endFields)

    fields =
        Yafl.defineFields
            (\string counter -> { string = string, counter = counter })
            |> Yafl.addWidget stringWidget
            |> Yafl.addWidget counterWidget
            |> Yafl.endFields

    {- This gives us the following Model and Msg types for
       our form:
    -}
    type alias FormModel =
        ( Maybe String, ( Maybe Int, () ) )

    type alias FormMsg =
        ( Maybe String, ( Maybe CounterMsg, () ) )

@docs Field, defineFields, addWidget, addWidgetWithConfig, endFields


# Turning Fields into forms

Once we've defined our [`Field`](#Field)s, we can start the fun part: making forms!

Imagine we just want a simple form that allows a user to choose an `Int`:

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)
    import Html exposing (Html)

    -- We can turn any Field into a form:

    form =
        fields.counter

    -- Initialize it with `Yafl.init` to get a (model, cmd)
    -- tuple:

    init =
        Yafl.init form

    init

    --: ( Yafl.Model FormModel Int, Cmd (Yafl.Msg FormMsg) )

    -- The form's model can then be passed to `Yafl.view`,
    -- `Yafl.update`, `Yafl.subscriptions` and `Yafl.submit`:

    model =
        Tuple.first init

    Yafl.view form model

    --: List (Html (Yafl.Msg FormMsg))

    Yafl.subscriptions form model

    --: Sub (Yafl.Msg FormMsg)

    Yafl.submit form model

    --> Ok 0

@docs Model, Msg, init, load, update, ViewConfig, view, Wizard, viewWizard, Feedback, subscriptions, submit


# Combining Fields

[_Back to top_](#table-of-contents)


## Succeeding and failing

In addition to the [`Field`](#Field)s that you define based on your
[`Widget`](#Widget)s, the package also provides [`succeed`](#succeed) and
[`fail`](#fail), which can be useful in various ways when
used with other combinators such as [`andMap`](#andMap). You may be familiar with similar functions from packages
such as [`elm/json`](http://package.elm-lang.org/packages/elm/json/latest/Json-Decode#succeed).

The views of these fields return an empty Html element. When
submitted, `succeed` always returns an `Ok`, while `fail` always returns an
`Err`.

@docs succeed, fail, failAt


## Converting input and output types

@docs map, contraMap


## Building product types

@docs andMap, andThen


## Building custom types

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    type MyCustomType
        = Foo String
        | Bar Int

    myCustomTypeField =
        Yafl.choice
            |> Yafl.option "Foo" .foo fooField
            |> Yafl.option "Bar" .bar barField

    fooField =
        fields.string
            |> Yafl.map Foo

    barField =
        fields.counter
            |> Yafl.map Bar

    model =
        myCustomTypeField
            |> Yafl.init
            |> Tuple.first

    Yafl.submit myCustomTypeField model

    --> Ok (Foo "")

@docs choice, option


# Customizing Fields

[_Back to top_](#table-of-contents)

@docs label, htmlBefore, htmlAfter


# Validating fields

[_Back to top_](#table-of-contents)

@docs error, errorAt, warning, warningAt


# Communicating between Fields

[_Back to top_](#table-of-contents)

@docs HasId, NoId, identifier, intercept, send, isFormValid


# Debugging

[_Back to top_](#table-of-contents)

@docs studio, toDOT

-}

import Browser
import Dict
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import List.Extra
import Maybe.Extra
import NestedTuple as NT
import Regex
import Task


{-| Internal type, we probably don't need to expose this...
-}
type Locator
    = ByPath Path
    | ById String


type alias MaybeId =
    Maybe String


{-| The top-level model type for your form.
-}
type Model formModel output
    = Model { selected : Int, idLookup : Dict.Dict String Path } (Node formModel)


type Node formModel
    = Value Path formModel
    | Product Path (List (Node formModel))
    | Sum Path { selected : Int, last : Int } (List ( String, Node formModel ))
    | Empty EmptyType Path


type EmptyType
    = Succeed
    | Fail


{-| The top-level message type for your form.
-}
type Msg formMsg
    = ValueChanged Path formMsg
    | ValueChangedById String formMsg
    | OptionSelected Path Int
    | Noop


{-| An internal data type used to track the location of a [`Field`](#Field) within the form.
-}
type alias Path =
    List Int


{-| Forms are composed of `Field`s - this is the main data type we'll be using in this package.
-}
type Field formModel formMsg id widgetMsg input output
    = Field
        { init :
            Path -> MaybeId -> ( Node formModel, Cmd (Msg formMsg), List ( String, Path ) )
        , load : Maybe input -> Node formModel -> ( Node formModel, Cmd (Msg formMsg) )
        , update :
            Msg formMsg
            -> Node formModel
            -> ( Node formModel, Cmd (Msg formMsg) )
        , view :
            InternalViewConfig
            -> Node formModel
            -> View formMsg
        , submit :
            List ( MaybeId, output -> Maybe ( Bool, String ) )
            -> Node formModel
            -> Result (List InternalFeedback) ( output, List InternalFeedback )
        , checks : List ( MaybeId, output -> Maybe ( Bool, String ) )
        , subscriptions :
            Node formModel
            -> Sub (Msg formMsg)
        , send : MaybeId -> widgetMsg -> Msg formMsg
        , intercept : Path -> Msg formMsg -> Maybe widgetMsg
        , label : String
        , maybeId : MaybeId
        }


type View formMsg
    = ViewNone
    | ViewOne (List (H.Html (Msg formMsg)))
    | ViewMany (View formMsg) (List (View formMsg))


{-| Indicates that a [`Field`](#Field) has been given an `identifier`, and can therefore be
used with [`intercept`](#intercept), [`send`](#send), etc. See the docs for [`identifier`](#identifier).
-}
type HasId
    = HasId Never


{-| Indicates that a [`Field`](#Field) has not been given an `identifier`. See the docs for
[`identifier`](#identifier).
-}
type NoId
    = NoId Never


{-| The `Widget` type is very similar to the record type that you would supply
to [`Browser.element`](http://package.elm-lang.org/packages/elm/browser/latest/Browser#element) to create
an Elm [`Program`](http://package.elm-lang.org/packages/elm/core/latest/Platform#Program).
-}
type alias Widget config model msg output =
    config
    -> InnerWidget model msg output


type alias InnerWidget model msg output =
    { init : ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , view : ViewConfig -> model -> List (H.Html msg)
    , submit : model -> Result (List String) output
    , subscriptions : model -> Sub msg
    , label : String
    }


{-| Configuration passed into the view of each [`Field`](#Field) in your form.
-}
type alias ViewConfig =
    { label : String
    , id : String
    , feedback : List Feedback
    }


{-| Feedback produced when the [`submit`](#submit) function on a [`Field`](#Field) returns errors.
-}
type alias Feedback =
    { isError : Bool, message : String }


type alias InternalViewConfig =
    { label : String
    , id : String
    , feedback : List LocatedFeedback
    }


type alias InternalFeedback =
    { message : String, isError : Bool, locator : Locator }


type alias LocatedFeedback =
    { message : String, isError : Bool, path : Path }



{-
   d888888b d8b   db d888888b d888888b
     `88'   888o  88   `88'   `~~88~~'
      88    88V8o 88    88       88
      88    88 V8o88    88       88
     .88.   88  V888   .88.      88
   Y888888P VP   V8P Y888888P    YP


-}


{-| Initialize your form

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    fields.counter
        |> Yafl.init

    --: ( Yafl.Model FormModel Int, Cmd (Yafl.Msg FormMsg) )

-}
init :
    Field formModel formMsg id widgetMsg input output
    -> ( Model formModel output, Cmd (Msg formMsg) )
init (Field field) =
    let
        ( node, cmd, idLookup ) =
            field.init [ 0 ] field.maybeId
    in
    ( Model { selected = 0, idLookup = Dict.fromList idLookup } node, cmd )


{-| Check that a form doesn't contain fields with duplicate identifiers.
-}
isFormValid : Field formModel formMsg id widgetMsg input output -> Bool
isFormValid field =
    List.isEmpty (checkDuplicateIds field)


checkDuplicateIds : Field formModel formMsg id widgetMsg input output -> List ( String, Int )
checkDuplicateIds (Field field) =
    let
        ( _, _, lookups ) =
            field.init [ 0 ] field.maybeId
    in
    lookups
        |> List.map (\( id_, _ ) -> id_)
        |> List.Extra.frequencies
        |> List.filter (\( _, count ) -> count > 1)



{-
   db       .d88b.   .d8b.  d8888b.
   88      .8P  Y8. d8' `8b 88  `8D
   88      88    88 88ooo88 88   88
   88      88    88 88~~~88 88   88
   88booo. `8b  d8' 88   88 88  .8D
   Y88888P  `Y88P'  YP   YP Y8888D'

-}


{-| Load data into your form. A bit tricky to explain, but see the examples
below:

For simple `Field`s, you just pass a value of the underlying `Widget`'s `msg`
type. This will dispatch the `msg` to the `Field`'s update function, which may
then update its model and optionally send a `Cmd`.

    import Yafl
    import Examples exposing (FormModel, FormMsg, CounterMsg(..), fields)

    form =
        fields.counter

    modelBeforeLoading =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form modelBeforeLoading
    --> Ok 0

    modelAfterLoading =
        modelBeforeLoading
            |> Yafl.load form Increment
            |> Tuple.first

    Yafl.submit form modelAfterLoading
    --> Ok 1

For `Field`s composed using `andMap`, you can pass in a record where each field
is a `Maybe widgetMsg`. If the record field's value is `Just`, then the message
will be dispatched to the `Field`'s update function. If it's `Nothing`, then no
message will be dispatched and the `Field`'s model will remain unchanged.

    import Yafl
    import Examples exposing (FormModel, FormMsg, CounterMsg(..), fields)

    form =
        Yafl.succeed (\int string -> ( int, string ))
            |> Yafl.andMap .a fields.counter
            |> Yafl.andMap .b fields.string

    form
    --: Yafl.Field FormModel FormMsg Never Never { a : Maybe CounterMsg, b : Maybe String } ( Int, String )

    modelBeforeLoading =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form modelBeforeLoading
    --> Ok (0, "")

    modelAfterLoading =
        modelBeforeLoading
            |> Yafl.load form
                { a = Nothing
                , b = Just "hello"
                }
            |> Tuple.first

    Yafl.submit form modelAfterLoading
    --> Ok ( 0, "hello" )

For `Field`s composed using `choice` and `option`, it's a similar story, except
that the options are nested within a record of the form `{ selected : Maybe Int,
options : {...} }`. The `selected` field is used to pick which of the options
should be selected (it's zero-indexed, so 0 is the first option, 1 is the
second, etc.)

    import Yafl
    import Examples exposing (FormModel, FormMsg, CounterMsg(..), fields)

    type Foo
        = Bar Int
        | Qux String

    form =
        Yafl.choice
            |> Yafl.option "Bar" .bar barField
            |> Yafl.option "Qux" .qux quxField

    barField =
        Yafl.map Bar fields.counter

    quxField =
        Yafl.map Qux fields.string

    form
    --: Yafl.Field FormModel FormMsg Never Never { selected : Maybe Int, options : Maybe { bar : Maybe CounterMsg, qux : Maybe String } } Foo

    modelBeforeLoading =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form modelBeforeLoading
    --> Ok (Bar 0)

    modelAfterLoading =
        modelBeforeLoading
            |> Yafl.load form
                { selected = Just 1
                , options =
                    Just
                        { bar = Nothing
                        , qux = Just "hello"
                        }
                }
            |> Tuple.first

    Yafl.submit form modelAfterLoading
    --> Ok (Qux "hello")

-}
load :
    Field formModel formMsg id widgetMsg input output
    -> input
    -> Model formModel output
    -> ( Model formModel output, Cmd (Msg formMsg) )
load (Field field) input (Model meta node) =
    field.load (Just input) node
        |> Tuple.mapFirst (Model meta)



{-
   db    db d8888b. d8888b.  .d8b.  d888888b d88888b
   88    88 88  `8D 88  `8D d8' `8b `~~88~~' 88'
   88    88 88oodD' 88   88 88ooo88    88    88ooooo
   88    88 88~~~   88   88 88~~~88    88    88~~~~~
   88b  d88 88      88  .8D 88   88    88    88.
   ~Y8888P' 88      Y8888D' YP   YP    YP    Y88888P


-}


{-| Update your form by supplying a `Msg` and `Model`
-}
update : Field formModel formMsg id widgetMsg input output -> Msg formMsg -> Model formModel output -> ( Model formModel output, Cmd (Msg formMsg) )
update (Field field) msg (Model meta node) =
    case msg of
        OptionSelected [] n ->
            case node of
                Product _ _ ->
                    ( Model { meta | selected = n } node
                    , Cmd.none
                    )

                _ ->
                    ( Model meta node, Cmd.none )

        ValueChangedById id_ widgetMsg ->
            case Dict.get id_ meta.idLookup of
                Just path ->
                    field.update (ValueChanged path widgetMsg) node
                        |> Tuple.mapFirst (Model meta)

                Nothing ->
                    -- this should be impossible
                    ( Model meta node, Cmd.none )

        _ ->
            field.update msg node
                |> Tuple.mapFirst (Model meta)



{-
   db    db d888888b d88888b db   d8b   db
   88    88   `88'   88'     88   I8I   88
   Y8    8P    88    88ooooo 88   I8I   88
   `8b  d8'    88    88~~~~~ Y8   I8I   88
    `8bd8'    .88.   88.     `8b d8'8b d8'
      YP    Y888888P Y88888P  `8b8' `8d8'


-}


{-| View your form.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)
    import Html exposing (Html)

    form =
        fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.view form model

    --: List (Html (Yafl.Msg FormMsg))

-}
view : Field formModel formMsg id widgetMsg input output -> Model formModel output -> List (H.Html (Msg formMsg))
view (Field field) (Model meta model) =
    let
        feedback =
            locateFeedback (Field field) (Model meta model)
    in
    checkDuplicatesErrorView (Field field)
        :: (field.view
                { label = field.label
                , feedback = feedback
                , id = pathFromModel model |> pathToString
                }
                model
                |> viewToList []
           )



{-
   db    db d888888b d88888b db   d8b   db db   d8b   db d888888b d88888D  .d8b.  d8888b. d8888b.
   88    88   `88'   88'     88   I8I   88 88   I8I   88   `88'   YP  d8' d8' `8b 88  `8D 88  `8D
   Y8    8P    88    88ooooo 88   I8I   88 88   I8I   88    88       d8'  88ooo88 88oobY' 88   88
   `8b  d8'    88    88~~~~~ Y8   I8I   88 Y8   I8I   88    88      d8'   88~~~88 88`8b   88   88
    `8bd8'    .88.   88.     `8b d8'8b d8' `8b d8'8b d8'   .88.    d8' db 88   88 88 `88. 88  .8D
      YP    Y888888P Y88888P  `8b8' `8d8'   `8b8' `8d8'  Y888888P d88888P YP   YP 88   YD Y8888D'


-}


{-| A record produced by [`viewWizard`](#viewWizard), containing fields that are
useful if you want to render your form as a multi-step "wizard".

  - `stepView` is the HTML produced by the view function for the current step of
    the wizard.

  - `stepIndex` is the zero-indexed number of the current step of the wizard.

  - `totalSteps` is the total number of steps in the wizard.

  - `selectStepMsg` lets you jump to a specified step of the wizard - for
    example, `selectStepMsg (currentStep + 1)` would move to the next step of
    the wizard. (In general, you'll want to take care not to let the user move
    to a `stepIndex` less than 0 or greater than `totalSteps - 1`, but there
    _are_ possible designs where you might want to do this, so Yafl doesn't
    guard against it.)

  - `isStepValid` indicates whether all the fields displayed in the current step
    of the wizard pass validation (i.e. their `submit` functions return an
    `Ok`). You could use this to decide whether to display a "next" button in
    the view of the current step.

-}
type alias Wizard formMsg =
    { stepView : List (H.Html (Msg formMsg))
    , stepIndex : Int
    , totalSteps : Int
    , selectStepMsg : Int -> Msg formMsg
    , isStepValid : Bool
    }


{-| View your form as a multi-step wizard. This will only work if the top-level
field of your form is a product type created with `succeed` and `andMap`.

`viewWizard` doesn't produce a fully-fledged wizard view; it returns a value of
type `Wizard`. [Jump over to the `Wizard` docs for an explanation](#Wizard).

-}
viewWizard :
    Field formModel formMsg id widgetMsg input output
    -> Model formModel output
    -> Wizard formMsg
viewWizard (Field field) (Model meta model) =
    let
        feedback =
            locateFeedback (Field field) (Model meta model)

        isStepValid =
            -- We want to check if any of the feedback relates to fields that
            -- are descendants of the currently selected field.
            --
            -- The currently selected field will always be an immediate child of
            -- the root node, whose path is `[ 0 ]`, so we know that its path
            -- will be two digits, like `[ 0, 0 ]`, `[ 1, 0 ]`, etc. and the
            -- paths of its descendants will always end in `[ ... , 0, 0 ]`, `[
            -- ... , 1, 0 ]` etc.
            --
            -- So, if `meta.selected` is 1, then we want to find any feedback
            -- items with a path that ends in `[ 1, 0 ]`; if `meta.selected` is
            -- 2, then we want any that end in `[ 2, 0 ]`, etc.
            --
            -- If there isn't any feedback for any of those paths, then we know
            -- that all the fields for this step of the wizard are valid. So,
            -- for example, the user can show a "next" button in this case.
            feedback
                |> List.filter
                    (\{ path, isError } ->
                        isError
                            && (case
                                    path
                                        |> List.reverse
                                        |> List.drop 1
                                        |> List.head
                                of
                                    Nothing ->
                                        False

                                    Just idx ->
                                        idx == meta.selected
                               )
                    )
                |> List.isEmpty

        toList =
            viewToList []

        default =
            { stepView = []
            , selectStepMsg = OptionSelected []
            , stepIndex = meta.selected
            , totalSteps = 0
            , isStepValid = isStepValid
            }
    in
    case
        field.view
            { label = field.label
            , feedback = feedback
            , id = pathFromModel model |> pathToString
            }
            model
    of
        ViewMany v vs ->
            let
                currentPage =
                    (v :: vs)
                        |> List.reverse
                        |> List.Extra.getAt meta.selected
                        |> Maybe.map toList
                        |> Maybe.withDefault []

                totalSteps =
                    List.length (v :: vs)
            in
            { default
                | stepView = checkDuplicatesErrorView (Field field) :: currentPage
                , totalSteps = totalSteps
            }

        otherView ->
            { default | stepView = checkDuplicatesErrorView (Field field) :: toList otherView }


locateFeedback :
    Field formModel formMsg id widgetMsg input output
    -> Model formModel output
    -> List LocatedFeedback
locateFeedback (Field field) (Model meta model) =
    let
        locatorToPath =
            \f ->
                case f.locator of
                    ById id ->
                        Dict.get id meta.idLookup
                            |> Maybe.map
                                (\path ->
                                    { message = f.message
                                    , isError = f.isError
                                    , path = path
                                    }
                                )

                    ByPath path ->
                        Just
                            { message = f.message
                            , isError = f.isError
                            , path = path
                            }
    in
    case field.submit field.checks model of
        Ok ( _, warnings ) ->
            List.filterMap locatorToPath warnings

        Err feedback_ ->
            List.filterMap locatorToPath feedback_


viewToList : List (H.Html (Msg formMsg)) -> View formMsg -> List (H.Html (Msg formMsg))
viewToList acc v =
    case v of
        ViewNone ->
            acc

        ViewOne one ->
            one ++ acc

        ViewMany one more ->
            List.foldl (\v_ acc_ -> viewToList acc_ v_) acc (one :: more)


checkDuplicatesErrorView : Field formModel formMsg id widgetMsg input output -> H.Html msg
checkDuplicatesErrorView (Field field) =
    case checkDuplicateIds (Field field) of
        [] ->
            H.text ""

        dups ->
            H.div
                []
                (List.map
                    (\( id_, count ) ->
                        H.p []
                            [ H.strong []
                                [ H.text
                                    ("⚠️ FATAL ERROR IN FORM DEFINITION: field identifiers must be unique, but the identifier \""
                                        ++ id_
                                        ++ "\" is assigned to "
                                        ++ String.fromInt count
                                        ++ " different fields."
                                    )
                                ]
                            ]
                    )
                    dups
                )



{-
   .d8888. db    db d8888b. .d8888.  .o88b. d8888b. d888888b d8888b. d888888b d888888b  .d88b.  d8b   db .d8888.
   88'  YP 88    88 88  `8D 88'  YP d8P  Y8 88  `8D   `88'   88  `8D `~~88~~'   `88'   .8P  Y8. 888o  88 88'  YP
   `8bo.   88    88 88oooY' `8bo.   8P      88oobY'    88    88oodD'    88       88    88    88 88V8o 88 `8bo.
     `Y8b. 88    88 88~~~b.   `Y8b. 8b      88`8b      88    88~~~      88       88    88    88 88 V8o88   `Y8b.
   db   8D 88b  d88 88   8D db   8D Y8b  d8 88 `88.   .88.   88         88      .88.   `8b  d8' 88  V888 db   8D
   `8888Y' ~Y8888P' Y8888P' `8888Y'  `Y88P' 88   YD Y888888P 88         YP    Y888888P  `Y88P'  VP   V8P `8888Y'


-}


{-| Generate subscriptions for your form.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.subscriptions form model

    --: Sub (Yafl.Msg FormMsg)

-}
subscriptions : Field formModel formMsg id widgetMsg input output -> Model formModel output -> Sub (Msg formMsg)
subscriptions (Field field) (Model _ model) =
    field.subscriptions model



{-
   .d8888. db    db d8888b. .88b  d88. d888888b d888888b
   88'  YP 88    88 88  `8D 88'YbdP`88   `88'   `~~88~~'
   `8bo.   88    88 88oooY' 88  88  88    88       88
     `Y8b. 88    88 88~~~b. 88  88  88    88       88
   db   8D 88b  d88 88   8D 88  88  88   .88.      88
   `8888Y' ~Y8888P' Y8888P' YP  YP  YP Y888888P    YP


-}


{-| Submit your form.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form model

    --> Ok ""

-}
submit : Field formModel formMsg id widgetMsg input output -> Model formModel output -> Result (List ( String, String )) output
submit (Field field) (Model _ model) =
    field.submit field.checks model
        |> Result.map Tuple.first
        |> Result.mapError
            (List.map
                (\{ message, locator } ->
                    ( case locator of
                        ById id_ ->
                            id_

                        ByPath path ->
                            pathToString path
                    , message
                    )
                )
            )



{-
   db       .d8b.  d8888b. d88888b db
   88      d8' `8b 88  `8D 88'     88
   88      88ooo88 88oooY' 88ooooo 88
   88      88~~~88 88~~~b. 88~~~~~ 88
   88booo. 88   88 88   8D 88.     88booo.
   Y88888P YP   YP Y8888P' Y88888P Y88888P


-}


{-| Add a label to a Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)


    fields.string
        |> Yafl.label "What is your name?"

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

-}
label : String -> Field formModel formMsg id widgetMsg input output -> Field formModel formMsg id widgetMsg input output
label label_ (Field field) =
    Field { field | label = label_ }



{-
   d88888b d8888b. d8888b.  .d88b.  d8888b.
   88'     88  `8D 88  `8D .8P  Y8. 88  `8D
   88ooooo 88oobY' 88oobY' 88    88 88oobY'
   88~~~~~ 88`8b   88`8b   88    88 88`8b
   88.     88 `88. 88 `88. `8b  d8' 88 `88.
   Y88888P 88   YD 88   YD  `Y88P'  88   YD


-}


{-| Validate a `Field` and specify an error message if validation fails.

    import Yafl

    form =
        Yafl.succeed 0
            |> Yafl.error
                (\int ->
                    if int > 0 then
                        Nothing
                    else
                        Just
                            ("Must be greater than 0, but the value is "
                                ++ String.fromInt int
                            )
                )

    form
        |> Yafl.init
        |> Tuple.first
        |> Yafl.submit form

    --> Err [ ( "0", "Must be greater than 0, but the value is 0" ) ]

-}
error :
    (output -> Maybe String)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
error check (Field field) =
    Field { field | checks = field.checks ++ [ ( Nothing, checkToError check ) ] }


checkToError : (output -> Maybe String) -> (output -> Maybe ( Bool, String ))
checkToError check =
    \output ->
        check output
            |> Maybe.map (Tuple.pair True)



{-
   d88888b d8888b. d8888b.  .d88b.  d8888b.  .d8b.  d888888b
   88'     88  `8D 88  `8D .8P  Y8. 88  `8D d8' `8b `~~88~~'
   88ooooo 88oobY' 88oobY' 88    88 88oobY' 88ooo88    88
   88~~~~~ 88`8b   88`8b   88    88 88`8b   88~~~88    88
   88.     88 `88. 88 `88. `8b  d8' 88 `88. 88   88    88
   Y88888P 88   YD 88   YD  `Y88P'  88   YD YP   YP    YP


-}


{-| Validate a `Field` and specify an error to display on a _different_ field.
This is useful when you are doing validation that involves multiple fields, but
you only want to display an error on one field.

    import Yafl
    import Examples exposing (fields)

    passwordField =
        fields.string
            |> Yafl.identifier "password"

    confirmField =
        fields.string
            |> Yafl.identifier "confirm"

    form =
        Yafl.succeed
            (\password confirm -> { password = password, confirm = confirm })
            |> Yafl.andMap .passwordField passwordField
            |> Yafl.andMap .confirmField confirmField
            |> Yafl.errorAt confirmField
                (\{ password, confirm } ->
                    if password == confirm then
                        Nothing
                    else
                        Just "Passwords do not match"
                )

    form
        |> Yafl.init
        |> Tuple.first
        |> Yafl.load form
            { passwordField = Just "password123"
            , confirmField = Just "password124"
            }
        |> Tuple.first
        |> Yafl.submit form

    --> Err [ ( "confirm", "Passwords do not match" ) ]

-}
errorAt :
    Field formModel formMsg HasId widgetMsg2 input2 output2
    -> (output -> Maybe String)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
errorAt (Field target) check (Field field) =
    Field { field | checks = field.checks ++ [ ( target.maybeId, checkToError check ) ] }



{-
   db   d8b   db  .d8b.  d8888b. d8b   db d888888b d8b   db  d888b
   88   I8I   88 d8' `8b 88  `8D 888o  88   `88'   888o  88 88' Y8b
   88   I8I   88 88ooo88 88oobY' 88V8o 88    88    88V8o 88 88
   Y8   I8I   88 88~~~88 88`8b   88 V8o88    88    88 V8o88 88  ooo
   `8b d8'8b d8' 88   88 88 `88. 88  V888   .88.   88  V888 88. ~8~
    `8b8' `8d8'  YP   YP 88   YD VP   V8P Y888888P VP   V8P  Y888P


-}


{-| Validate a `Field` and specify a warning message if validation fails. A
`warning` is like an `error`, but if you call `submit` on the `Field`, it will
return `Ok`.

    import Yafl

    form =
        Yafl.succeed 0
            |> Yafl.warning
                (\int ->
                    if int > 0 then
                        Nothing
                    else
                        Just
                            ("Should be greater than 0, but the value is "
                                ++ String.fromInt int
                            )
                )

    form
        |> Yafl.init
        |> Tuple.first
        |> Yafl.submit form

    --> Ok 0

-}
warning :
    (output -> Maybe String)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
warning check (Field field) =
    Field { field | checks = field.checks ++ [ ( Nothing, checkToWarning check ) ] }


checkToWarning : (output -> Maybe String) -> (output -> Maybe ( Bool, String ))
checkToWarning check =
    \output ->
        check output
            |> Maybe.map (Tuple.pair False)



{-
   db   d8b   db  .d8b.  d8888b. d8b   db d888888b d8b   db  d888b   .d8b.  d888888b
   88   I8I   88 d8' `8b 88  `8D 888o  88   `88'   888o  88 88' Y8b d8' `8b `~~88~~'
   88   I8I   88 88ooo88 88oobY' 88V8o 88    88    88V8o 88 88      88ooo88    88
   Y8   I8I   88 88~~~88 88`8b   88 V8o88    88    88 V8o88 88  ooo 88~~~88    88
   `8b d8'8b d8' 88   88 88 `88. 88  V888   .88.   88  V888 88. ~8~ 88   88    88
    `8b8' `8d8'  YP   YP 88   YD VP   V8P Y888888P VP   V8P  Y888P  YP   YP    YP


-}


{-| Validate a `Field` and specify a warning to display on a _different_ `Field`.
This is useful when you are doing validation that involves multiple fields, but
you only want to display a warning on one field.

    import Yafl
    import Examples exposing (fields)

    passwordField =
        fields.string
            |> Yafl.identifier "password"

    confirmField =
        fields.string
            |> Yafl.identifier "confirm"

    form =
        Yafl.succeed
            (\password confirm -> { password = password, confirm = confirm })
            |> Yafl.andMap .passwordField passwordField
            |> Yafl.andMap .confirmField confirmField
            |> Yafl.warningAt confirmField
                (\{ password, confirm } ->
                    if password == confirm then
                        Nothing
                    else
                        Just "Passwords do not match"
                )

    form
        |> Yafl.init
        |> Tuple.first
        |> Yafl.load form
            { passwordField = Just "password123"
            , confirmField = Just "password124"
            }
        |> Tuple.first
        |> Yafl.submit form

    --> Ok { password = "password123", confirm = "password124" }

-}
warningAt :
    Field formModel formMsg HasId widgetMsg2 input2 output2
    -> (output -> Maybe String)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
warningAt (Field target) check (Field field) =
    Field { field | checks = field.checks ++ [ ( target.maybeId, checkToWarning check ) ] }



{-
   d888888b d8888b.
     `88'   88  `8D
      88    88   88
      88    88   88
     .88.   88  .8D
   Y888888P Y8888D'


-}


{-| Add a unique identifier to a [`Field`](#Field), which can be used to send and intercept
messages to that Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myField =
        fields.string

    myField

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

    myFieldWithId =
        myField
            |> Yafl.identifier "any-string-as-long-as-it's-unique"

    myFieldWithId

    --: Yafl.Field FormModel FormMsg Yafl.HasId String String String

    Yafl.send myFieldWithId "Hello!"

    --: Cmd (Yafl.Msg FormMsg)

This identifier is also used as the `id` string in [`ViewConfig`](#ViewConfig),
which is passed into the view when the Field is rendered. When defining a
Widget, you can use the `id` field of the `ViewConfig` to set the
`Html.Attributes.id` of the HTML input.

-}
identifier :
    String
    -> Field formModel formMsg NoId widgetMsg input output
    -> Field formModel formMsg HasId widgetMsg input output
identifier sendId_ (Field field) =
    Field { field | maybeId = Just sendId_ }



{-
   .d8888. d88888b d8b   db d8888b.
   88'  YP 88'     888o  88 88  `8D
   `8bo.   88ooooo 88V8o 88 88   88
     `Y8b. 88~~~~~ 88 V8o88 88   88
   db   8D 88.     88  V888 88  .8D
   `8888Y' Y88888P VP   V8P Y8888D'


-}


{-| Create a `Cmd` that will send a message to a specific [`option`](#option) in
a [`choice`](#choice) Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myFieldWithId =
        fields.string
            |> Yafl.identifier "any-string-as-long-as-it's-unique"

    Yafl.send myFieldWithId "Hello!"

    --: Cmd (Yafl.Msg FormMsg)

-}
send : Field formModel formMsg HasId widgetMsg input output -> widgetMsg -> Cmd (Msg formMsg)
send (Field field) msg =
    Task.perform identity (Task.succeed (field.send field.maybeId msg))



{-
   d888888b d8b   db d888888b d88888b d8888b.  .o88b. d88888b d8888b. d888888b
     `88'   888o  88 `~~88~~' 88'     88  `8D d8P  Y8 88'     88  `8D `~~88~~'
      88    88V8o 88    88    88ooooo 88oobY' 8P      88ooooo 88oodD'    88
      88    88 V8o88    88    88~~~~~ 88`8b   8b      88~~~~~ 88~~~      88
     .88.   88  V888    88    88.     88 `88. Y8b  d8 88.     88         88
   Y888888P VP   V8P    YP    Y88888P 88   YD  `Y88P' Y88888P 88         YP


-}


{-| Intercept the top-level `Msg` sent to your form, and if it contains a message sent to the specified field, return that message.

    import Yafl
    import Examples exposing (CounterMsg, FormModel, FormMsg, fields)

    myFieldWithId =
        fields.counter
            |> Yafl.identifier "any-string-as-long-as-it's-unique"

    model =
        Yafl.init myFieldWithId
            |> Tuple.first

    Yafl.intercept myFieldWithId model

    --: Yafl.Msg FormMsg -> Maybe CounterMsg

-}
intercept : Field formModel formMsg HasId widgetMsg input fieldOutput -> Model formModel formOutput -> Msg formMsg -> Maybe widgetMsg
intercept (Field field) (Model meta _) msg =
    field.maybeId
        |> Maybe.andThen (\id -> Dict.get id meta.idLookup)
        |> Maybe.andThen (\path -> field.intercept path msg)



{-
   db   db d888888b .88b  d88. db
   88   88 `~~88~~' 88'YbdP`88 88
   88ooo88    88    88  88  88 88
   88~~~88    88    88  88  88 88
   88   88    88    88  88  88 88booo.
   YP   YP    YP    YP  YP  YP Y88888P


-}


{-| Add some arbitrary HTML before the view of a field.

    import Examples exposing (FormModel, FormMsg, fields)
    import Html
    import Yafl

    form =
        fields.string
            |> Yafl.htmlBefore (Html.text "Here's some text")

    form --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

-}
htmlBefore :
    H.Html Never
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
htmlBefore html_ field =
    insertHtml (\h v -> h ++ v) html_ field


{-| Add some arbitrary HTML after the view of a field.

    import Examples exposing (FormModel, FormMsg, fields)
    import Html
    import Yafl

    form =
        fields.string
            |> Yafl.htmlAfter (Html.text "Here's some text")

    form --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

-}
htmlAfter :
    H.Html Never
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
htmlAfter html_ field =
    insertHtml (\h v -> v ++ h) html_ field


insertHtml :
    (List (H.Html (Msg formMsg)) -> List (H.Html (Msg formMsg)) -> List (H.Html (Msg formMsg)))
    -> H.Html Never
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg d widgetMsg input output
insertHtml inserter html_ (Field field) =
    Field
        { field
            | view =
                \config model ->
                    let
                        recursivelyInsertHtml view_ =
                            case view_ of
                                ViewNone ->
                                    ViewNone

                                ViewOne v ->
                                    ViewOne (inserter [ H.map (always Noop) html_ ] v)

                                ViewMany v vs ->
                                    ViewMany (recursivelyInsertHtml v) vs
                    in
                    field.view config model
                        |> recursivelyInsertHtml
        }



{-
   .d8888. db    db  .o88b.  .o88b. d88888b d88888b d8888b.
   88'  YP 88    88 d8P  Y8 d8P  Y8 88'     88'     88  `8D
   `8bo.   88    88 8P      8P      88ooooo 88ooooo 88   88
     `Y8b. 88    88 8b      8b      88~~~~~ 88~~~~~ 88   88
   db   8D 88b  d88 Y8b  d8 Y8b  d8 88.     88.     88  .8D
   `8888Y' ~Y8888P'  `Y88P'  `Y88P' Y88888P Y88888P Y8888D'


-}


{-| A Field that always successfully generates the value that you supply.

    import Yafl

    form =
        Yafl.succeed "Hurrah!"

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form model

    --> Ok "Hurrah!"

-}
succeed : output -> Field formModel formMsg Never Never input output
succeed output =
    Field
        { init =
            \path maybeId ->
                ( Empty Succeed path
                , Cmd.none
                , Maybe.map (\id -> ( id, path )) maybeId |> Maybe.Extra.toList
                )
        , load = \_ model -> ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> ViewNone
        , subscriptions = \_ -> Sub.none
        , submit = \checks model -> runChecks checks model output
        , checks = []
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
   d88888b  .d8b.  d888888b db
   88'     d8' `8b   `88'   88
   88ooo   88ooo88    88    88
   88~~~   88~~~88    88    88
   88      88   88   .88.   88booo.
   YP      YP   YP Y888888P Y88888P


-}


{-| A Field that always fails on submission with the error message that you supply.

    import Yafl

    form =
        Yafl.fail "Oh dear!"

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form model

    --> Err [ ("0", "Oh dear!") ]

-}
fail : String -> Field formModel formMsg Never Never input output
fail e =
    Field
        { init =
            \path maybeId ->
                ( Empty Fail path
                , Cmd.none
                , Maybe.map (\id -> ( id, path )) maybeId |> Maybe.Extra.toList
                )
        , load = \_ model -> ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view =
            \{ feedback } model ->
                ViewOne <|
                    case List.filter (\f -> f.path == pathFromModel model) feedback of
                        [] ->
                            []

                        filtered ->
                            [ H.ul []
                                (List.map
                                    (\f -> H.li [] [ H.text f.message ])
                                    filtered
                                )
                            ]

        --|> Debug.log "We really need to give the user a way to define how they want errors to be rendered"
        , subscriptions = \_ -> Sub.none
        , submit =
            \_ model ->
                Err
                    [ { message = e
                      , isError = True
                      , locator = locatorFromModel model
                      }
                    ]
        , checks = []
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
   d88888b  .d8b.  d888888b db       .d8b.  d888888b
   88'     d8' `8b   `88'   88      d8' `8b `~~88~~'
   88ooo   88ooo88    88    88      88ooo88    88
   88~~~   88~~~88    88    88      88~~~88    88
   88      88   88   .88.   88booo. 88   88    88
   YP      YP   YP Y888888P Y88888P YP   YP    YP


-}


{-| Like `fail`, except it will display the error message on a _different_
Field. This can be useful in multi-field validation, when you have an error that
results from a combination of several fields, but you only want to display the
error message on one specific field.

    import Examples exposing (fields)
    import Yafl

    form =
        Yafl.succeed
            (\targetOutput failAtOutput -> targetOutput)
            |> Yafl.andMap .target targetField
            |> Yafl.andMap .failure failAtField

    targetField =
        fields.string
            |> Yafl.identifier "target-field"

    failAtField =
        Yafl.failAt targetField "Uh oh!"

    output =
        Yafl.init form
            |> Tuple.first
            |> Yafl.submit form

    -- The error is assigned to `targetField`,
    -- not `failAtField`
    output --> Err [ ( "target-field", "Uh oh!" ) ]

-}
failAt :
    Field formModel formMsg HasId widgetMsg1 input1 output1
    -> String
    -> Field formModel formMsg Never Never input2 output2
failAt (Field failField) e =
    Field
        { init =
            \path maybeId ->
                ( Empty Fail path
                , Cmd.none
                , Maybe.map (\id -> ( id, path )) maybeId |> Maybe.Extra.toList
                )
        , load = \_ model -> ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view =
            \{ feedback } model ->
                ViewOne <|
                    case List.filter (\f -> f.path == pathFromModel model) feedback of
                        [] ->
                            []

                        filtered ->
                            [ H.ul []
                                (List.map
                                    (\f -> H.li [] [ H.text f.message ])
                                    filtered
                                )
                            ]

        --|> Debug.log "We really need to give the user a way to define how they want errors to be rendered"
        , subscriptions = \_ -> Sub.none
        , submit =
            \_ model ->
                Err
                    [ case failField.maybeId of
                        Just id_ ->
                            { message = e
                            , isError = True
                            , locator = ById id_
                            }

                        Nothing ->
                            { message = "FATAL ERROR in `failAt` function"
                            , isError = True
                            , locator = locatorFromModel model
                            }
                    ]
        , checks = []
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
    .o88b.  .d88b.  d8b   db d888888b d8888b.  .d8b.  .88b  d88.  .d8b.  d8888b.
   d8P  Y8 .8P  Y8. 888o  88 `~~88~~' 88  `8D d8' `8b 88'YbdP`88 d8' `8b 88  `8D
   8P      88    88 88V8o 88    88    88oobY' 88ooo88 88  88  88 88ooo88 88oodD'
   8b      88    88 88 V8o88    88    88`8b   88~~~88 88  88  88 88~~~88 88~~~
   Y8b  d8 `8b  d8' 88  V888    88    88 `88. 88   88 88  88  88 88   88 88
    `Y88P'  `Y88P'  VP   V8P    YP    88   YD YP   YP YP  YP  YP YP   YP 88


-}


{-| Convert the input of a [`Field`](#Field) from one type to another.

This is useful if you want to control how data is loaded into your form with
[`load`](#load).

    import Examples exposing (FormModel, FormMsg, fields)
    import Yafl

    passwordField :
        Yafl.Field
            FormModel
            FormMsg
            Never
            Never
            -- Here's the `input` parameter:
            { password : Maybe String
            , confirm : Maybe String
            }
            String
    passwordField =
        Yafl.succeed
            (\p c -> { password = p, confirm = c })
            |> Yafl.andMap .password fields.string
            |> Yafl.andMap .confirm fields.string
            |> Yafl.error
                (\{ password, confirm } ->
                    if password == confirm then
                        Nothing

                    else
                        Just "Passwords need to match"
                )
            |> Yafl.map .password

    -- With the `.password` and `.confirm` functions that we
    -- pass to `andMap` here, our `Field`'s `input` type
    -- parameter is a record containing both of those fields.
    -- By using `contraMap`, we can change the `input` type
    -- to make the field a bit easier to use.

    passwordFieldThatIsEasierToLoad :
        Yafl.Field
            FormModel
            FormMsg
            Never
            Never
            -- after `contraMap`, the `input` parameter
            -- is just a `String`
            String
            String
    passwordFieldThatIsEasierToLoad =
        passwordField
            |> Yafl.contraMap
                (\string ->
                    { password = Just string
                    , confirm = Just string
                    }
                )

    -- DOC TESTS
    passwordField --: Yafl.Field FormModel FormMsg Never Never { password : Maybe String, confirm : Maybe String } String
    passwordFieldThatIsEasierToLoad --: Yafl.Field FormModel FormMsg Never Never String String

-}
contraMap :
    (input2 -> input)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input2 output
contraMap f (Field field) =
    Field
        { init = field.init
        , load = \input -> input |> Maybe.map f |> field.load
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , maybeId = field.maybeId
        , send = field.send
        , checks = field.checks
        , intercept = field.intercept
        , label = field.label
        , submit = field.submit
        }



{-
   .88b  d88.  .d8b.  d8888b.
   88'YbdP`88 d8' `8b 88  `8D
   88  88  88 88ooo88 88oodD'
   88  88  88 88~~~88 88~~~
   88  88  88 88   88 88
   YP  YP  YP YP   YP 88


-}


{-| Convert the output of a [`Field`](#Field) from one type to another.

A common use case for this function is to create `Field`s that produce custom
type variants.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    -- Example: Creating a custom type variant

    type MyCustomType
        = Foo String

    fooField =
        Yafl.map Foo (fields.string)

    fooField
        |> Yafl.init
        |> Tuple.first
        |> Yafl.submit fooField

    --> Ok (Foo "")

-}
map :
    (output -> output2)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output2
map f (Field field) =
    Field
        { init = field.init
        , load = field.load
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , submit =
            \checks model ->
                field.submit field.checks model
                    |> Result.map (\( output, warnings ) -> ( f output, warnings ))
                    |> Result.andThen
                        (\( output, warnings ) ->
                            case runChecks checks model output of
                                Ok ( output_, moreWarnings ) ->
                                    Ok ( output_, warnings ++ moreWarnings )

                                Err feedback_ ->
                                    Err (warnings ++ feedback_)
                        )
        , checks = []
        , send = field.send
        , intercept = field.intercept
        , label = field.label
        , maybeId = field.maybeId
        }



{-
    .d8b.  d8b   db d8888b. .88b  d88.  .d8b.  d8888b.
   d8' `8b 888o  88 88  `8D 88'YbdP`88 d8' `8b 88  `8D
   88ooo88 88V8o 88 88   88 88  88  88 88ooo88 88oodD'
   88~~~88 88 V8o88 88   88 88  88  88 88~~~88 88~~~
   88   88 88  V888 88  .8D 88  88  88 88   88 88
   YP   YP VP   V8P Y8888D' YP  YP  YP YP   YP 88


-}


{-| Combine multiple fields. Use in combination with [`succeed`](#succeed).

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        Yafl.succeed (\a b c -> { firstName = a, middleName = b, lastName = c })
            |> Yafl.andMap .firstName (fields.string |> Yafl.label "First name")
            |> Yafl.andMap .middleName (fields.string |> Yafl.label "Middle name")
            |> Yafl.andMap .lastName (fields.string |> Yafl.label "Last name")

    model =
        Yafl.init form
            |> Tuple.first

    Yafl.submit form model
    --> Ok { firstName = "", middleName = "", lastName = "" }

-}
andMap :
    (options -> Maybe input)
    -> Field formModel formMsg id widgetMsg input output1
    -> Field formModel formMsg Never Never options (output1 -> output2)
    -> Field formModel formMsg Never Never options output2
andMap getInput (Field thisField) (Field previousFields) =
    Field
        { init =
            \path _ ->
                let
                    ( previousFieldsModel, previousFieldsCmd, previousFieldsLookups ) =
                        previousFields.init path previousFields.maybeId
                in
                case previousFieldsModel of
                    Product previousPath previousFieldNodes ->
                        let
                            ( thisFieldNode, thisFieldCmd, thisFieldLookups ) =
                                thisField.init (List.length previousFieldNodes :: path) thisField.maybeId
                        in
                        ( Product previousPath (thisFieldNode :: previousFieldNodes)
                        , Cmd.batch [ previousFieldsCmd, thisFieldCmd ]
                        , thisFieldLookups ++ previousFieldsLookups
                        )

                    Empty _ _ ->
                        let
                            ( thisFieldNode, thisFieldCmd, thisFieldLookups ) =
                                thisField.init (0 :: path) thisField.maybeId
                        in
                        ( Product path [ thisFieldNode ]
                        , thisFieldCmd
                        , thisFieldLookups ++ previousFieldsLookups
                        )

                    _ ->
                        let
                            ( newPreviousFieldsModel, _, newPreviousFieldsLookups ) =
                                previousFields.init (0 :: path) previousFields.maybeId

                            ( thisFieldModel, thisFieldCmd, thisFieldLookups ) =
                                thisField.init (1 :: path) thisField.maybeId
                        in
                        ( Product path [ thisFieldModel, newPreviousFieldsModel ]
                        , Cmd.batch [ previousFieldsCmd, thisFieldCmd ]
                        , thisFieldLookups ++ newPreviousFieldsLookups
                        )
        , load =
            \input model ->
                case ( input |> Maybe.andThen getInput, model ) of
                    ( thisFieldInput, Product path (thisFieldNode :: previousFieldNodes) ) ->
                        let
                            ( newThisOptionNode, thisOptionCmd ) =
                                thisField.load thisFieldInput thisFieldNode

                            ( newPreviousFieldsNode, previousFieldsCmd ) =
                                previousFields.load input (Product path previousFieldNodes)
                        in
                        case newPreviousFieldsNode of
                            Product _ nodes ->
                                ( Product path (newThisOptionNode :: nodes)
                                , Cmd.batch [ thisOptionCmd, previousFieldsCmd ]
                                )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , update =
            \msg model ->
                case model of
                    Product path (thisFieldNode :: previousFieldNodes) ->
                        let
                            ( newThisFieldNode, thisFieldCmd ) =
                                thisField.update msg thisFieldNode

                            ( newPreviousFieldsNode, previousFieldsCmd ) =
                                previousFields.update msg (Product path previousFieldNodes)
                        in
                        case newPreviousFieldsNode of
                            Product _ nodes ->
                                ( Product path (newThisFieldNode :: nodes)
                                , Cmd.batch [ previousFieldsCmd, thisFieldCmd ]
                                )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Product path (thisFieldNode :: previousFieldNodes) ->
                        let
                            thisView =
                                thisField.view
                                    { config
                                        | label = thisField.label
                                        , id = thisFieldNode |> pathFromModel |> pathToString
                                    }
                                    thisFieldNode
                        in
                        case
                            previousFields.view
                                { config
                                    | label = previousFields.label
                                    , id = "never used"
                                }
                                (Product path previousFieldNodes)
                        of
                            ViewNone ->
                                thisView

                            ViewOne v ->
                                ViewMany thisView [ ViewOne v ]

                            ViewMany v vs ->
                                ViewMany thisView (v :: vs)

                    _ ->
                        ViewOne [ H.text "Fatal error in `andMap` view function (not a product)" ]
        , subscriptions =
            \model ->
                case model of
                    Product path (thisFieldNode :: previousFieldNodes) ->
                        Sub.batch
                            [ previousFields.subscriptions (Product path previousFieldNodes)
                            , thisField.subscriptions thisFieldNode
                            ]

                    _ ->
                        Sub.none
        , submit =
            \checks model ->
                case model of
                    Product path (thisFieldNode :: previousFieldNodes) ->
                        case
                            ( thisField.submit thisField.checks thisFieldNode
                            , previousFields.submit previousFields.checks (Product path previousFieldNodes)
                            )
                        of
                            ( Ok ( thisFieldOutput, thisFieldWarnings ), Ok ( outputConstructor, outputConstructorWarnings ) ) ->
                                case outputConstructor thisFieldOutput |> runChecks checks model of
                                    Ok ( output, warnings ) ->
                                        Ok ( output, outputConstructorWarnings ++ thisFieldWarnings ++ warnings )

                                    Err feedback_ ->
                                        Err (outputConstructorWarnings ++ thisFieldWarnings ++ feedback_)

                            ( Ok _, Err previousErrors ) ->
                                Err previousErrors

                            ( Err thisError, Ok _ ) ->
                                Err thisError

                            ( Err thisError, Err previousErrors ) ->
                                Err (previousErrors ++ thisError)

                    _ ->
                        Err
                            [ { message = "Fatal error in `andMap` submit function"
                              , isError = True
                              , locator = locatorFromModel model
                              }
                            ]
        , checks = []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = previousFields.label
        , maybeId = Nothing
        }



{-
    .d8b.  d8b   db d8888b. d888888b db   db d88888b d8b   db
   d8' `8b 888o  88 88  `8D `~~88~~' 88   88 88'     888o  88
   88ooo88 88V8o 88 88   88    88    88ooo88 88ooooo 88V8o 88
   88~~~88 88 V8o88 88   88    88    88~~~88 88~~~~~ 88 V8o88
   88   88 88  V888 88  .8D    88    88   88 88.     88  V888
   YP   YP VP   V8P Y8888D'    YP    YP   YP Y88888P VP   V8P


-}


{-| Check the result of submitting a [`Field`](#Field). This can be useful if
you want to convert an existing [`Widget`](#Widget) to return a different output
type.

(You _can_ also use it for validating a field's output, but it will probably be
better to use [`error`](#error) or [`errorAt`](#errorAt) instead.)

Be warned: this is not a fully law-abiding monadic `andThen` - you shouldn't use
it to return arbitrary Fields, you should only use it with `succeed`, `fail` and
`failAt`

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    -- Example 1: Repurposing an existing widget to return
    -- a different type

    fields.string
            |> Yafl.label "Enter a floating-point number"
            |> Yafl.andThen
                (\string ->
                    case String.toFloat string of
                        Just float ->
                            Yafl.succeed float

                        Nothing ->
                            Yafl.fail
                                "That's not a valid float"
                )

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String Float

    -- Example 2: Validating a field's output
    -- (This works, but it's better to use `error`
    -- and `errorAt`.)

    fields.string
        |> Yafl.label "Enter the first name of a Beatle"
        |> Yafl.andThen
            (\name ->
                if List.member name
                    [ "John", "Paul", "George", "Ringo" ]
                then
                    Yafl.succeed name

                else
                    Yafl.fail "Invalid Beatle"
            )

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

-}
andThen :
    (output -> Field formModel formMsg Never Never input output2)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output2
andThen f (Field field) =
    Field
        { init = field.init
        , load = field.load
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , maybeId = field.maybeId
        , send = field.send
        , checks = []
        , intercept = field.intercept
        , label = field.label
        , submit =
            \checks model ->
                field.submit field.checks model
                    |> Result.andThen
                        (\( output, warnings ) ->
                            let
                                (Field andThenField) =
                                    f output
                            in
                            case andThenField.submit (andThenField.checks ++ checks) model of
                                Ok ( andThenOutput, andThenWarnings ) ->
                                    Ok ( andThenOutput, warnings ++ andThenWarnings )

                                Err feedback_ ->
                                    Err (warnings ++ feedback_)
                        )
        }



{-
    .o88b. db   db  .d88b.  d888888b  .o88b. d88888b
   d8P  Y8 88   88 .8P  Y8.   `88'   d8P  Y8 88'
   8P      88ooo88 88    88    88    8P      88ooooo
   8b      88~~~88 88    88    88    8b      88~~~~~
   Y8b  d8 88   88 `8b  d8'   .88.   Y8b  d8 88.
    `Y88P' YP   YP  `Y88P'  Y888888P  `Y88P' Y88888P


-}


{-| Begin defining a `choice` between multiple [`option`](#option)s.

This doesn't do anything useful on its own - it needs to be used in conjunction
with `option`

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    Yafl.choice

    --: Yafl.Field FormModel FormMsg Never Never { selected : Maybe Int, options : Maybe {} } Int

-}
choice : Field model formMsg Never Never { selected : Maybe Int, options : Maybe options } value
choice =
    Field
        { init =
            \path maybeId ->
                ( Sum path { selected = 0, last = -1 } []
                , Cmd.none
                , Maybe.map (\id -> ( id, path )) maybeId |> Maybe.Extra.toList
                )
        , load =
            \input model ->
                case ( Maybe.andThen .selected input, model ) of
                    ( Just selected, Sum path meta nodes ) ->
                        ( Sum path { meta | selected = selected } nodes
                        , Cmd.none
                        )

                    _ ->
                        ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> ViewOne []
        , subscriptions = \_ -> Sub.none
        , submit =
            \_ model ->
                Err
                    [ { message = "empty choice"
                      , isError = True
                      , locator = locatorFromModel model
                      }
                    ]
        , checks = []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
    .d88b.  d8888b. d888888b d888888b  .d88b.  d8b   db
   .8P  Y8. 88  `8D `~~88~~'   `88'   .8P  Y8. 888o  88
   88    88 88oodD'    88       88    88    88 88V8o 88
   88    88 88~~~      88       88    88    88 88 V8o88
   `8b  d8' 88         88      .88.   `8b  d8' 88  V888
    `Y88P'  88         YP    Y888888P  `Y88P'  VP   V8P


-}


{-| Add an option to a [`choice`](#choice).

The option will render as an HTML radio input in the view, so you need to
provide a `String` to serve as a label, plus a `Field` that returns the actual
type you want as output.

All the `options` of a given `choice` must return the same output type,
although their internal `model` and `msg` types can be different.

If the user selects the radio button for this `option`, then the `Field`'s view
will be rendered underneath the fieldset containing the radio buttons.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    Yafl.choice
        |> Yafl.option
            "This is the label for the radio button"
            .counter
            (fields.counter
                |> Yafl.label "This is a label for the `counter` field"
            )

    --: Yafl.Field FormModel FormMsg Never Never { options : Maybe { counter : Maybe Examples.CounterMsg }, selected : Maybe Int } Int

-}
option :
    String
    -> (options -> Maybe input)
    -> Field formModel formMsg id widgetMsg input value
    -> Field formModel formMsg Never Never { selected : Maybe Int, options : Maybe options } value
    -> Field formModel formMsg Never Never { selected : Maybe Int, options : Maybe options } value
option thisOptionLabel getInput (Field thisOptionField) (Field previousOptionFields) =
    Field
        { init =
            \path _ ->
                case previousOptionFields.init path previousOptionFields.maybeId of
                    ( Sum previousPath meta previousOptions, previousOptionsCmd, previousOptionsLookups ) ->
                        let
                            ( thisOptionModel, thisOptionCmd, thisOptionLookups ) =
                                thisOptionField.init (List.length previousOptions :: path) thisOptionField.maybeId
                        in
                        ( Sum previousPath { meta | last = meta.last + 1 } (( thisOptionLabel, thisOptionModel ) :: previousOptions)
                        , Cmd.batch [ previousOptionsCmd, thisOptionCmd ]
                        , thisOptionLookups ++ previousOptionsLookups
                        )

                    _ ->
                        thisOptionField.init path thisOptionField.maybeId
        , load =
            \input model ->
                case ( input |> Maybe.andThen .options |> Maybe.andThen getInput, model ) of
                    ( thisOptionInput, Sum path sel (( _, thisOptionNode ) :: previousOptionLabelsAndNodes) ) ->
                        let
                            ( newThisOptionNode, thisOptionCmd ) =
                                thisOptionField.load thisOptionInput thisOptionNode

                            ( newPreviousOptionsNode, previousOptionsCmd ) =
                                previousOptionFields.load input (Sum path sel previousOptionLabelsAndNodes)
                        in
                        case newPreviousOptionsNode of
                            Sum _ newSel newPreviousOptionLabelsAndNodes ->
                                ( Sum path newSel (( thisOptionLabel, newThisOptionNode ) :: newPreviousOptionLabelsAndNodes)
                                , Cmd.batch [ thisOptionCmd, previousOptionsCmd ]
                                )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , update =
            \msg model ->
                case model of
                    Sum path meta ((( _, thisOptionModel ) :: previousOptionLabelsAndModels) as options) ->
                        let
                            fallback =
                                let
                                    ( newThisOptionModel, thisOptionCmd ) =
                                        thisOptionField.update msg thisOptionModel

                                    ( newPreviousOptionModels, previousOptionsCmd ) =
                                        previousOptionFields.update msg (Sum path meta previousOptionLabelsAndModels)
                                in
                                case newPreviousOptionModels of
                                    Sum _ _ newPreviousOptionLabelsAndModels ->
                                        ( Sum path meta (( thisOptionLabel, newThisOptionModel ) :: newPreviousOptionLabelsAndModels)
                                        , Cmd.batch [ previousOptionsCmd, thisOptionCmd ]
                                        )

                                    _ ->
                                        ( model, Cmd.none )
                        in
                        case msg of
                            OptionSelected msgPath selected ->
                                if msgPath == path then
                                    ( Sum path { meta | selected = selected } options
                                    , Cmd.none
                                    )

                                else
                                    fallback

                            _ ->
                                fallback

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Sum path meta (( _, thisOptionModel ) :: previousOptionLabelsAndModels) ->
                        let
                            radio idx lbl =
                                H.label [ HA.class "yafl-radio-option" ]
                                    [ H.input
                                        [ HA.type_ "radio"
                                        , HA.name config.label
                                        , HE.onClick (OptionSelected path idx)
                                        , HA.checked (meta.selected == idx)
                                        ]
                                        []
                                    , H.text lbl
                                    ]

                            previousLabels =
                                List.map Tuple.first previousOptionLabelsAndModels

                            labels =
                                List.reverse (thisOptionLabel :: previousLabels)

                            viewOptionSelector =
                                if meta.last == List.length previousOptionLabelsAndModels then
                                    H.fieldset [ HA.id (pathToString path) ]
                                        (H.legend [] [ H.text config.label ] :: List.indexedMap radio labels)

                                else
                                    H.text ""

                            viewSelectedOption =
                                if meta.selected == List.length previousOptionLabelsAndModels then
                                    thisOptionField.view
                                        { config
                                            | label = thisOptionField.label
                                            , id = thisOptionModel |> pathFromModel |> pathToString
                                        }
                                        thisOptionModel

                                else
                                    previousOptionFields.view
                                        { config
                                            | label = previousOptionFields.label
                                            , id = "never used"
                                        }
                                        (Sum path meta previousOptionLabelsAndModels)
                        in
                        case viewSelectedOption of
                            ViewOne v ->
                                ViewOne (viewOptionSelector :: v)

                            ViewMany (ViewOne v) vs ->
                                ViewMany (ViewOne (viewOptionSelector :: v)) vs

                            _ ->
                                ViewOne [ viewOptionSelector ]

                    _ ->
                        ViewOne [ H.text "Fatal error in `option` view function" ]
        , subscriptions =
            \model ->
                case model of
                    Sum path meta (( _, thisOptionModel ) :: previousOptionLabelsAndModels) ->
                        Sub.batch
                            [ previousOptionFields.subscriptions (Sum path meta previousOptionLabelsAndModels)
                            , thisOptionField.subscriptions thisOptionModel
                            ]

                    _ ->
                        Sub.none
        , submit =
            \_ model ->
                case model of
                    Sum path meta (( _, thisOptionModel ) :: previousOptionLabelsAndModels) ->
                        if meta.selected == List.length previousOptionLabelsAndModels then
                            thisOptionField.submit thisOptionField.checks thisOptionModel

                        else
                            previousOptionFields.submit previousOptionFields.checks (Sum path meta previousOptionLabelsAndModels)

                    _ ->
                        Err
                            [ { message = "Fatal error in `option` submit function"
                              , isError = True
                              , locator = locatorFromModel model
                              }
                            ]
        , checks = []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = previousOptionFields.label
        , maybeId = Nothing
        }



{-
   d8888b. d88888b d88888b d888888b d8b   db d88888b d88888b d888888b d88888b db      d8888b.
   88  `8D 88'     88'       `88'   888o  88 88'     88'       `88'   88'     88      88  `8D
   88   88 88ooooo 88ooo      88    88V8o 88 88ooooo 88ooo      88    88ooooo 88      88   88
   88   88 88~~~~~ 88~~~      88    88 V8o88 88~~~~~ 88~~~      88    88~~~~~ 88      88   88
   88  .8D 88.     88        .88.   88  V888 88.     88        .88.   88.     88booo. 88  .8D
   Y8888D' Y88888P YP      Y888888P VP   V8P Y88888P YP      Y888888P Y88888P Y88888P Y8888D'


-}


{-| Begin a definition of the fields you want to use in your forms.
-}
defineFields :
    ctor
    ->
        { ctor : ctor
        , widgets : b -> b
        , modelGetters : { focus : focus -> focus, appendToGetters : getters -> getters }
        , modelSetters : { focus : c -> c, appendToSetters : setters -> setters }
        , modelBlanks : d -> d
        , msgGetters : { focus : e -> e, appendToGetters : f -> f }
        , msgSetters : { focus : g -> g, appendToSetters : h -> h }
        , msgBlanks : i -> i
        , apply : j -> j
        }
defineFields ctor =
    { ctor = ctor
    , widgets = NT.define
    , modelGetters = NT.defineGetters
    , modelSetters = NT.defineSetters
    , modelBlanks = NT.define
    , msgGetters = NT.defineGetters
    , msgSetters = NT.defineSetters
    , msgBlanks = NT.define
    , apply = NT.define
    }



{-
    .d8b.  d8888b. d8888b. db   d8b   db d888888b d8888b.  d888b  d88888b d888888b
   d8' `8b 88  `8D 88  `8D 88   I8I   88   `88'   88  `8D 88' Y8b 88'     `~~88~~'
   88ooo88 88   88 88   88 88   I8I   88    88    88   88 88      88ooooo    88
   88~~~88 88   88 88   88 Y8   I8I   88    88    88   88 88  ooo 88~~~~~    88
   88   88 88  .8D 88  .8D `8b d8'8b d8'   .88.   88  .8D 88. ~8~ 88.        88
   YP   YP Y8888D' Y8888D'  `8b8' `8d8'  Y888888P Y8888D'  Y888P  Y88888P    YP


-}


{-| Add a Widget to the definition of the Fields you want to use in your forms.
-}
addWidget :
    Widget () widgetModel widgetMsg output
    ->
        { apply :
            ({ blankModel : formModel
             , blankMsg : formMsg
             , ctor :
                Field formModel formMsg NoId widgetMsg widgetMsg output -> fields
             }
             -> ( formMsg -> Maybe widgetMsg, previousMsgGetters )
             -> ( Maybe widgetMsg -> formMsg -> formMsg, previousMsgSetters )
             -> ( formModel -> Maybe widgetModel, previousModelGetters )
             -> ( Maybe widgetModel -> formModel -> formModel, previousModelSetters )
             -> ( InnerWidget widgetModel widgetMsg output, previousWidgets )
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : ( InnerWidget widgetModel widgetMsg output, previousWidgets ) -> toWidgets
        , modelBlanks : ( Maybe widgetModel, previousBlankModels ) -> toBlankModel
        , modelGetters :
            { appendToGetters : ( tuple3 -> head3, nextModelGetters ) -> toModelGetters
            , focus : tuple3 -> ( head3, tail4 )
            }
        , modelSetters :
            { appendToSetters :
                ( head2 -> tuple2 -> tuple2, nextModelSetters ) -> toModelSetters
            , focus :
                (( head2, tail3 ) -> ( head2, tail3 )) -> tuple2 -> tuple2
            }
        , msgBlanks : ( Maybe widgetMsg, previousBlankMsgs ) -> toBlankMsg
        , msgGetters :
            { appendToGetters : ( tuple1 -> head1, nextMsgGetters ) -> toMsgGetters
            , focus : tuple1 -> ( head1, tail1 )
            }
        , msgSetters :
            { appendToSetters :
                ( head -> tuple -> tuple, nextMsgSetters ) -> toMsgSetters
            , focus : (( head, tail ) -> ( head, tail )) -> tuple -> tuple
            }
        }
    ->
        { apply :
            ({ blankModel : formModel, blankMsg : formMsg, ctor : fields }
             -> previousMsgGetters
             -> previousMsgSetters
             -> previousModelGetters
             -> previousModelSetters
             -> previousWidgets
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : previousWidgets -> toWidgets
        , modelBlanks : previousBlankModels -> toBlankModel
        , modelGetters :
            { appendToGetters : nextModelGetters -> toModelGetters
            , focus : tuple3 -> tail4
            }
        , modelSetters :
            { appendToSetters : nextModelSetters -> toModelSetters
            , focus : (tail3 -> tail3) -> tuple2 -> tuple2
            }
        , msgBlanks : previousBlankMsgs -> toBlankMsg
        , msgGetters :
            { appendToGetters : nextMsgGetters -> toMsgGetters, focus : tuple1 -> tail1 }
        , msgSetters :
            { appendToSetters : nextMsgSetters -> toMsgSetters
            , focus : (tail -> tail) -> tuple -> tuple
            }
        }
addWidget widget builder =
    { ctor = builder.ctor
    , widgets = NT.appender (widget ()) builder.widgets
    , modelGetters = NT.getter builder.modelGetters
    , modelSetters = NT.setter builder.modelSetters
    , modelBlanks = NT.appender Nothing builder.modelBlanks
    , msgGetters = NT.getter builder.msgGetters
    , msgSetters = NT.setter builder.msgSetters
    , msgBlanks = NT.appender Nothing builder.msgBlanks
    , apply = folder5 applierWithoutConfig builder.apply
    }


{-| Add a configurable Widget to the definition of the Fields you want to use in
your forms. Each time you use a Field derived from this Widget in your form, you
will be able to pass in a `config` value.
-}
addWidgetWithConfig :
    Widget config widgetModel widgetMsg output
    ->
        { apply :
            ({ blankModel : formModel
             , blankMsg : formMsg
             , ctor :
                (config -> Field formModel formMsg NoId widgetMsg widgetMsg output) -> fields
             }
             -> ( formMsg -> Maybe widgetMsg, previousMsgGetters )
             -> ( Maybe widgetMsg -> formMsg -> formMsg, previousMsgSetters )
             -> ( formModel -> Maybe widgetModel, previousModelGetters )
             -> ( Maybe widgetModel -> formModel -> formModel, previousModelSetters )
             -> ( Widget config widgetModel widgetMsg output, previousWidgets )
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : ( Widget config widgetModel widgetMsg output, previousWidgets ) -> toWidgets
        , modelBlanks : ( Maybe widgetModel, previousBlankModels ) -> toBlankModel
        , modelGetters :
            { appendToGetters : ( tuple3 -> head3, nextModelGetters ) -> toModelGetters
            , focus : tuple3 -> ( head3, tail4 )
            }
        , modelSetters :
            { appendToSetters :
                ( head2 -> tuple2 -> tuple2, nextModelSetters ) -> toModelSetters
            , focus :
                (( head2, tail3 ) -> ( head2, tail3 )) -> tuple2 -> tuple2
            }
        , msgBlanks : ( Maybe widgetMsg, previousBlankMsgs ) -> toBlankMsg
        , msgGetters :
            { appendToGetters : ( tuple1 -> head1, nextMsgGetters ) -> toMsgGetters
            , focus : tuple1 -> ( head1, tail1 )
            }
        , msgSetters :
            { appendToSetters :
                ( head -> tuple -> tuple, nextMsgSetters ) -> toMsgSetters
            , focus : (( head, tail ) -> ( head, tail )) -> tuple -> tuple
            }
        }
    ->
        { apply :
            ({ blankModel : formModel, blankMsg : formMsg, ctor : fields }
             -> previousMsgGetters
             -> previousMsgSetters
             -> previousModelGetters
             -> previousModelSetters
             -> previousWidgets
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : previousWidgets -> toWidgets
        , modelBlanks : previousBlankModels -> toBlankModel
        , modelGetters :
            { appendToGetters : nextModelGetters -> toModelGetters
            , focus : tuple3 -> tail4
            }
        , modelSetters :
            { appendToSetters : nextModelSetters -> toModelSetters
            , focus : (tail3 -> tail3) -> tuple2 -> tuple2
            }
        , msgBlanks : previousBlankMsgs -> toBlankMsg
        , msgGetters :
            { appendToGetters : nextMsgGetters -> toMsgGetters, focus : tuple1 -> tail1 }
        , msgSetters :
            { appendToSetters : nextMsgSetters -> toMsgSetters
            , focus : (tail -> tail) -> tuple -> tuple
            }
        }
addWidgetWithConfig widget builder =
    { ctor = builder.ctor
    , widgets = NT.appender widget builder.widgets
    , modelGetters = NT.getter builder.modelGetters
    , modelSetters = NT.setter builder.modelSetters
    , modelBlanks = NT.appender Nothing builder.modelBlanks
    , msgGetters = NT.getter builder.msgGetters
    , msgSetters = NT.setter builder.msgSetters
    , msgBlanks = NT.appender Nothing builder.msgBlanks
    , apply = folder5 applierWithConfig builder.apply
    }



{-
   d88888b d8b   db d8888b. d88888b d888888b d88888b db      d8888b. .d8888.
   88'     888o  88 88  `8D 88'       `88'   88'     88      88  `8D 88'  YP
   88ooooo 88V8o 88 88   88 88ooo      88    88ooooo 88      88   88 `8bo.
   88~~~~~ 88 V8o88 88   88 88~~~      88    88~~~~~ 88      88   88   `Y8b.
   88.     88  V888 88  .8D 88        .88.   88.     88booo. 88  .8D db   8D
   Y88888P VP   V8P Y8888D' YP      Y888888P Y88888P Y88888P Y8888D' `8888Y'


-}


{-| Finalize the definition of the Fields you want to use in your forms.
-}
endFields :
    { apply :
        (acc -> empty -> empty -> empty -> empty -> empty -> acc)
        -> { blankModel : modelBlanks, blankMsg : msgBlanks, ctor : toFields }
        -> msgGetters
        -> msgSetters
        -> modelGetters
        -> modelSetters
        -> widgets
        -> { blankModel : modelBlanks, blankMsg : msgBlanks, ctor : fields }
    , ctor : toFields
    , widgets : () -> widgets
    , modelBlanks : () -> modelBlanks
    , modelGetters : { appendToGetters : () -> modelGetters, focus : focus3 }
    , modelSetters : { appendToSetters : () -> modelSetters, focus : focus2 }
    , msgBlanks : () -> msgBlanks
    , msgGetters : { appendToGetters : () -> msgGetters, focus : focus1 }
    , msgSetters : { appendToSetters : () -> msgSetters, focus : focus }
    }
    -> fields
endFields builder =
    let
        apply =
            endFolder5 builder.apply

        msgGetters =
            NT.endGetters builder.msgGetters

        msgSetters =
            NT.endSetters builder.msgSetters

        modelGetters =
            NT.endGetters builder.modelGetters

        modelSetters =
            NT.endSetters builder.modelSetters

        widgets =
            NT.endAppender builder.widgets

        blankMsg =
            NT.endAppender builder.msgBlanks

        blankModel =
            NT.endAppender builder.modelBlanks
    in
    apply
        { ctor = builder.ctor
        , blankMsg = blankMsg
        , blankModel = blankModel
        }
        msgGetters
        msgSetters
        modelGetters
        modelSetters
        widgets
        |> .ctor



{-
   d8888b.  .d8b.  d8888b. db   dD      .88b  d88.  .d8b.   d888b  d888888b  .o88b.
   88  `8D d8' `8b 88  `8D 88 ,8P'      88'YbdP`88 d8' `8b 88' Y8b   `88'   d8P  Y8
   88   88 88ooo88 88oobY' 88,8P        88  88  88 88ooo88 88         88    8P
   88   88 88~~~88 88`8b   88`8b        88  88  88 88~~~88 88  ooo    88    8b
   88  .8D 88   88 88 `88. 88 `88.      88  88  88 88   88 88. ~8~   .88.   Y8b  d8
   Y8888D' YP   YP 88   YD YP   YD      YP  YP  YP YP   YP  Y888P  Y888888P  `Y88P'


-}


applierWithConfig :
    (formMsg -> Maybe widgetMsg)
    -> (Maybe widgetMsg -> formMsg -> formMsg)
    -> (formModel -> Maybe widgetModel)
    -> (Maybe widgetModel -> formModel -> formModel)
    -> Widget config widgetModel widgetMsg output
    ->
        { blankModel : formModel
        , blankMsg : formMsg
        , ctor : (config -> Field formModel formMsg NoId widgetMsg widgetMsg output) -> fields
        }
    -> { blankModel : formModel, blankMsg : formMsg, ctor : fields }
applierWithConfig msgGetter msgSetter modelGetter modelSetter widgetFromConfig acc =
    let
        send_ msg_ =
            msgSetter (Just msg_) acc.blankMsg

        intercept_ =
            msgGetter

        field_ config =
            let
                widget =
                    widgetFromConfig config
            in
            convertToField
                { init =
                    let
                        ( widgetModel, widgetCmd ) =
                            widget.init
                    in
                    ( modelSetter (Just widgetModel) acc.blankModel
                    , Cmd.map send_ widgetCmd
                    )
                , load =
                    \input model ->
                        case
                            Maybe.map (widget.update input) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , update =
                    \msg model ->
                        case
                            Maybe.map2 widget.update (msgGetter msg) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , view =
                    \viewConfig model ->
                        Maybe.map (widget.view viewConfig) (modelGetter model)
                            |> Maybe.withDefault []
                            |> List.map (H.map send_)
                , submit =
                    \model ->
                        modelGetter model
                            |> Maybe.map
                                (\mdl ->
                                    widget.submit mdl
                                        |> Result.mapError
                                            (\errs ->
                                                List.map
                                                    (\err ->
                                                        { message = err
                                                        , isError = True
                                                        , locator = ByPath []
                                                        }
                                                    )
                                                    errs
                                            )
                                        |> Result.map (\output -> ( output, [] ))
                                )
                            |> Maybe.withDefault
                                (Err
                                    [ { message = "error in `applier` function"
                                      , isError = True
                                      , locator = ByPath []
                                      }
                                    ]
                                )
                , subscriptions =
                    \model ->
                        Maybe.map widget.subscriptions (modelGetter model)
                            |> Maybe.withDefault Sub.none
                            |> Sub.map send_
                , label = widget.label
                , send = send_
                , intercept = intercept_
                , blankModel = acc.blankModel
                }
    in
    { ctor = acc.ctor field_
    , blankMsg = acc.blankMsg
    , blankModel = acc.blankModel
    }


applierWithoutConfig :
    (formMsg -> Maybe widgetMsg)
    -> (Maybe widgetMsg -> formMsg -> formMsg)
    -> (formModel -> Maybe widgetModel)
    -> (Maybe widgetModel -> formModel -> formModel)
    -> InnerWidget widgetModel widgetMsg output
    ->
        { blankModel : formModel
        , blankMsg : formMsg
        , ctor : Field formModel formMsg NoId widgetMsg widgetMsg output -> fields
        }
    -> { blankModel : formModel, blankMsg : formMsg, ctor : fields }
applierWithoutConfig msgGetter msgSetter modelGetter modelSetter widget acc =
    let
        send_ msg_ =
            msgSetter (Just msg_) acc.blankMsg

        intercept_ =
            msgGetter

        field_ =
            convertToField
                { init =
                    let
                        ( widgetModel, widgetCmd ) =
                            widget.init
                    in
                    ( modelSetter (Just widgetModel) acc.blankModel
                    , Cmd.map send_ widgetCmd
                    )
                , load =
                    \input model ->
                        case
                            Maybe.map (widget.update input) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , update =
                    \msg model ->
                        case
                            Maybe.map2 widget.update (msgGetter msg) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , view =
                    \viewConfig model ->
                        Maybe.map (widget.view viewConfig) (modelGetter model)
                            |> Maybe.withDefault []
                            |> List.map (H.map send_)
                , submit =
                    \model ->
                        modelGetter model
                            |> Maybe.map
                                (\mdl ->
                                    widget.submit mdl
                                        |> Result.mapError
                                            (\errs ->
                                                List.map
                                                    (\err ->
                                                        { message = err
                                                        , isError = True
                                                        , locator = ByPath []
                                                        }
                                                    )
                                                    errs
                                            )
                                        |> Result.map (\output -> ( output, [] ))
                                )
                            |> Maybe.withDefault
                                (Err
                                    [ { message = "error in `applier` function"
                                      , isError = True
                                      , locator = ByPath []
                                      }
                                    ]
                                )
                , subscriptions =
                    \model ->
                        Maybe.map widget.subscriptions (modelGetter model)
                            |> Maybe.withDefault Sub.none
                            |> Sub.map send_
                , label = widget.label
                , send = send_
                , intercept = intercept_
                , blankModel = acc.blankModel
                }
    in
    { ctor = acc.ctor field_
    , blankMsg = acc.blankMsg
    , blankModel = acc.blankModel
    }


convertToField :
    { init : ( formModel, Cmd formMsg )
    , load : widgetMsg -> formModel -> ( formModel, Cmd formMsg )
    , update : formMsg -> formModel -> ( formModel, Cmd formMsg )
    , blankModel : formModel
    , view : ViewConfig -> formModel -> List (H.Html formMsg)
    , submit : formModel -> Result (List InternalFeedback) ( value, List InternalFeedback )
    , subscriptions : formModel -> Sub formMsg
    , send : widgetMsg -> formMsg
    , intercept : formMsg -> Maybe widgetMsg
    , label : String
    }
    -> Field formModel formMsg NoId widgetMsg widgetMsg value
convertToField args =
    Field
        { init =
            \path maybeId ->
                let
                    ( model, cmd ) =
                        args.init
                in
                ( Value path model
                , Cmd.map (ValueChanged path) cmd
                , Maybe.map (\id -> ( id, path )) maybeId |> Maybe.Extra.toList
                )
        , load =
            \input model ->
                case ( input, model ) of
                    ( Just widgetMsg, Value path innerModel ) ->
                        let
                            ( newModel, cmd ) =
                                args.load widgetMsg innerModel
                        in
                        ( Value path newModel
                        , Cmd.map (ValueChanged path) cmd
                        )

                    _ ->
                        ( model, Cmd.none )
        , update =
            \msg model ->
                case model of
                    Value path innerModel ->
                        case msg of
                            ValueChanged locator widgetMsg ->
                                if locator == path then
                                    let
                                        ( newModel, cmd ) =
                                            args.update widgetMsg innerModel
                                    in
                                    ( Value path newModel
                                    , Cmd.map (ValueChanged path) cmd
                                    )

                                else
                                    ( model, Cmd.none )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \viewConfig model ->
                let
                    path =
                        pathFromModel model

                    relevantFeedback =
                        List.filterMap
                            (\f ->
                                if f.path == path then
                                    Just { message = f.message, isError = f.isError }

                                else
                                    Nothing
                            )
                            viewConfig.feedback

                    ( model_, mapper ) =
                        case model of
                            Value _ model__ ->
                                ( model__, ValueChanged path )

                            _ ->
                                ( args.blankModel, always Noop )
                in
                args.view
                    { feedback = relevantFeedback
                    , id = pathToString path
                    , label = viewConfig.label
                    }
                    model_
                    |> List.map (H.map mapper)
                    |> ViewOne
        , submit =
            \checks model ->
                case model of
                    Value path model_ ->
                        args.submit model_
                            |> Result.mapError
                                (\errs ->
                                    List.map
                                        (\err ->
                                            { err
                                                | locator = ByPath path
                                            }
                                        )
                                        errs
                                )
                            |> Result.andThen
                                (\( output, warnings ) ->
                                    case runChecks checks model output of
                                        Ok ( output_, moreWarnings ) ->
                                            Ok ( output_, warnings ++ moreWarnings )

                                        Err feedback_ ->
                                            Err (warnings ++ feedback_)
                                )

                    _ ->
                        Err []
        , checks = []
        , subscriptions =
            \model ->
                case model of
                    Value path model_ ->
                        args.subscriptions model_
                            |> Sub.map (ValueChanged path)

                    _ ->
                        Sub.none
        , send =
            \maybeId msg ->
                case maybeId of
                    Nothing ->
                        Noop

                    Just id_ ->
                        ValueChangedById id_ (args.send msg)
        , intercept =
            \path msg ->
                case msg of
                    ValueChanged msgPath msgTuple ->
                        if msgPath == path then
                            args.intercept msgTuple

                        else
                            Nothing

                    _ ->
                        Nothing
        , label = args.label
        , maybeId = Nothing
        }


runChecks :
    List ( MaybeId, output2 -> Maybe ( Bool, String ) )
    -> Node formModel
    -> output2
    -> Result (List InternalFeedback) ( output2, List InternalFeedback )
runChecks checks model output =
    case
        List.filterMap
            (\( maybeId, check ) ->
                check output
                    |> Maybe.map
                        (\( isError, message ) ->
                            { message = message
                            , isError = isError
                            , locator =
                                case maybeId of
                                    Nothing ->
                                        locatorFromModel model

                                    Just id_ ->
                                        ById id_
                            }
                        )
            )
            checks
            |> List.partition (\{ isError } -> isError)
    of
        ( [], warnings ) ->
            Ok ( output, warnings )

        ( errs, warnings ) ->
            Err (errs ++ warnings)


folder5 :
    (headA -> headB -> headC -> headD -> headE -> accForHead -> accForTail)
    -> ((accForHead -> ( headA, tailA ) -> ( headB, tailB ) -> ( headC, tailC ) -> ( headD, tailD ) -> ( headE, tailE ) -> accForNext) -> toFolder5)
    -> (accForTail -> tailA -> tailB -> tailC -> tailD -> tailE -> accForNext)
    -> toFolder5
folder5 =
    let
        folder5_ foldHead foldTail accForHead tuple1 tuple2 tuple3 tuple4 tuple5 =
            let
                accForTail =
                    foldHead (NT.head tuple1) (NT.head tuple2) (NT.head tuple3) (NT.head tuple4) (NT.head tuple5) accForHead
            in
            foldTail accForTail (NT.tail tuple1) (NT.tail tuple2) (NT.tail tuple3) (NT.tail tuple4) (NT.tail tuple5)
    in
    do folder5_


do : (doThis -> doRest -> todoPrev) -> doThis -> (todoPrev -> done) -> doRest -> done
do doer doThis doPrev =
    \doRest -> doPrev (doer doThis doRest)


end : ender -> (ender -> done) -> done
end ender prev =
    prev ender


endFolder5 : ((acc -> empty -> empty -> empty -> empty -> empty -> acc) -> folder5) -> folder5
endFolder5 =
    end (\acc _ _ _ _ _ -> acc)



{-
   d8888b.  .d8b.  d888888b db   db
   88  `8D d8' `8b `~~88~~' 88   88
   88oodD' 88ooo88    88    88ooo88
   88~~~   88~~~88    88    88~~~88
   88      88   88    88    88   88
   88      YP   YP    YP    YP   YP


-}


pathToString : List Int -> String
pathToString path =
    path
        |> List.reverse
        |> List.map String.fromInt
        |> String.join "."


pathFromModel : Node model -> Path
pathFromModel model =
    case model of
        Value path _ ->
            path

        Product path _ ->
            path

        Sum path _ _ ->
            path

        Empty _ path ->
            path


locatorFromModel : Node model -> Locator
locatorFromModel =
    pathFromModel >> ByPath



{-
    d888b  d8888b.  .d8b.  d8888b. db   db db    db d888888b d88888D
   88' Y8b 88  `8D d8' `8b 88  `8D 88   88 88    88   `88'   YP  d8'
   88      88oobY' 88ooo88 88oodD' 88ooo88 Y8    8P    88       d8'
   88  ooo 88`8b   88~~~88 88~~~   88~~~88 `8b  d8'    88      d8'
   88. ~8~ 88 `88. 88   88 88      88   88  `8bd8'    .88.    d8' db
    Y888P  88   YD YP   YP 88      YP   YP    YP    Y888888P d88888P


-}


{-| Convert a `Model` value into a Graphviz DOT String, which you can visualize
using a tool such as <https://dreampuf.github.io/GraphvizOnline>

As the first argument, you should pass in `Debug.toString`.

-}
toDOT : (model -> String) -> Model model output -> String
toDOT debugToString (Model _ model) =
    let
        escape str =
            String.replace "\"" "\\\"" str

        regex =
            Regex.fromString "(?<=Just )[^,]+"
                |> Maybe.withDefault Regex.never

        match val =
            Regex.find regex (escape (debugToString val)) |> List.map .match |> List.head |> Maybe.withDefault ""

        emptyTypeToString emptyType =
            case emptyType of
                Succeed ->
                    { label = "Succeed", shape = "star" }

                Fail ->
                    { label = "Fail", shape = "octagon" }

        nodeLabel path innerLabel =
            "\"" ++ pathToString path ++ ": " ++ innerLabel ++ "\""

        toPathsAndLabels model_ =
            case model_ of
                Value path val ->
                    [ ( path
                      , nodeLabel path ("Value: " ++ match val)
                      , "oval"
                      )
                    ]

                Product path ms ->
                    ( path
                    , nodeLabel path "Product"
                    , "square"
                    )
                        :: List.concatMap toPathsAndLabels ms

                Sum path _ ms ->
                    ( path
                    , nodeLabel path "Choice"
                    , "diamond"
                    )
                        :: List.concatMap (\( _, m ) -> toPathsAndLabels m) ms

                Empty typ path ->
                    [ ( path
                      , nodeLabel path (emptyTypeToString typ).label
                      , (emptyTypeToString typ).shape
                      )
                    ]

        pathDict =
            model
                |> toPathsAndLabels
                |> List.sort
                |> List.indexedMap (\i ( p, l, c ) -> ( p, ( i, l, c ) ))
                |> Dict.fromList

        node index label_ colour =
            String.fromInt index
                ++ " [ label = "
                ++ label_
                ++ ", shape = \""
                ++ colour
                ++ "\", fixedsize = shape, style = filled, fillcolor = grey85, color = grey85 ]\n"

        edge n1 n2 =
            String.fromInt n1 ++ " -- " ++ String.fromInt n2 ++ "\n"

        ( nodes, edges ) =
            Dict.foldl
                (\path ( index, label_, colour ) list ->
                    ( node index label_ colour
                    , case Dict.get (List.drop 1 path) pathDict of
                        Just ( parentIndex, _, _ ) ->
                            edge parentIndex index

                        Nothing ->
                            ""
                    )
                        :: list
                )
                []
                pathDict
                |> List.unzip
                |> Tuple.mapBoth (List.sort >> String.concat) (List.sort >> String.concat)
    in
    "strict graph {\n" ++ nodes ++ edges ++ "}"



{-
   .d8888. d888888b db    db d8888b. d888888b  .d88b.
   88'  YP `~~88~~' 88    88 88  `8D   `88'   .8P  Y8.
   `8bo.      88    88    88 88   88    88    88    88
     `Y8b.    88    88    88 88   88    88    88    88
   db   8D    88    88b  d88 88  .8D   .88.   `8b  d8'
   `8888Y'    YP    ~Y8888P' Y8888D' Y888888P  `Y88P'


-}


{-| Turn a [`Field`](#Field) into an Elm `Program` that you can view in your
browser with in `elm reactor` for testing purposes.

This should only be used in development - to help you avoid accidentally
deploying it in production, you should pass in `Debug.toString` as the first
argument.

-}
studio :
    (output -> String)
    -> Field formModel formMsg id widgetMsg input output
    -> Program () (Model formModel output) (Msg formMsg)
studio debugToString field =
    Browser.document
        { init = \() -> init field
        , update = update field
        , view =
            \model ->
                { title = "Yafl Studio"
                , body =
                    [ H.h1 [] [ H.text "Your form" ]
                    , H.form []
                        (view field model
                         --|> List.map (\item -> H.div [] [ item ])
                        )
                    , H.h2 [] [ H.text "Output" ]
                    , case submit field model of
                        Ok output ->
                            H.div []
                                [ H.text "Validation succeeded!"
                                , H.pre [] [ H.text (debugToString output) ]
                                ]

                        Err errors ->
                            H.div []
                                [ H.text "Validation failed!"
                                , H.ul [] <|
                                    List.map
                                        (\( id_, err ) ->
                                            H.li [] [ H.text (id_ ++ ": " ++ err) ]
                                        )
                                        errors
                                ]
                    ]
                }
        , subscriptions = subscriptions field
        }
