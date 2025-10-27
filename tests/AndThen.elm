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
                            |> Yafl.andMap .x field
                            |> Yafl.andMap .y (Yafl.succeed ())

                    field =
                        Examples.fields.string
                            |> Yafl.id "xxx"
                            |> Yafl.andThen Yafl.succeed
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField form field "1"
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
                            |> Yafl.andMap .x field

                    field =
                        Examples.fields.string
                            |> Yafl.andThen Yafl.succeed
                            |> Yafl.id "xxx"
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField form field "1"
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
                            |> Yafl.andMap .x (Yafl.succeed ())
                            |> Yafl.andMap .y field

                    field =
                        Examples.fields.string
                            |> Yafl.id "xxx"
                            |> Yafl.andThen Yafl.succeed
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField form field "1"
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
                            |> Yafl.andMap .x (Yafl.succeed ())
                            |> Yafl.andMap .y field
                            |> Yafl.andMap .z (Yafl.succeed ())

                    field =
                        Examples.fields.string
                            |> Yafl.id "xxx"
                            |> Yafl.andThen Yafl.succeed
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField form field "1"
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
                    |> Yafl.andUpdateField form field "1"
                    |> Tuple.first
                    |> Yafl.submit form
                    |> Expect.equal (Ok "1")
            )
        , Test.test
            "Can use andSelectField with a choice field that is within an andThen-ed field"
            (\() ->
                let
                    form =
                        str
                            |> Yafl.andThen
                                (\str_ ->
                                    if str_ == "a" then
                                        field

                                    else
                                        Yafl.succeed True
                                )

                    str =
                        Examples.fields.string
                            |> Yafl.id "str"

                    yes =
                        Yafl.succeed True

                    no =
                        Yafl.succeed False
                            |> Yafl.id "no"

                    field =
                        Yafl.choice
                            |> Yafl.option "yes" .yes yes
                            |> Yafl.option "no" .no no
                in
                form
                    |> Yafl.init
                    |> Yafl.andUpdateField form str "a"
                    |> Yafl.andSelectField form no
                    |> Tuple.first
                    |> Yafl.submit form
                    |> Expect.equal (Ok False)
            )
        ]
