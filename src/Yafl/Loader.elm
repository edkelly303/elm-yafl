module Yafl.Loader exposing (..)

import List.Extra
import Yafl
import Yafl.Internal exposing (Loader(..), LoaderNode(..), Model(..), Node(..))


type alias Loader flags model =
    Yafl.Internal.Loader flags model


succeed : Loader flags model
succeed =
    Loader
        { load = \_ -> LEmpty
        }


map : (flags -> Maybe innerFlags) -> Loader innerFlags model -> Loader flags model
map flagsToThisFlags (Loader thisLoader) =
    Loader
        { load =
            \flags ->
                flags
                    |> Maybe.andThen flagsToThisFlags
                    |> thisLoader.load
        }


andMap : (flags -> Maybe innerFlags) -> Loader innerFlags model -> Loader flags model -> Loader flags model
andMap flagsToThisFlags (Loader thisLoader) (Loader previousLoader) =
    Loader
        { load =
            \flags ->
                LProduct
                    (flags |> Maybe.andThen flagsToThisFlags |> thisLoader.load)
                    (flags |> previousLoader.load)
        }


choice : Loader flags model
choice =
    Loader { load = \_ -> LSum [] }


option : (flags -> Maybe innerFlags) -> Loader innerFlags model -> Loader flags model -> Loader flags model
option flagsToThisFlags (Loader thisLoader) (Loader previousLoader) =
    Loader
        { load =
            \flags ->
                case previousLoader.load flags of
                    LSum nodes ->
                        LSum
                            ((flags
                                |> Maybe.andThen flagsToThisFlags
                                |> thisLoader.load
                             )
                                :: nodes
                            )

                    _ ->
                        LEmpty
        }



{-
   db       .d88b.   .d8b.  d8888b.
   88      .8P  Y8. d8' `8b 88  `8D
   88      88    88 88ooo88 88   88
   88      88    88 88~~~88 88   88
   88booo. `8b  d8' 88   88 88  .8D
   Y88888P  `Y88P'  YP   YP Y8888D'


-}


load : Loader flags model -> flags -> Model model output -> Result () (Model model output)
load (Loader loader) flags (Model node) =
    let
        loaderNode =
            loader.load (Just flags)
    in
    patch loaderNode node
        |> Result.map Model


patch : LoaderNode formModel -> Node formModel -> Result () (Node formModel)
patch loaderNode node =
    case ( loaderNode, node ) of
        ( LValue p, Value loc _ ) ->
            case p of
                Just n_ ->
                    Ok <| Value loc n_

                Nothing ->
                    Ok <| node

        ( LProduct p1 p2, Product loc typ n1 n2 ) ->
            Result.map2 (Product loc typ) (patch p1 n1) (patch p2 n2)

        ( LSum ps, Sum sel loc ns ) ->
            Result.map (Sum sel loc)
                (List.foldl
                    (\( p, ( lbl, n ) ) res ->
                        Result.map2
                            (\acc n_ -> ( lbl, n_ ) :: acc)
                            res
                            (patch p n)
                    )
                    (Ok [])
                    (List.Extra.zip ps ns)
                )

        ( LEmpty, Empty loc typ ) ->
            Ok <| Empty loc typ

        _ ->
            Err ()


makeLoader : (flags -> model) -> Loader flags model
makeLoader loader =
    Loader { load = \flags -> LValue (Maybe.map loader flags) }
