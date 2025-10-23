module Yafl.Internal exposing (..)

import Html as H


{-| Internal type, we probably don't need to expose this...
-}
type Locator
    = ByPath Path
    | ById String


type Location
    = Located Path
    | Identified Path String


type alias MaybeId =
    Maybe String


{-| The top-level model type for your form.
-}
type Model formModel output
    = Model (Node formModel)


type Node formModel
    = Value Location formModel
    | Product ProductType Location (Node formModel) (Node formModel)
    | Sum Location { selected : Int } (List ( String, Node formModel ))
    | Empty EmptyType Location


type ProductType
    = Map2
    | AndThen


type EmptyType
    = Succeed
    | Fail
    | NoValue


{-| The top-level message type for your form.
-}
type Msg formMsg
    = ValueChanged Locator formMsg
    | OptionSelected Locator
    | Noop


{-| An internal data type used to track the location of a [`Field`](#Field) within the form.
-}
type alias Path =
    List Int


{-| Forms are composed of `Field`s - this is the main data type we'll be using in this package.
-}
type Field formModel formMsg id widgetMsg output
    = Field
        { init :
            Path -> MaybeId -> ( Node formModel, Cmd (Msg formMsg) )
        , update :
            Msg formMsg
            -> Node formModel
            -> ( Node formModel, Cmd (Msg formMsg) )
        , view :
            InternalViewConfig
            -> Node formModel
            -> List (H.Html (Msg formMsg))
        , submit :
            List ( MaybeId, output -> Maybe String )
            -> Node formModel
            -> Result (List InternalFeedback) output
        , checks : List ( MaybeId, output -> Maybe String )
        , subscriptions :
            Node formModel
            -> Sub (Msg formMsg)
        , send : MaybeId -> widgetMsg -> Msg formMsg
        , intercept : MaybeId -> Msg formMsg -> Maybe widgetMsg
        , label : String
        , maybeId : MaybeId
        }


{-| Indicates that a [`Field`](#Field) has been given an `id`, and can therefore be
used with [`intercept`](#intercept), [`send`](#send), etc. See the docs for [`id`](#id).
-}
type HasId
    = HasId Never


{-| Indicates that a [`Field`](#Field) has not been given an `id`. See the docs for
[`id`](#id).
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
    String


type alias InternalViewConfig =
    { label : String
    , id : String
    , feedback : List InternalFeedback
    }


type alias InternalFeedback =
    { message : String, fail : Bool, locator : Locator }


type Loader flags model
    = Loader
        { load : Maybe flags -> LoaderNode model
        }


type LoaderNode model
    = LValue (Maybe model)
    | LProduct (LoaderNode model) (LoaderNode model)
    | LSum (List (LoaderNode model))
    | LEmpty
