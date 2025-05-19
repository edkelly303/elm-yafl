module Visualize exposing (draw)

import Html as H
import Html.Attributes as HA
import Internal
import Location
import Svg
import Svg.Attributes
import TreeDiagram
import TreeDiagram.Svg


draw : Internal.Model model -> H.Html msg
draw tree =
    H.div
        [ HA.style "display" "flex"
        , HA.style "width" "100vw"
        , HA.style "justify-content" "center"
        ]
        [ TreeDiagram.Svg.draw
            { defaultTreeLayout
                | siblingDistance = 200
                , subtreeDistance = 200
                , padding = 80
            }
            drawNode
            drawLine
            (toTreeDiagram tree)
        ]


showLocation : Internal.Location -> List String
showLocation location =
    Location.toString location
        :: (case Location.toMaybeAddress location of
                Nothing ->
                    []

                Just a ->
                    [ a ]
           )


toTreeDiagram : Internal.Model model -> TreeDiagram.Tree ( String, List String )
toTreeDiagram model =
    case model of
        Internal.Empty location ->
            TreeDiagram.node
                ( "lavender"
                , "Empty" :: showLocation location
                )
                []

        Internal.Value location _ ->
            TreeDiagram.node
                ( "lavenderblush"
                , "Value" :: showLocation location
                )
                []

        Internal.Both location t1 t2 ->
            TreeDiagram.node
                ( "lightYellow"
                , "Both" :: showLocation location
                )
                [ toTreeDiagram t1, toTreeDiagram t2 ]

        Internal.OneOf location meta ts ->
            TreeDiagram.node
                ( "honeydew"
                , [ "OneOf"
                  , "selected: " ++ String.fromInt meta.selected
                  ]
                    ++ showLocation location
                )
                (List.map (Tuple.second >> toTreeDiagram) (List.reverse ts))


defaultTreeLayout : TreeDiagram.TreeLayout
defaultTreeLayout =
    TreeDiagram.defaultTreeLayout


drawLine : ( Float, Float ) -> Svg.Svg msg
drawLine ( targetX, targetY ) =
    Svg.line
        [ Svg.Attributes.x1 "0"
        , Svg.Attributes.y1 "0"
        , Svg.Attributes.x2 (String.fromFloat targetX)
        , Svg.Attributes.y2 (String.fromFloat targetY)
        , Svg.Attributes.stroke "black"
        ]
        []


drawNode : ( String, List String ) -> Svg.Svg msg
drawNode ( colour, strings ) =
    let
        padding =
            10

        height =
            padding + List.length strings * 20
    in
    Svg.g
        []
        (Svg.rect
            [ Svg.Attributes.width "150"
            , Svg.Attributes.height (String.fromInt height)
            , Svg.Attributes.fill colour
            , Svg.Attributes.transform ("translate(-75," ++ String.fromInt (-2 * padding) ++ ")")
            ]
            []
            :: List.indexedMap
                (\idx string ->
                    Svg.text_
                        [ Svg.Attributes.width "100"
                        , Svg.Attributes.textAnchor "middle"
                        , Svg.Attributes.y (String.fromInt (20 * idx))
                        ]
                        [ Svg.text string ]
                )
                strings
        )
