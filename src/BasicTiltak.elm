module BasicTiltak exposing (..)

import BasicState exposing (..)
import Focus exposing ((=>), Focus)
import FormattedValue
    exposing
        ( FormattedValue
        , bompengeAndel
        , installationCost
        , value
        )
import GeneralForutsetninger exposing (verifiserteVerdisettinger)
import Maybe.Extra
import Regex
import Tiltak exposing (..)



{--
these are not valid in id's for css selectors which is what we use

!"#$%&'()*+,./:;<=>?@[\]^`{|}~

the toDomId function should probably just validate with a white-list
rather than a black list like it does now

--}


toDomId : String -> String
toDomId string =
    string
        -- add all invalid characters in domId here
        |> Regex.replace Regex.All (Regex.regex "[:/]") (\_ -> " ")
        -- whitespace is handled here
        |> String.words
        |> String.join "-"


maybeSum : List (Maybe number) -> Maybe number
maybeSum listOfMaybes =
    Maybe.Extra.combine listOfMaybes |> Maybe.map List.sum


allYearlyNytter this state =
    let
        f accessor =
            sendTo this accessor state
    in
    [ f .yearlySyklistNytteInklOverfoert
    , f .yearlyFotgjengerNytteInklOverfoert
    , f .yearlyTrafikantNytteInklOverfoert
    , f .yearlyHelsegevinstNytteInklOverfoert
    , f .yearlyTSGevinstNytteInklOverfoert
    , f .yearlyEksterneEffekterNytteInklOverfoert
    ]


yearlyNytteInklOverfoertSum this state =
    allYearlyNytter this state |> maybeSum


nytteInklOverfoert : StateCalculationMethod
nytteInklOverfoert this state =
    allYearlyNytter this state |> List.map (Maybe.map ((*) GeneralForutsetninger.afaktorVekst)) |> maybeSum


nettoNytteInklOverfoert : StateCalculationMethod
nettoNytteInklOverfoert this state =
    let
        f =
            bindTiltak this state
    in
    Maybe.map3 (\a b c -> a + b + c)
        (f .nytteInklOverfoert)
        (f .kostUtenSkyggepris)
        (f .skyggepris)


syklistNytteInklOverfoert : StateCalculationMethod
syklistNytteInklOverfoert =
    analysePeriodeNytteFor .yearlySyklistNytteInklOverfoert


fotgjengerNytteInklOverfoert =
    analysePeriodeNytteFor .yearlyFotgjengerNytteInklOverfoert


trafikantNytteInklOverfoert : StateCalculationMethod
trafikantNytteInklOverfoert =
    analysePeriodeNytteFor .yearlyTrafikantNytteInklOverfoert


helseGevinstNytteInklOverfoert =
    analysePeriodeNytteFor .yearlyHelsegevinstNytteInklOverfoert


tsGevinstNytteInklOverfoert : StateCalculationMethod
tsGevinstNytteInklOverfoert =
    analysePeriodeNytteFor .yearlyTSGevinstNytteInklOverfoert


eksterneEffekterNytteInklOverfoert =
    analysePeriodeNytteFor .yearlyEksterneEffekterNytteInklOverfoert


analysePeriodeNytteFor accessor this state =
    sendTo this accessor state |> Maybe.map ((*) GeneralForutsetninger.afaktorVekst)


kostUtenSkyggepris : StateCalculationMethod
kostUtenSkyggepris this state =
    let
        f =
            bindTiltak this state
    in
    Maybe.map2 (+)
        (f .investeringsKostInklRestverdi)
        (f .driftOgVedlihKost)


skyggeprisHelper this state =
    let
        calculation kostUtenSkyggepris =
            kostUtenSkyggepris * GeneralForutsetninger.skyggepris
    in
    sendTo this .kostUtenSkyggepris state
        |> Maybe.map calculation


yearlyTrafikantNytteInklOverfoert ((Tiltak object) as this) state =
    let
        nytte =
            object.yearlyTrafikantNytteInklOverfoertForBruker this state
    in
    Maybe.map2 (+)
        (object.syklistForutsetninger this state |> nytte)
        (object.fotgjengerForutsetninger this state |> nytte)


yearlyHelsegevinstNytteInklOverfoert ((Tiltak object) as this) state =
    let
        nytte =
            object.yearlyHelsegevinstNytteInklOverfoertForBruker this state
    in
    Maybe.map2 (+)
        (object.syklistForutsetninger this state |> nytte)
        (object.fotgjengerForutsetninger this state |> nytte)


yearlyTSGevinstNytte : StateCalculationMethod
yearlyTSGevinstNytte ((Tiltak object) as this) state =
    Maybe.map2 (+)
        (object.syklistForutsetninger this state |> object.yearlyTSGevinstNytteForBrukere this state)
        (object.fotgjengerForutsetninger this state |> object.yearlyTSGevinstNytteForBrukere this state)


yearlyTSGevinstNytteForBrukere ((Tiltak record) as this) state brukerForutsetninger =
    Maybe.map2
        (\turerPerYear lengde ->
            min lengde brukerForutsetninger.totalReiseDistanceKm
                * turerPerYear
                * brukerForutsetninger.tsKostnad
                * brukerForutsetninger.tsGevinstTiltak
        )
        brukerForutsetninger.turerPerYearMaybe
        (record.basicState state).lengdeVeiKm.value


yearlyTSGevinstNytteOverfoert ((Tiltak object) as this) state =
    let
        nytte =
            object.yearlyTSGevinstNytteOverfoertForBrukere this state
    in
    Maybe.map2 (+)
        (object.syklistForutsetninger this state |> nytte)
        (object.fotgjengerForutsetninger this state |> nytte)


yearlyTSGevinstNytteOverfoertForBrukere ((Tiltak object) as this) state brukerForutsetninger =
    let
        nyeTurerFunc =
            nyeTurerFra this state brukerForutsetninger

        tsKostnader =
            (object.basicState state).sted |> stedsForutsetninger |> .tsKostnader

        beregning nyeTurerFraBil nyeTurerFraKollektiv nyeTurerFraGenererte =
            brukerForutsetninger.totalReiseDistanceKm
                * (nyeTurerFraBil
                    * (tsKostnader.bil
                        - brukerForutsetninger.tsKostnad
                      )
                    + (nyeTurerFraKollektiv
                        * (tsKostnader.kollektivtransport
                            - brukerForutsetninger.tsKostnad
                          )
                      )
                    - nyeTurerFraGenererte
                    * brukerForutsetninger.tsKostnad
                  )
    in
    Maybe.map3
        beregning
        (nyeTurerFunc .andelNyeBrukereFraBil)
        (nyeTurerFunc .andelNyeBrukereFraKollektivtransport)
        (nyeTurerFunc .andelNyeBrukereGenererte)


yearlyTSGevinstNytteInklOverfoert : StateCalculationMethod
yearlyTSGevinstNytteInklOverfoert ((Tiltak object) as this) state =
    Maybe.map2 (+)
        (object.yearlyTSGevinstNytte this state)
        (object.yearlyTSGevinstNytteOverfoert this state)


yearlyEksterneEffekterNytteInklOverfoert ((Tiltak object) as this) state =
    let
        nytte =
            object.yearlyEksterneEffekterNytteInklOverfoertForBruker this state
    in
    Maybe.map2 (+)
        (object.syklistForutsetninger this state |> nytte)
        (object.fotgjengerForutsetninger this state |> nytte)


nyeTurerFra ((Tiltak object) as this) state brukerForutsetninger andelsAccessor =
    let
        nivaaForutsetninger =
            object.basicState state
                |> .nivaa
                |> object.nivaaForutsetninger
    in
    Maybe.map3
        (\a b c -> a * b * c)
        brukerForutsetninger.turerPerYearMaybe
        (Just nivaaForutsetninger.etterspoerselsEffekt)
        (andelsAccessor brukerForutsetninger |> Just)


yearlyOverfoerteSykkelturer : StateCalculationMethod
yearlyOverfoerteSykkelturer ((Tiltak object) as this) state =
    object.syklistForutsetninger this state |> yearlyOverfoerteTurer this state


yearlyOverfoerteGangturer ((Tiltak object) as this) state =
    object.fotgjengerForutsetninger this state |> yearlyOverfoerteTurer this state


yearlyOverfoerteTurer this state brukerForutsetninger =
    let
        receiver =
            nyeTurerFra this state brukerForutsetninger
    in
    Maybe.map3 (\a b c -> a + b + c)
        (receiver .andelNyeBrukereFraBil)
        (receiver .andelNyeBrukereFraKollektivtransport)
        (receiver .andelNyeBrukereGenererte)


yearlyTrafikantNytteInklOverfoertForBruker ((Tiltak object) as this) state brukerForutsetninger =
    let
        receiver =
            bindTiltak this state

        basicState =
            object.basicState state

        koekostnad =
            (stedsForutsetninger basicState.sted).koekostnadBiler

        overfoertNytte =
            Maybe.map3 (\a b c -> a * b * c)
                (Just brukerForutsetninger.totalReiseDistanceKm)
                (nyeTurerFra this state brukerForutsetninger .andelNyeBrukereFraBil)
                (Just koekostnad)
    in
    Maybe.map2 (+) (receiver .yearlyTrafikantNytte) overfoertNytte


yearlySyklistNytteInklOverfoert : StateCalculationMethod
yearlySyklistNytteInklOverfoert ((Tiltak object) as this) state =
    let
        receiver =
            bindTiltak this state

        overfoertNytte =
            Maybe.map
                (\a -> a / 2)
                (object.yearlySyklistNyttePerTur this state (object.syklistForutsetninger this state |> yearlyOverfoerteTurer this state))
    in
    Maybe.map2 (+) (receiver .yearlySyklistNytte) overfoertNytte


yearlyHelsegevinstNytteInklOverfoertForBruker this state brukerForutsetninger =
    Maybe.map3
        (\a b c -> a * b * c)
        (yearlyOverfoerteTurer this state brukerForutsetninger)
        (Just brukerForutsetninger.totalReiseDistanceKm)
        (Just brukerForutsetninger.helseGevinstBruker)


yearlySyklistNytte : StateCalculationMethod
yearlySyklistNytte ((Tiltak object) as this) ({ ledLys } as state) =
    object.yearlySyklistNyttePerTur this state (object.basicState state).sykkelturerPerYear.value


yearlyFotgjengerNytte ((Tiltak object) as this) ({ gsB_GsA } as state) =
    object.yearlyFotgjengerNyttePerTur this state (object.basicState state).gangturerPerYear.value


yearlyEksterneEffekterNytteInklOverfoertForBruker ((Tiltak object) as this) state brukerForutsetninger =
    let
        nyeTurer =
            nyeTurerFra this state brukerForutsetninger

        sted =
            (object.basicState state).sted

        eksterneKostnader =
            stedsForutsetninger sted |> .oevrigeEksterneKostnader

        overfoertFraBilNyttePerKm nyeTurerFraBil =
            nyeTurerFraBil * eksterneKostnader.bil

        overfoertFraKollektivNyttePerKm nyeTurerFraKollektiv =
            nyeTurerFraKollektiv * eksterneKostnader.kollektivtransport

        nytte nyeTurerFraBil nyeTurerFraKollektiv =
            brukerForutsetninger.totalReiseDistanceKm
                * (overfoertFraBilNyttePerKm nyeTurerFraBil
                    + overfoertFraKollektivNyttePerKm nyeTurerFraKollektiv
                  )
    in
    Maybe.map2 nytte
        (nyeTurer .andelNyeBrukereFraBil)
        (nyeTurer .andelNyeBrukereFraKollektivtransport)


tidsbesparelseMinPerTurSyklende ((Tiltak object) as this) state =
    let
        basicState =
            object.basicState state

        tidsbesparelseMinPerKm =
            (object.nivaaForutsetninger basicState.nivaa).tidsbesparelseSyklendeMinutterPerKilometer
    in
    Maybe.map2 (*)
        basicState.lengdeVeiKm.value
        (Just tidsbesparelseMinPerKm)


defaults =
    { syklistNytteInklOverfoert = syklistNytteInklOverfoert
    , fotgjengerNytteInklOverfoert = fotgjengerNytteInklOverfoert
    , trafikantNytteInklOverfoert = trafikantNytteInklOverfoert
    , tsGevinstNytteInklOverfoert = tsGevinstNytteInklOverfoert
    , helseGevinstNytteInklOverfoert = helseGevinstNytteInklOverfoert
    , eksterneEffekterNytteInklOverfoert = eksterneEffekterNytteInklOverfoert
    , nytteInklOverfoert = nytteInklOverfoert
    , kostUtenSkyggepris = kostUtenSkyggepris
    , nettoNytteInklOverfoert = nettoNytteInklOverfoert
    , skyggeprisHelper = skyggeprisHelper
    , graphId = \this -> sendTo this .domId |> (++) "c3graph"
    , domId = \this -> sendTo this .title |> toDomId
    , skyggepris = skyggeprisHelper
    , yearlyTSGevinstNytteOverfoert = yearlyTSGevinstNytteOverfoert
    , yearlyTrafikantNytteInklOverfoertForBruker = yearlyTrafikantNytteInklOverfoertForBruker
    }


basicTiltakRecord : Hooks a -> TiltakRecord
basicTiltakRecord hooks =
    { syklistNytteInklOverfoert = defaults.syklistNytteInklOverfoert
    , fotgjengerNytteInklOverfoert = defaults.fotgjengerNytteInklOverfoert
    , trafikantNytteInklOverfoert = defaults.trafikantNytteInklOverfoert
    , tsGevinstNytteInklOverfoert = defaults.tsGevinstNytteInklOverfoert
    , helseGevinstNytteInklOverfoert = defaults.helseGevinstNytteInklOverfoert
    , eksterneEffekterNytteInklOverfoert = defaults.eksterneEffekterNytteInklOverfoert
    , nytteInklOverfoert = defaults.nytteInklOverfoert
    , kostUtenSkyggepris = defaults.kostUtenSkyggepris
    , nettoNytteInklOverfoert = defaults.nettoNytteInklOverfoert
    , skyggeprisHelper = defaults.skyggeprisHelper
    , yearlyTSGevinstNytteOverfoert = defaults.yearlyTSGevinstNytteOverfoert
    , graphId = defaults.graphId
    , domId = defaults.domId
    , skyggepris = defaults.skyggepris
    , yearlySyklistNytte = yearlySyklistNytte
    , yearlySyklistNytteInklOverfoert = \_ _ -> Nothing
    , yearlyFotgjengerNytte = yearlyFotgjengerNytte
    , yearlyFotgjengerNytteInklOverfoert = \_ _ -> Nothing
    , yearlyTrafikantNytte = \_ _ -> Just 0
    , yearlyTSGevinstNytte = yearlyTSGevinstNytte
    , yearlyTrafikantNytteInklOverfoert = yearlyTrafikantNytteInklOverfoert
    , yearlyTSGevinstNytteInklOverfoert = yearlyTSGevinstNytteInklOverfoert
    , yearlyHelsegevinstNytteInklOverfoert = yearlyHelsegevinstNytteInklOverfoert
    , yearlyEksterneEffekterNytteInklOverfoert = yearlyEksterneEffekterNytteInklOverfoert
    , yearlyNytteInklOverfoertSum = yearlyNytteInklOverfoertSum
    , tidsbesparelseMinPerTurSyklende = tidsbesparelseMinPerTurSyklende
    , title = hooks.title
    , fields = hooks.fields
    , preferredField = preferredField hooks.specificStateFocus
    , preferredToGraphFocus = hooks.specificStateFocus => preferredToGraph
    , basicState = hooks.basicState
    , nivaaFocus = hooks.nivaaFocus
    , stedFocus = hooks.stedFocus
    , driftOgVedlihKost = hooks.driftOgVedlihKost
    , investeringsKostInklRestverdi = hooks.investeringsKostInklRestverdi
    , yearlySyklistNyttePerTur = hooks.yearlySyklistNyttePerTur
    , yearlyFotgjengerNyttePerTur = hooks.yearlyFotgjengerNyttePerTur
    , yearlyTrafikantNytteInklOverfoertForBruker = defaults.yearlyTrafikantNytteInklOverfoertForBruker
    , yearlyHelsegevinstNytteInklOverfoertForBruker = yearlyHelsegevinstNytteInklOverfoertForBruker
    , yearlyTSGevinstNytteForBrukere = yearlyTSGevinstNytteForBrukere
    , yearlyEksterneEffekterNytteInklOverfoertForBruker = yearlyEksterneEffekterNytteInklOverfoertForBruker
    , yearlyTSGevinstNytteOverfoertForBrukere = yearlyTSGevinstNytteOverfoertForBrukere
    , syklistForutsetninger = hooks.syklistForutsetninger
    , fotgjengerForutsetninger = hooks.fotgjengerForutsetninger
    , nivaaForutsetninger = hooks.nivaaForutsetninger
    }


preferredToGraph : Focus { b | preferredToGraph : a } a
preferredToGraph =
    Focus.create
        .preferredToGraph
        (\f state -> { state | preferredToGraph = f state.preferredToGraph })


preferredField specificStateFocus tiltak tiltakStates =
    let
        fieldName =
            Focus.get
                (getAttr tiltak .preferredToGraphFocus)
                tiltakStates

        filterByName field =
            field.name == fieldName
    in
    sendTo tiltak .fields
        |> List.filter filterByName
        |> List.head


investeringsKostInklRestverdi :
    { specificState
        | installationCost : FormattedValue Float
    }
    -> Float
    -> Maybe Float
investeringsKostInklRestverdi specificState levetid =
    specificState
        |> Focus.get (installationCost => value)
        |> Maybe.map ((*) <| GeneralForutsetninger.investeringsFaktor levetid)
        |> Maybe.map negate


driftOgVedlihKost : { specificState | yearlyMaintenance : FormattedValue Float } -> Maybe Float
driftOgVedlihKost specificState =
    specificState.yearlyMaintenance.value
        |> Maybe.map ((*) GeneralForutsetninger.afaktor)
        |> Maybe.map negate


type alias StedsForutsetninger =
    { koekostnadBiler : Float
    , overfoertFra :
        { bil : Float
        , kollektivtransport : Float
        , genererte : Float
        }
    , tsKostnader :
        { bil : Float
        , kollektivtransport : Float
        }
    , oevrigeEksterneKostnader :
        { bil : Float
        , kollektivtransport : Float
        }
    }


stedsForutsetninger :
    Sted
    -> StedsForutsetninger
stedsForutsetninger sted =
    case sted of
        Storby ->
            { overfoertFra =
                { bil = 30 / 100
                , kollektivtransport = 50 / 100
                , genererte = 20 / 100
                }
            , tsKostnader =
                { bil = 0.0981818
                , kollektivtransport = 0.0203143
                }
            , oevrigeEksterneKostnader =
                { bil = 0.6207036
                , kollektivtransport = 0.2641275
                }
            , koekostnadBiler = 1.3171136
            }

        Spredtbygd ->
            { overfoertFra =
                { bil = 70 / 100
                , kollektivtransport = 20 / 100
                , genererte = 10 / 100
                }
            , tsKostnader =
                { bil = 0.092307692
                , kollektivtransport = 0.036
                }
            , oevrigeEksterneKostnader =
                { bil = 0.1
                , kollektivtransport = 0.072136348
                }
            , koekostnadBiler = 0.0
            }

        LitenBy ->
            { overfoertFra =
                { bil = 50 / 100
                , kollektivtransport = 30 / 100
                , genererte = 20 / 100
                }
            , tsKostnader =
                { bil = 0.096503497
                , kollektivtransport = 0.023581731
                }
            , oevrigeEksterneKostnader =
                { bil = 0.355979021
                , kollektivtransport = 0.160726336
                }
            , koekostnadBiler = 0.17972028
            }


overfoertFraHelper (Tiltak object) state =
    let
        basicState =
            object.basicState state
    in
    (stedsForutsetninger basicState.sted).overfoertFra


basicSyklistForutsetninger ((Tiltak object) as this) state =
    let
        overfoert =
            overfoertFraHelper this state
    in
    { andelNyeBrukereFraBil = overfoert.bil
    , andelNyeBrukereFraKollektivtransport = overfoert.kollektivtransport
    , andelNyeBrukereGenererte = overfoert.genererte
    , tsKostnad = verifiserteVerdisettinger.tsKostnadSykkel
    , turerPerYearMaybe = (object.basicState state).sykkelturerPerYear.value
    , totalReiseDistanceKm = verifiserteVerdisettinger.syklistTotalReiseDistanceKm
    , helseGevinstBruker = verifiserteVerdisettinger.helseTSGevinstSykkel
    , tsGevinstTiltak = 0
    }


basicFotgjengerForutsetninger ((Tiltak object) as this) state =
    let
        overfoert =
            overfoertFraHelper this state
    in
    { andelNyeBrukereFraBil = overfoert.bil
    , andelNyeBrukereFraKollektivtransport = overfoert.kollektivtransport
    , andelNyeBrukereGenererte = overfoert.genererte
    , tsKostnad = verifiserteVerdisettinger.tsKostnadGange
    , totalReiseDistanceKm = verifiserteVerdisettinger.fotgjengerTotalReiseDistanceKm
    , helseGevinstBruker = verifiserteVerdisettinger.helseGevinstGange
    , turerPerYearMaybe = (object.basicState state).gangturerPerYear.value
    , tsGevinstTiltak = 0
    }
