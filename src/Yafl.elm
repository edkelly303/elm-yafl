module Yafl exposing
    ( Feedback
    , Field
    , HasAddress
    , Location
    , Model(..)
    , Msg
    , NoAddress
    , NotAddressable
    , Widget
    , addWidget
    , address
    , addressFromLocation
    , andChooseField
    , andMap
    , andThen
    , andUpdateField
    , choice
    , choose
    , chooseField
    , defineFields
    , endFields
    , fail
    , init
    , intercept
    , label
    , map
    , map2
    , option
    , pathFromLocation
    , send
    , showFeedback
    , submit
    , subscriptions
    , succeed
    , update
    , updateField
    , view
    )

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import List.Extra
import NestedTuple as NT
import Task


type Msg msg
    = ValueChanged Locator msg
    | OptionSelected Locator
    | Noop


type Model model
    = Value Location model
    | Both Location (Model model) (Model model)
    | OneOf Location { selected : Int } (List ( String, Model model ))
    | Empty Location


type Locator
    = ByPath Path
    | ByAddress String


type Location
    = Located Path
    | Addressed Path String


type alias Path =
    List Int


type alias MaybeAddress =
    Maybe String


type Field model msg address widgetMsg output
    = Field
        { init :
            Path -> MaybeAddress -> ( Model model, Cmd (Msg msg) )
        , update :
            Msg msg
            -> Model model
            -> ( Model model, Cmd (Msg msg) )
        , view :
            ViewConfig
            -> Model model
            -> List (H.Html (Msg msg))
        , submit :
            Model model
            -> Result (List Feedback) output
        , subscriptions :
            Model model
            -> Sub (Msg msg)
        , send : MaybeAddress -> widgetMsg -> Msg msg
        , intercept : MaybeAddress -> Msg msg -> Maybe widgetMsg
        , label : String
        , maybeAddress : MaybeAddress
        }


type HasAddress
    = HasAddress Never


type NoAddress
    = NoAddress Never


type NotAddressable
    = NotAddressable Never


type alias Widget model msg output =
    { init : ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , view : ViewConfig -> model -> List (H.Html msg)
    , submit : model -> Result (List String) output
    , subscriptions : model -> Sub msg
    , label : String
    }


type alias ViewConfig =
    { label : String
    , feedback : List Feedback
    }


type alias Feedback =
    { message : String, fail : Bool, path : Path }



{-
   db    db .d8888. d888888b d8b   db  d888b       d88888b d888888b d88888b db      d8888b. .d8888.
   88    88 88'  YP   `88'   888o  88 88' Y8b      88'       `88'   88'     88      88  `8D 88'  YP
   88    88 `8bo.      88    88V8o 88 88           88ooo      88    88ooooo 88      88   88 `8bo.
   88    88   `Y8b.    88    88 V8o88 88  ooo      88~~~      88    88~~~~~ 88      88   88   `Y8b.
   88b  d88 db   8D   .88.   88  V888 88. ~8~      88        .88.   88.     88booo. 88  .8D db   8D
   ~Y8888P' `8888Y' Y888888P VP   V8P  Y888P       YP      Y888888P Y88888P Y88888P Y8888D' `8888Y'


-}


init : Field model msg address innerMsg output -> ( Model model, Cmd (Msg msg) )
init (Field field) =
    field.init [ 0 ] field.maybeAddress


update : Field model msg address innerMsg output -> Msg msg -> Model model -> ( Model model, Cmd (Msg msg) )
update (Field field) msg model =
    field.update msg model


view : Field model msg address innerMsg output -> Model model -> List (H.Html (Msg msg))
view (Field field) model =
    let
        feedback =
            case field.submit model of
                Ok _ ->
                    []

                Err f ->
                    f
    in
    field.view
        { label = field.label
        , feedback = feedback
        }
        model


subscriptions : Field model msg address innerMsg output -> Model model -> Sub (Msg msg)
subscriptions (Field field) model =
    field.subscriptions model


submit : Field model msg address innerMsg output -> Model model -> Result (List Feedback) output
submit (Field field) model =
    field.submit model


label : String -> Field model msg address innerMsg output -> Field model msg address innerMsg output
label label_ (Field field) =
    Field { field | label = label_ }



{-
    .d8b.  d8888b. d8888b. d8888b. d88888b .d8888. .d8888. d888888b d8b   db  d888b
   d8' `8b 88  `8D 88  `8D 88  `8D 88'     88'  YP 88'  YP   `88'   888o  88 88' Y8b
   88ooo88 88   88 88   88 88oobY' 88ooooo `8bo.   `8bo.      88    88V8o 88 88
   88~~~88 88   88 88   88 88`8b   88~~~~~   `Y8b.   `Y8b.    88    88 V8o88 88  ooo
   88   88 88  .8D 88  .8D 88 `88. 88.     db   8D db   8D   .88.   88  V888 88. ~8~
   YP   YP Y8888D' Y8888D' 88   YD Y88888P `8888Y' `8888Y' Y888888P VP   V8P  Y888P


-}


address : String -> Field model msg NoAddress innerMsg output -> Field model msg HasAddress innerMsg output
address sendId_ (Field field) =
    Field { field | maybeAddress = Just sendId_ }


choose : Field model msg HasAddress widgetMsg output -> Cmd (Msg a)
choose (Field field) =
    case field.maybeAddress of
        Just address_ ->
            Task.perform identity (Task.succeed (OptionSelected (ByAddress address_)))

        Nothing ->
            Cmd.none


send : Field model msg HasAddress innerMsg output -> innerMsg -> Cmd (Msg msg)
send (Field field) msg =
    Task.perform identity (Task.succeed (field.send field.maybeAddress msg))


intercept : Field model msg HasAddress innerMsg output -> Msg msg -> Maybe innerMsg
intercept (Field field) =
    field.intercept field.maybeAddress


updateField : Field model msg address b output -> b -> Model model -> ( Model model, Cmd (Msg msg) )
updateField (Field field) innerMsg model =
    field.update (field.send field.maybeAddress innerMsg) model


andUpdateField : Field model msg HasAddress innerMsg output -> innerMsg -> ( Model model, Cmd (Msg msg) ) -> ( Model model, Cmd (Msg msg) )
andUpdateField field innerMsg ( model, cmd1 ) =
    updateField field innerMsg model
        |> Tuple.mapSecond (\cmd2 -> Cmd.batch [ cmd1, cmd2 ])


chooseField : Field model msg address widgetMsg output -> Model model -> ( Model model, Cmd (Msg msg) )
chooseField (Field field) model =
    case field.maybeAddress of
        Just address_ ->
            let
                msg =
                    OptionSelected (ByAddress address_)
            in
            field.update msg model

        Nothing ->
            ( model, Cmd.none )


andChooseField : Field model msg HasAddress widgetMsg output -> ( Model model, Cmd (Msg msg) ) -> ( Model model, Cmd (Msg msg) )
andChooseField field ( model, cmd1 ) =
    chooseField field model
        |> Tuple.mapSecond (\cmd2 -> Cmd.batch [ cmd1, cmd2 ])



{-
   db       .d88b.   .o88b.  .d8b.  d888888b d888888b  .d88b.  d8b   db
   88      .8P  Y8. d8P  Y8 d8' `8b `~~88~~'   `88'   .8P  Y8. 888o  88
   88      88    88 8P      88ooo88    88       88    88    88 88V8o 88
   88      88    88 8b      88~~~88    88       88    88    88 88 V8o88
   88booo. `8b  d8' Y8b  d8 88   88    88      .88.   `8b  d8' 88  V888
   Y88888P  `Y88P'   `Y88P' YP   YP    YP    Y888888P  `Y88P'  VP   V8P


-}


newLocation : Path -> Maybe String -> Location
newLocation path maybeAddress =
    case maybeAddress of
        Nothing ->
            Located path

        Just address_ ->
            Addressed path address_


getLocation : Model model -> Location
getLocation model =
    case model of
        Value loc _ ->
            loc

        Both loc _ _ ->
            loc

        OneOf loc _ _ ->
            loc

        Empty loc ->
            loc


getPath : Model model -> Path
getPath model =
    pathFromLocation (getLocation model)


pathFromLocation : Location -> Path
pathFromLocation location =
    case location of
        Located path_ ->
            path_

        Addressed path_ _ ->
            path_


addressFromLocation : Location -> Maybe String
addressFromLocation location =
    case location of
        Located _ ->
            Nothing

        Addressed _ address_ ->
            Just address_


isLocated : Locator -> Location -> Bool
isLocated locator location =
    case ( locator, location ) of
        ( ByPath path1, Located path2 ) ->
            path1 == path2

        ( ByPath path1, Addressed path2 _ ) ->
            path1 == path2

        ( ByAddress address1, Addressed _ address2 ) ->
            address1 == address2

        ( ByAddress _, Located _ ) ->
            False


toLocator : Location -> Locator
toLocator location =
    case location of
        Located path ->
            ByPath path

        Addressed _ address_ ->
            ByAddress address_



{-
    .o88b.  .d88b.  .88b  d88. d8888b. d888888b d8b   db  .d8b.  d888888b  .d88b.  d8888b. .d8888.
   d8P  Y8 .8P  Y8. 88'YbdP`88 88  `8D   `88'   888o  88 d8' `8b `~~88~~' .8P  Y8. 88  `8D 88'  YP
   8P      88    88 88  88  88 88oooY'    88    88V8o 88 88ooo88    88    88    88 88oobY' `8bo.
   8b      88    88 88  88  88 88~~~b.    88    88 V8o88 88~~~88    88    88    88 88`8b     `Y8b.
   Y8b  d8 `8b  d8' 88  88  88 88   8D   .88.   88  V888 88   88    88    `8b  d8' 88 `88. db   8D
    `Y88P'  `Y88P'  YP  YP  YP Y8888P' Y888888P VP   V8P YP   YP    YP     `Y88P'  88   YD `8888Y'


-}


succeed : output -> Field model msg address innerMsg output
succeed f =
    Field
        { init = \path maybeAddress -> ( Empty (newLocation path maybeAddress), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateOneOf locator model

                    _ ->
                        ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \_ -> Ok f
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
        }


fail : String -> Field model msg address innerMsg output
fail e =
    Field
        { init = \path maybeAddress -> ( Empty (newLocation path maybeAddress), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateOneOf locator model

                    _ ->
                        ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \_ -> Err [ { message = e, fail = True, path = [] } ]
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
        }


locateOneOf : Locator -> Model model -> ( Model model, Cmd msg )
locateOneOf locator model =
    case model of
        OneOf location selection options ->
            case
                List.Extra.findMap
                    (\( _, optionModel ) ->
                        if isLocated locator (getLocation optionModel) then
                            getPath optionModel
                                |> List.head

                        else
                            Nothing
                    )
                    options
            of
                Just selected ->
                    ( OneOf location
                        { selected = selected }
                        options
                    , Cmd.none
                    )

                Nothing ->
                    let
                        ( labels, models ) =
                            List.unzip options

                        ( newModels, cmds ) =
                            models
                                |> List.map (locateOneOf locator)
                                |> List.unzip
                    in
                    ( OneOf location selection (List.Extra.zip labels newModels)
                    , Cmd.batch cmds
                    )

        Value _ _ ->
            ( model, Cmd.none )

        Both location model1 model2 ->
            let
                ( newModel1, cmd1 ) =
                    locateOneOf locator model1

                ( newModel2, cmd2 ) =
                    locateOneOf locator model2
            in
            ( Both location newModel1 newModel2
            , Cmd.batch
                [ cmd1, cmd2 ]
            )

        Empty _ ->
            ( model, Cmd.none )


map :
    (output -> output2)
    -> Field model msg address innerMsg output
    -> Field model msg address innerMsg output2
map f (Field field) =
    Field
        { init = field.init
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , submit = \model -> field.submit model |> Result.map f
        , send = field.send
        , intercept = field.intercept
        , label = field.label
        , maybeAddress = field.maybeAddress
        }


map2 :
    (output1 -> output2 -> output3)
    -> Field model msg address1 innerMsg1 output1
    -> Field model msg address2 innerMsg2 output2
    -> Field model msg NotAddressable Never output3
map2 f (Field field1) (Field field2) =
    Field
        { init =
            \path maybeAddress ->
                let
                    ( model1, cmd1 ) =
                        field1.init (0 :: path) field1.maybeAddress

                    ( model2, cmd2 ) =
                        field2.init (1 :: path) field2.maybeAddress
                in
                ( Both (newLocation path maybeAddress) model1 model2
                , Cmd.batch
                    [ cmd1
                    , cmd2
                    ]
                )
        , update =
            \msg model ->
                case model of
                    Both location model1 model2 ->
                        let
                            ( newModel1, cmd1 ) =
                                field1.update msg model1

                            ( newModel2, cmd2 ) =
                                field2.update msg model2
                        in
                        ( Both location newModel1 newModel2
                        , Cmd.batch
                            [ cmd1, cmd2 ]
                        )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Both _ model1 model2 ->
                        field1.view { config | label = field1.label } model1
                            ++ field2.view { config | label = field2.label } model2

                    _ ->
                        []
        , subscriptions =
            \model ->
                case model of
                    Both _ model1 model2 ->
                        Sub.batch
                            [ field1.subscriptions model1
                            , field2.subscriptions model2
                            ]

                    _ ->
                        Sub.none
        , submit =
            \model ->
                case model of
                    Both _ model1 model2 ->
                        case ( field1.submit model1, field2.submit model2 ) of
                            ( Ok output1, Ok output2 ) ->
                                Ok (f output1 output2)

                            ( Err errs, Ok _ ) ->
                                Err errs

                            ( Ok _, Err errs ) ->
                                Err errs

                            ( Err errs1, Err errs2 ) ->
                                Err (errs2 ++ errs1)

                    _ ->
                        Err [ { message = "weird map2 error", fail = True, path = [] } ]
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
        }


andMap :
    Field model msg address1 innerMsg1 output1
    -> Field model msg address2 innerMsg2 (output1 -> output2)
    -> Field model msg NotAddressable Never output2
andMap (Field field1) (Field field2) =
    let
        (Field mapped) =
            map2 (\x f -> f x) (Field field1) (Field field2)
    in
    Field
        { mapped
            | view =
                \config model ->
                    case model of
                        Both _ model1 model2 ->
                            field2.view { config | label = field2.label } model2
                                ++ field1.view { config | label = field1.label } model1

                        _ ->
                            []
        }


andThen :
    (output -> Field model msg address innerMsg output2)
    -> Field model msg address innerMsg output
    -> Field model msg address innerMsg output2
andThen f (Field field) =
    Field
        { init = \path maybeAddress -> ( Empty (newLocation path maybeAddress), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateOneOf locator model

                    _ ->
                        ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit =
            \model ->
                case field.submit model of
                    Ok output ->
                        let
                            (Field field2) =
                                f output
                        in
                        field2.submit model

                    Err e ->
                        Err e
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
        }


showFeedback :
    (List Feedback -> H.Html (Msg msg))
    -> Field model msg address innerMsg output
    -> Field model msg address innerMsg output
showFeedback render (Field field) =
    Field
        { field
            | view =
                \config model ->
                    let
                        relevantFeedback =
                            List.filter (\f -> f.path == getPath model) config.feedback
                    in
                    field.view config model ++ [ render relevantFeedback ]
        }


choice : Field model msg NoAddress Never output
choice =
    Field
        { init = \path maybeAddress -> ( OneOf (newLocation path maybeAddress) { selected = 0 } [], Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \_ -> Err []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
        }


option :
    String
    -> Field model msg address innerMsg output
    -> Field model msg NoAddress Never output
    -> Field model msg NoAddress Never output
option radioLabel (Field field) (Field choice_) =
    Field
        { init =
            \path _ ->
                case choice_.init path choice_.maybeAddress of
                    ( OneOf location selection options, choiceCmd ) ->
                        let
                            ( fieldModel, fieldCmd ) =
                                field.init (List.length options :: path) field.maybeAddress
                        in
                        ( OneOf location selection (( radioLabel, fieldModel ) :: options)
                        , Cmd.batch [ choiceCmd, fieldCmd ]
                        )

                    _ ->
                        field.init path field.maybeAddress
        , update =
            \msg model ->
                case model of
                    OneOf location selection ((( fieldLabel, fieldModel ) :: choiceLabelsAndModels) as options) ->
                        let
                            fallback =
                                let
                                    ( newFieldModel, fieldCmd ) =
                                        field.update msg fieldModel

                                    ( newChoiceModels, choiceCmd ) =
                                        choice_.update msg (OneOf location selection choiceLabelsAndModels)
                                in
                                case newChoiceModels of
                                    OneOf _ _ options2 ->
                                        ( OneOf location selection (( fieldLabel, newFieldModel ) :: options2)
                                        , Cmd.batch [ choiceCmd, fieldCmd ]
                                        )

                                    _ ->
                                        ( model, Cmd.none )
                        in
                        case msg of
                            OptionSelected locator ->
                                case List.Extra.find (\( _, optionModel ) -> isLocated locator (getLocation optionModel)) options of
                                    Just ( _, optionModel ) ->
                                        ( OneOf location
                                            { selected =
                                                getPath optionModel
                                                    |> List.head
                                                    |> Maybe.withDefault 0
                                            }
                                            options
                                        , Cmd.none
                                        )

                                    Nothing ->
                                        fallback

                            _ ->
                                fallback

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    OneOf location meta (( fieldLabel, fieldModel ) :: choiceModels) ->
                        let
                            choiceViews =
                                choice_.view { config | label = choice_.label } (OneOf location meta choiceModels)
                                    |> List.drop 1

                            radio idx lbl =
                                H.label [ HA.class "yafl-radio-option" ]
                                    [ H.input
                                        [ HA.type_ "radio"
                                        , HA.name config.label
                                        , HE.onClick (OptionSelected (ByPath (idx :: pathFromLocation location)))
                                        , HA.checked (meta.selected == idx)
                                        ]
                                        []
                                    , H.text lbl
                                    ]

                            labels =
                                List.map Tuple.first (List.reverse choiceModels) ++ [ fieldLabel ]
                        in
                        H.fieldset [] (H.legend [] [ H.text config.label ] :: List.indexedMap radio labels)
                            :: (if meta.selected == List.length choiceModels then
                                    field.view { config | label = field.label } fieldModel

                                else
                                    choiceViews
                               )

                    _ ->
                        [ H.text "error: not a OneOf" ]
        , subscriptions =
            \model ->
                case model of
                    OneOf location meta (( _, fieldModel ) :: options) ->
                        Sub.batch
                            [ choice_.subscriptions (OneOf location meta options)
                            , field.subscriptions fieldModel
                            ]

                    _ ->
                        Sub.none
        , submit =
            \model ->
                case model of
                    OneOf location meta (( _, fieldModel ) :: options) ->
                        if meta.selected == List.length options then
                            field.submit fieldModel

                        else
                            choice_.submit (OneOf location meta options)

                    _ ->
                        Err []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = choice_.label
        , maybeAddress = Nothing
        }



{-
   db   d8b   db d888888b d8888b.  d888b  d88888b d888888b .d8888.
   88   I8I   88   `88'   88  `8D 88' Y8b 88'     `~~88~~' 88'  YP
   88   I8I   88    88    88   88 88      88ooooo    88    `8bo.
   Y8   I8I   88    88    88   88 88  ooo 88~~~~~    88      `Y8b.
   `8b d8'8b d8'   .88.   88  .8D 88. ~8~ 88.        88    db   8D
    `8b8' `8d8'  Y888888P Y8888D'  Y888P  Y88888P    YP    `8888Y'


-}


defineFields ctor =
    { ctor = ctor
    , fields = NT.define
    , modelGetters = NT.defineGetters
    , modelSetters = NT.defineSetters
    , modelBlanks = NT.define
    , msgGetters = NT.defineGetters
    , msgSetters = NT.defineSetters
    , msgBlanks = NT.define
    , apply = NT.define
    }


addWidget field builder =
    { ctor = builder.ctor
    , fields = NT.appender field builder.fields
    , modelGetters = NT.getter builder.modelGetters
    , modelSetters = NT.setter builder.modelSetters
    , modelBlanks = NT.appender Nothing builder.modelBlanks
    , msgGetters = NT.getter builder.msgGetters
    , msgSetters = NT.setter builder.msgSetters
    , msgBlanks = NT.appender Nothing builder.msgBlanks
    , apply = folder5 applier builder.apply
    }


applier msgGetter msgSetter modelGetter modelSetter fieldType acc =
    let
        send_ msg_ =
            msgSetter (Just msg_) acc.blankMsg

        intercept_ =
            msgGetter

        wrappedFieldType =
            wrapWithTrees
                { init =
                    let
                        ( model, cmd ) =
                            fieldType.init
                    in
                    ( modelSetter (Just model) acc.blankModel
                    , Cmd.map send_ cmd
                    )
                , update =
                    \msg model ->
                        case
                            Maybe.map2 fieldType.update (msgGetter msg) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , view =
                    \config model ->
                        Maybe.map (fieldType.view config) (modelGetter model)
                            |> Maybe.withDefault []
                            |> List.map (H.map send_)
                , submit =
                    \model ->
                        modelGetter model
                            |> Maybe.map
                                (\mdl ->
                                    fieldType.submit mdl
                                        |> Result.mapError (\errs -> List.map (\err -> { message = err, fail = True, path = [] }) errs)
                                )
                            |> Maybe.withDefault (Err [ { message = "error in `applier` function", fail = True, path = [] } ])
                , subscriptions =
                    \model ->
                        Maybe.map fieldType.subscriptions (modelGetter model)
                            |> Maybe.withDefault Sub.none
                            |> Sub.map send_
                , label = fieldType.label
                , send = send_
                , intercept = intercept_
                , blankModel = acc.blankModel
                }
    in
    { ctor = acc.ctor wrappedFieldType
    , blankMsg = acc.blankMsg
    , blankModel = acc.blankModel
    }


wrapWithTrees :
    { init : ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , blankModel : model
    , view : ViewConfig -> model -> List (H.Html msg)
    , submit : model -> Result (List Feedback) value
    , subscriptions : model -> Sub msg
    , send : innerMsg -> msg
    , intercept : msg -> Maybe innerMsg
    , label : String
    }
    -> Field model msg NoAddress innerMsg value
wrapWithTrees args =
    Field
        { init =
            \path maybeAddress ->
                let
                    location =
                        newLocation path maybeAddress
                in
                args.init
                    |> Tuple.mapBoth
                        (\model -> Value location model)
                        (\cmd -> Cmd.map (ValueChanged (toLocator location)) cmd)
        , update =
            \msg model ->
                internalUpdate args.update msg model
        , view =
            \config model ->
                let
                    location =
                        getLocation model

                    path =
                        pathFromLocation location

                    relevantFeedback =
                        List.filter (\f -> f.path == path) config.feedback

                    ( model_, mapper ) =
                        case model of
                            Value _ model__ ->
                                ( model__, ValueChanged (toLocator location) )

                            _ ->
                                ( args.blankModel, always Noop )
                in
                args.view { config | feedback = relevantFeedback } model_
                    |> List.map (H.map mapper)
        , submit =
            \model ->
                case model of
                    Value location model_ ->
                        args.submit model_
                            |> Result.mapError (\errs -> List.map (\err -> { err | path = pathFromLocation location }) errs)

                    _ ->
                        Err []
        , subscriptions =
            \model ->
                case model of
                    Value location model_ ->
                        args.subscriptions model_
                            |> Sub.map (ValueChanged (toLocator location))

                    _ ->
                        Sub.none
        , send =
            \maybeAddress msg ->
                case maybeAddress of
                    Nothing ->
                        Noop

                    Just address_ ->
                        ValueChanged (ByAddress address_) (args.send msg)
        , intercept =
            \maybeAddress msg ->
                case ( maybeAddress, msg ) of
                    ( Just address_, ValueChanged (ByAddress msgAddress) msgTuple ) ->
                        if msgAddress == address_ then
                            args.intercept msgTuple

                        else
                            Nothing

                    _ ->
                        Nothing
        , label = args.label
        , maybeAddress = Nothing
        }


internalUpdate update_ msg model =
    case model of
        Value location innerModel ->
            case msg of
                ValueChanged locator innerMsg ->
                    if isLocated locator location then
                        let
                            ( newModel, cmd ) =
                                update_ innerMsg innerModel
                        in
                        ( Value location newModel
                        , Cmd.map (ValueChanged (toLocator location)) cmd
                        )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Both location model1 model2 ->
            let
                ( newModel1, cmd1 ) =
                    internalUpdate update_ msg model1

                ( newModel2, cmd2 ) =
                    internalUpdate update_ msg model2
            in
            ( Both location newModel1 newModel2
            , Cmd.batch [ cmd1, cmd2 ]
            )

        OneOf location selection options ->
            let
                fallback =
                    let
                        ( labels, models ) =
                            List.unzip options

                        ( newModels, cmds ) =
                            models
                                |> List.map (internalUpdate update_ msg)
                                |> List.unzip
                    in
                    ( OneOf location selection (List.Extra.zip labels newModels)
                    , Cmd.batch cmds
                    )
            in
            case msg of
                OptionSelected locator ->
                    case
                        List.Extra.findMap
                            (\( _, optionModel ) ->
                                let
                                    optionLocation =
                                        getLocation optionModel
                                in
                                if isLocated locator optionLocation then
                                    optionLocation
                                        |> pathFromLocation
                                        |> List.head

                                else
                                    Nothing
                            )
                            options
                    of
                        Just selected ->
                            ( OneOf location { selected = selected } options
                            , Cmd.none
                            )

                        Nothing ->
                            fallback

                _ ->
                    fallback

        Empty _ ->
            ( model, Cmd.none )


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

        fields =
            NT.endAppender builder.fields

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
        fields
        |> .ctor



{-
   d8888b.  .d8b.  d8888b. db   dD      .88b  d88.  .d8b.   d888b  d888888b  .o88b.
   88  `8D d8' `8b 88  `8D 88 ,8P'      88'YbdP`88 d8' `8b 88' Y8b   `88'   d8P  Y8
   88   88 88ooo88 88oobY' 88,8P        88  88  88 88ooo88 88         88    8P
   88   88 88~~~88 88`8b   88`8b        88  88  88 88~~~88 88  ooo    88    8b
   88  .8D 88   88 88 `88. 88 `88.      88  88  88 88   88 88. ~8~   .88.   Y8b  d8
   Y8888D' YP   YP 88   YD YP   YD      YP  YP  YP YP   YP  Y888P  Y888888P  `Y88P'


-}


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


endFolder5 =
    end (\acc _ _ _ _ _ -> acc)
