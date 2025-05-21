module Location exposing
    ( fromModel
    , isLocated
    , locatorFromModel
    , new
    , pathFromModel
    , toLocator
    , toMaybeAddress
    , toPath
    , toString
    )

import Internal exposing (Location(..), Locator(..), MaybeAddress, Model(..), Path)


toString : Location -> String
toString location =
    location
        |> toPath
        |> List.reverse
        |> List.map String.fromInt
        |> String.join "."


new : Path -> Maybe String -> Location
new path maybeAddress =
    case maybeAddress of
        Nothing ->
            Located path

        Just address_ ->
            Addressed path address_


fromModel : Model model -> Location
fromModel model =
    case model of
        Value loc _ ->
            loc

        Both loc _ _ ->
            loc

        OneOf loc _ _ ->
            loc

        Empty loc ->
            loc


pathFromModel : Model model -> Path
pathFromModel =
    fromModel >> toPath


toPath : Location -> Path
toPath location =
    case location of
        Located path_ ->
            path_

        Addressed path_ _ ->
            path_


toMaybeAddress : Location -> MaybeAddress
toMaybeAddress location =
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


locatorFromModel : Model model -> Locator
locatorFromModel =
    fromModel >> toLocator
