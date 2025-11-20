module Search exposing
    ( filter
    , filterD
    , filterMany
    , filterManyD
    , highlight
    , partition
    )

import Dict exposing (Dict)


sanitizedMatch : String -> String -> Bool
sanitizedMatch needle =
    String.contains (String.toLower needle) << String.toLower


match_ : (a -> String) -> String -> a -> Bool
match_ getter needle =
    sanitizedMatch needle << getter


checkEmpty : String -> (a -> a) -> (a -> a)
checkEmpty needle fc =
    if String.isEmpty needle then
        identity

    else
        fc


filterMany : (a -> List String) -> String -> List a -> List a
filterMany getter needle =
    checkEmpty needle <|
        List.filter (List.any (sanitizedMatch needle) << getter)


filterManyD : (comparable -> a -> List String) -> String -> Dict comparable a -> Dict comparable a
filterManyD getter needle =
    checkEmpty needle <|
        Dict.filter (\c v -> List.any (sanitizedMatch needle) <| getter c v)


filter : (a -> String) -> String -> List a -> List a
filter getter needle =
    checkEmpty needle <| List.filter (match_ getter needle)


partition : (a -> String) -> String -> List a -> ( List a, List a )
partition getter needle xs =
    if String.isEmpty needle then
        ( xs, [] )

    else
        List.partition (match_ getter needle) xs


filterD : (comparable -> a -> String) -> String -> Dict comparable a -> Dict comparable a
filterD getter needle =
    checkEmpty needle <| Dict.filter (\c -> match_ (getter c) needle)


highlight : { match : String -> a, rest : String -> a } -> String -> String -> List a
highlight { match, rest } term source =
    if String.isEmpty term then
        [ rest source ]

    else
        let
            needle =
                String.toLower term

            termLength =
                String.length term

            tokens : List { length : Int, isMatch : Bool }
            tokens =
                String.toLower source
                    |> String.split needle
                    |> List.concatMap
                        (\str ->
                            [ { length = String.length str, isMatch = False }
                            , { length = termLength, isMatch = True }
                            ]
                        )

            view : { length : Int, isMatch : Bool } -> ( List a, String ) -> ( List a, String )
            view { length, isMatch } ( acc, src ) =
                let
                    fn =
                        if isMatch then
                            match

                        else
                            rest

                    substring =
                        String.left length src

                    restOfString =
                        String.dropLeft length src
                in
                ( fn substring :: acc
                , restOfString
                )
        in
        List.foldl view ( [], source ) tokens
            |> Tuple.first
            |> List.reverse
