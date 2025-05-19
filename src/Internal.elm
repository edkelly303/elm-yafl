module Internal exposing (Location(..), Locator(..), MaybeAddress, Model(..), Msg(..), Path)


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
