module Main exposing (main)

import Browser
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Widgets
import Yafl



{- Goal: create a form that will allow a user to create a value of the type
   below:
-}


type alias Dog =
    { name : String
    , funFact : FunFact
    }


type FunFact
    = LikesBones Bool
    | HasFleas Int



{-
   Step 1: Define your `Widget`s

   Look at the primitive Elm types mentioned in the `Dog` and `FunFact`
   definitions.

   We can see there's a `String` for the `Dog`'s name, plus a `Bool` and an
   `Int` in the `FunFact` definition.

   So, in order to build our form, we're going to need some `Widget`s that allow
   the user to input `String`s, `Bool`s and `Int`s.

   A `Widget` is basically just a little Elm program with `init`, `update`,
   `view` and `subscriptions` functions. (There are a couple of minor
   differences: the `init` function can't take flags as an argument, and the
   `view` function takes some config as an extra argument and outputs `List
   (Html msg)` instead of just `Html msg`.)

   A `Widget` also has a `label`, which is just a `String` that will be used to
   label the input in the HTML.

   Finally, a `Widget` has a `submit` function, which attempts to parse its
   internal state into a value of whatever type we want it to output.

   Below is an example of a simple `Widget` that outputs a `Bool`. I've also
   provided examples of inputs for `String` and `Int`, which you can find in
   `Widgets.elm`.
-}


boolWidget : Yafl.Widget Bool Bool Bool
boolWidget =
    { init = ( False, Cmd.none )
    , update =
        \msg _ ->
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
    , subscriptions = \_ -> Sub.none
    , submit = Ok
    , label = "Bool"
    }



{-
   Step 2: Define your `Field`s

   Over time, we might build up a library of dozens of different `Widgets`, but
   for any individual form, we may only need to use a small handful of them.

   So, the next step in the process is to select the subset of all our available
   `Widget`s that we want to use in our form. From now on, we will refer to
   these selected `Widget`s as `Field`s.

   We define our `Field`s as follows:
-}


fields =
    Yafl.defineFields
        (\bool int string ->
            { bool = bool
            , int = int
            , string = string
            }
        )
        |> Yafl.addWidget boolWidget
        |> Yafl.addWidget Widgets.int
        |> Yafl.addWidget Widgets.string
        |> Yafl.endFields



{-
   Now, wherever in our form we want to add a field that allows the user to
   input a `Bool`, we can simply call `fields.bool`.

   Incidentally, the process of defining the `Field`s we're going to use in our
   form also tells the Elm compiler what the types of the form's `Model` and
   `Msg` are going to be. You don't need to work these types out for yourself;
   the compiler (and hopefully your editor) will be able to infer them.

   In this case, they are as follows:
-}


type alias FormMsg =
    ( Maybe Bool
    , ( Maybe Widgets.IntMsg
      , ( Maybe String
        , ()
        )
      )
    )


type alias FormModel =
    ( Maybe Bool
    , ( Maybe Int
      , ( Maybe String
        , ()
        )
      )
    )



{-
   Step 3: Customise your `Field`s

   You might have a form that contains multiple `Field`s that produce the same
   data type - but those fields might signify different things. For example, one
   field might be for the user's first name, another for their last name. Or one
   for username, another for password.

   `Yafl` provides various functions that allow you to customise the `Field`s
   you've defined. For example:

   * `Yafl.label` allows you to set the label that is used in the HTML produced
   by the `Field`'s `view` function, so you can easily tell which field is
   which.

   * `Yafl.address` allows you to give the `Field` a unique ID. (This is useful
   for several reasons, and we'll come back to it later.)
-}


nameField : Yafl.Field FormModel FormMsg Yafl.HasAddress String String
nameField =
    fields.string
        |> Yafl.label "What is your dog's name?"
        |> Yafl.address "name-field"



{-
   Step 4: Assemble your form

   `Yafl` provides all the usual functional combinators that allow you to
   combine the outputs of your `Field`s to create larger and more complex data
   structures.

   For example, to combine two `Field`s into a `Field` that produces a product
   type (such as a record or tuple), we can use `Yafl.succeed` and
   `Yafl.andMap`. This is a pattern that you may recognise from packages like
   `NoRedInk/elm-json-decode-pipeline`.
-}


dogField : Yafl.Field FormModel FormMsg Yafl.NoAddress Never Dog
dogField =
    Yafl.succeed Dog
        |> Yafl.andMap nameField
        |> Yafl.andMap funFactField



{-
   Similarly, we can also combine `Field`s into custom types (sum types) using
   `Yafl.choice` and 'Yafl.option`.
-}


funFactField : Yafl.Field FormModel FormMsg Yafl.NoAddress Never FunFact
funFactField =
    Yafl.choice
        |> Yafl.label "A fun fact about your dog is:"
        |> Yafl.option "They have fleas" hasFleasField
        |> Yafl.option "They like bones" likesBonesField



{-
   `Yafl.map` allows us to map the output value of a field to a value of a
   different type.

   This is especially useful for creating custom type variants - in the example
   below, we map the `Bool` output from `fields.bool` to `LikesBones Bool`, a
   variant of our `FunFact` type.
-}


likesBonesField : Yafl.Field FormModel FormMsg Yafl.HasAddress Bool FunFact
likesBonesField =
    fields.bool
        |> Yafl.map LikesBones
        |> Yafl.label "Do they _really_ like bones?"
        |> Yafl.address "likes-bones-field"



{-
   `Yafl.andThen` is useful for validating outputs, in combination with
   `Yafl.succeed` and `Yafl.fail`, and also for asking the user for more
   information.

   When a field could possibly fail validation, we may want to show the user an
   error message. You can customise how errors are displayed with
   `Yafl.showFeedback`.
-}


hasFleasField : Yafl.Field FormModel FormMsg Yafl.NoAddress Widgets.IntMsg FunFact
hasFleasField =
    fields.int
        |> Yafl.label "How many fleas do they have?"
        |> Yafl.showFeedback viewFeedback
        |> Yafl.andThen
            (\numberOfFleas ->
                if numberOfFleas < 1 then
                    Yafl.fail "They must have at least one?!"
                        |> Yafl.showFeedback viewFeedback

                else if numberOfFleas < 10 then
                    Yafl.choice
                        |> Yafl.label "Hmm, that's not very many, did you check their belly?"
                        |> Yafl.option "Yes, that's really all the fleas they have" (Yafl.succeed True)
                        |> Yafl.option "No, I'll check the belly..." (Yafl.succeed False)
                        |> Yafl.andThen
                            (\yes ->
                                if yes then
                                    Yafl.succeed (HasFleas numberOfFleas)

                                else
                                    fields.int
                                        |> Yafl.label "Ok, how many extra fleas did you find on their belly?"
                                        |> Yafl.showFeedback viewFeedback
                                        |> Yafl.andThen
                                            (\extraFleas ->
                                                if extraFleas < 0 then
                                                    Yafl.fail "C'mon, you can't have negative fleas!"
                                                        |> Yafl.showFeedback viewFeedback

                                                else
                                                    Yafl.succeed (HasFleas (numberOfFleas + extraFleas))
                                            )
                            )

                else
                    Yafl.succeed (HasFleas numberOfFleas)
            )


viewFeedback : List Yafl.Feedback -> H.Html msg
viewFeedback feedback =
    case feedback of
        [] ->
            H.text ""

        _ ->
            H.ul
                [ HA.style "list-style-type" "none"
                , HA.style "margin" "0px"
                , HA.style "padding" "0px"
                ]
                (List.map
                    (\f -> H.li [] [ H.small [] [ H.text ("⚠️ " ++ f.message) ] ])
                    feedback
                )



{-
   Step 5: Wire your form into your application

   To see our `Dog` form in action, we just need to call `Yafl.init`,
   `Yafl.update`, `Yafl.view` and `Yafl.subscriptions` in the `init`, `update`,
   `view` and `subscriptions` functions of our main Elm application.

   The simplest possible example is something like this:
-}


main_ : Program () (Yafl.Model FormModel) (Yafl.Msg FormMsg)
main_ =
    Browser.element
        { init =
            \() ->
                Yafl.init dogField
        , update =
            \msg model ->
                Yafl.update dogField msg model
        , view =
            \model ->
                H.form [] (Yafl.view dogField model)
        , subscriptions =
            \model ->
                Yafl.subscriptions dogField model
        }



{-
   Appendix: Advanced stuff!

   Below is a slightly more realistic example of integrating a form into an app
   that has its own `Model` and `Msg` types.

   This example also shows how we can use some of `Yafl`'s more advanced
   features to handle situations where the state of one field needs to depend on
   the state of another.

   If we need the state of field A to depend on the state of field B, we can use
   `Yafl.intercept` in our app's `update` function to intercept messages sent to
   field B.

   If necessary, we can then send messages to field A with `Yafl.send`. If field
   A is a `Yafl.option`, we can also select it using `Yafl.choose`.

   Both field B and Field B need to have addresses set with `Yafl.address` for
   this to work.
-}


type Msg
    = FormUpdated (Yafl.Msg FormMsg)
    | FormSubmitted


type Model
    = EditingForm (Yafl.Model FormModel)
    | ViewingDog Dog


main : Program () Model Msg
main =
    Browser.element
        { init =
            \() ->
                Yafl.init dogField
                    |> Tuple.mapFirst EditingForm
                    |> Tuple.mapSecond (Cmd.map FormUpdated)
        , update =
            \msg model ->
                case ( msg, model ) of
                    ( FormUpdated formMsg, EditingForm formModel ) ->
                        let
                            prettySureThisGuyLikesBonesCmd =
                                -- If the user sets the `name` field to "Boney
                                -- M", then we automatically select the
                                -- `LikesBones` variant and set the `Bool`
                                -- within it to `True`
                                case Yafl.intercept nameField formMsg of
                                    Just "Boney M" ->
                                        Cmd.batch
                                            [ Yafl.send likesBonesField True
                                            , Yafl.select likesBonesField
                                            ]

                                    _ ->
                                        Cmd.none

                            ( newFormModel, cmd ) =
                                Yafl.update dogField formMsg formModel
                        in
                        ( EditingForm newFormModel
                        , [ cmd, prettySureThisGuyLikesBonesCmd ]
                            |> Cmd.batch
                            |> Cmd.map FormUpdated
                        )

                    ( FormSubmitted, EditingForm formModel ) ->
                        ( case Yafl.submit dogField formModel of
                            Ok dog ->
                                ViewingDog dog

                            Err _ ->
                                EditingForm formModel
                        , Cmd.none
                        )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \model ->
                case model of
                    EditingForm formModel ->
                        H.form [ HE.onSubmit FormSubmitted ]
                            ((Yafl.view dogField formModel
                                |> List.map (H.map FormUpdated)
                             )
                                ++ [ H.button [] [ H.text "Submit" ] ]
                            )

                    ViewingDog dog ->
                        H.text
                            (dog.name
                                ++ (case dog.funFact of
                                        LikesBones True ->
                                            " likes bones."

                                        LikesBones False ->
                                            " doesn't like bones, what a weirdo!"

                                        HasFleas numberOfFleas ->
                                            " has " ++ String.fromInt numberOfFleas ++ " fleas."
                                   )
                            )
        , subscriptions =
            \model ->
                case model of
                    EditingForm formModel ->
                        Yafl.subscriptions dogField formModel
                            |> Sub.map FormUpdated

                    ViewingDog _ ->
                        Sub.none
        }
