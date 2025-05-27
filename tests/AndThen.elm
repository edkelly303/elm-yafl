module AndThen exposing (..)

import Examples
import Expect
import Test
import Yafl


tests : Test.Test
tests =
    Test.describe
        "andThen"
        [ Test.test
            "Can use andUpdateField with an andThen-ed field that is within an andMap-ed field and has another andMap-ed field after it"
            (\() ->
                let
                    form =
                        Yafl.succeed (\x y -> ( x, y ))
                            |> Yafl.andMap field
                            |> Yafl.andMap (Yafl.succeed ())

                    field =
                        Examples.fields.string
                            |> Yafl.id "xxx"
                            |> Yafl.andThen Yafl.succeed
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField field "1"
                    |> Tuple.first
                    |> Yafl.submit form
                    |> Expect.equal (Ok ( "1", () ))
            )
        , Test.test
            "Can use andUpdateField with an andThen-ed field that is within an andMap-ed field"
            (\() ->
                let
                    form =
                        Yafl.succeed (\x -> x)
                            |> Yafl.andMap field

                    field =
                        Examples.fields.string
                            |> Yafl.andThen Yafl.succeed
                            |> Yafl.id "xxx"
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField field "1"
                    |> Tuple.first
                    |> Yafl.submit form
                    |> Expect.equal (Ok "1")
            )
        , Test.test
            "Can use andUpdateField with an andThen-ed field that is within an andMap-ed field and has another andMap-ed field before it"
            (\() ->
                let
                    form =
                        Yafl.succeed (\x y -> ( x, y ))
                            |> Yafl.andMap (Yafl.succeed ())
                            |> Yafl.andMap field

                    field =
                        Examples.fields.string
                            |> Yafl.id "xxx"
                            |> Yafl.andThen Yafl.succeed
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField field "1"
                    |> Tuple.first
                    |> Yafl.submit form
                    |> Expect.equal (Ok ( (), "1" ))
            )
        , Test.test
            "Can use andUpdateField with an andThen-ed field that is within an andMap-ed field and has another andMap-ed field before and after it"
            (\() ->
                let
                    form =
                        Yafl.succeed (\x y z -> ( x, y, z ))
                            |> Yafl.andMap (Yafl.succeed ())
                            |> Yafl.andMap field
                            |> Yafl.andMap (Yafl.succeed ())

                    field =
                        Examples.fields.string
                            |> Yafl.id "xxx"
                            |> Yafl.andThen Yafl.succeed
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField field "1"
                    |> Tuple.first
                    |> Yafl.submit form
                    |> Expect.equal (Ok ( (), "1", () ))
            )
        , Test.test
            "Can use andUpdateField with an andThen-ed field that is within another andThen-ed field"
            (\() ->
                let
                    form =
                        Examples.fields.string
                            |> Yafl.andThen (\_ -> field)

                    field =
                        Examples.fields.string
                            |> Yafl.id "xxx"
                            |> Yafl.andThen Yafl.succeed
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField field "1"
                    |> Tuple.first
                    |> Yafl.submit form
                    |> Expect.equal (Ok "1")
            )
        ]
