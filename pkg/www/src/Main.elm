-- Features:
-- - SPA with header nav items (Freyground, GitHub) and main content (Welcome.)
-- - Uses Browser.sandbox (no effects); upgrade to Browser.element if ports/Cmd needed
module Main exposing (main)

import Browser
import Html exposing (Html, main_, nav, p, text)

type Msg = NoOp

view : () -> Html Msg
view _ =
    nav []
        [ nav []
            [ p [] [ text "Freyground" ]
            , p [] [ text "GitHub" ]
            ]
        , main_ []
            [ p [] [ text "Welcome." ] ]
        ]

main : Program () () Msg
main =
    Browser.sandbox { init = (), view = view, update = \_ m -> m }
