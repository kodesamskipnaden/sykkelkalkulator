module Tiltak.GsB_GsA exposing (..)

import BasicTiltak
import Field exposing (Field, SimpleField)
import Focus exposing ((=>), Focus)
import FormattedValue
    exposing
        ( formattedValue
        , formattedValueDefault
        , gangturerPerYear
        , installationCost
        , lengdeVeiKm
        , sykkelturerPerYear
        , value
        , yearlyMaintenance
        )
import GeneralForutsetninger exposing (verdisettinger)
import SpecificStates exposing (GsB_GsAState)
import Tiltak exposing (StateCalculationMethod, Tiltak(..), bindTiltak, sendTo)


tiltak : Tiltak
tiltak =
    let
        basicTiltakRecord =
            BasicTiltak.basicTiltakRecord specificState
    in
    Tiltak
        { basicTiltakRecord
            | title = \_ -> "GsB til GsA"
            , fields = \_ -> fields
            , yearlySyklistNytte = yearlySyklistNytte
            , yearlyFotgjengerNytte = yearlyFotgjengerNytte
            , yearlyTSGevinstNytte = yearlyTSGevinstNytte
            , yearlySyklistNytteInklOverfoert = yearlySyklistNytteInklOverfoert
            , yearlyFotgjengerNytteInklOverfoert = yearlyFotgjengerNytteInklOverfoert
            , yearlyTrafikantNytteInklOverfoert = yearlyTrafikantNytteInklOverfoert
            , yearlyHelsegevinstNytteInklOverfoert = yearlyHelsegevinstNytteInklOverfoert
            , yearlyTSGevinstNytteInklOverfoert = yearlyTSGevinstNytteInklOverfoert
            , yearlyEksterneEffekterNytteInklOverfoert = yearlyEksterneEffekterNytteInklOverfoert
            , investeringsKostInklRestverdi =
                \_ { gsB_GsA } ->
                    BasicTiltak.investeringsKostInklRestverdi
                        gsB_GsA
                        levetid
            , driftOgVedlihKost =
                \_ { gsB_GsA } ->
                    BasicTiltak.driftOgVedlihKost gsB_GsA
            , skyggepris =
                \this state ->
                    sendTo
                        this
                        .skyggeprisHelper
                        state
        }


initialState : GsB_GsAState
initialState =
    { installationCost = Just 0 |> formattedValue
    , yearlyMaintenance = formattedValueDefault
    , sykkelturerPerYear = Just 0 |> formattedValue
    , gangturerPerYear = Just 0 |> formattedValue
    , lengdeVeiKm = formattedValueDefault
    , oppetidPercent = Just 0.8 |> formattedValue
    , preferredToGraph = ""
    }


specificState :
    Focus
        { tiltakStates
            | gsB_GsA : GsB_GsAState
        }
        GsB_GsAState
specificState =
    Focus.create
        .gsB_GsA
        (\f tiltakStates ->
            { tiltakStates
                | gsB_GsA = f tiltakStates.gsB_GsA
            }
        )


fieldDefinitions : List SimpleField
fieldDefinitions =
    let
        oppetidPercent =
            Focus.create
                .oppetidPercent
                (\f specificState ->
                    { specificState | oppetidPercent = f specificState.oppetidPercent }
                )
    in
    [ { name = "installationCost"
      , title = "Installasjonskostnad"
      , placeholder = "Kostnaden ved å installere tiltaket en gang, kroner"
      , focus = specificState => installationCost
      , stepSize = 50000
      }
    , { name = "yearlyMaintenance"
      , title = "Økte årlige drifts- og vedlikeholdskostnader"
      , placeholder = BasicTiltak.yearlyMaintenancePlaceholder
      , focus = specificState => yearlyMaintenance
      , stepSize = 5000
      }
    , { name = "lengdeVeiKm"
      , title = "Veilengde i kilometer"
      , placeholder = "Lengde vei (km)"
      , focus = specificState => lengdeVeiKm
      , stepSize = 5
      }
    , { name = "sykkelturerPerYear"
      , title = "Antall sykkelturer per år"
      , placeholder = "Turer på mørke tider som får nytte av tiltaket"
      , focus = specificState => sykkelturerPerYear
      , stepSize = 50
      }
    , { name = "gangturerPerYear"
      , title = "Antall gangturer per år"
      , placeholder = "Turer på mørke tider som får nytte av tiltaket"
      , focus = specificState => gangturerPerYear
      , stepSize = 50
      }
    , { name = "oppetidPercent"
      , title = "Tiltakets oppetid, prosent"
      , placeholder = "Andel av aktuell tidsperiode hvor nivået GsA oppfylles (mindre enn 100% pga f.eks. at det tar tid fra nedbør skjer, til GsA-standard er gjenopprettet)"
      , focus = specificState => oppetidPercent
      , stepSize = 0.1
      }
    ]


levetid =
    40


fields : List Field
fields =
    fieldDefinitions
        |> Field.transformToFields


tidsbesparelsePerTur =
    -- minutter
    0.5


syklistForutsetninger gsB_GsA =
    { andelNyeBrukereFraBil = verdisettinger.andelNyeSyklisterFraBil
    , andelNyeBrukereFraKollektivtransport = verdisettinger.andelNyeSyklisterFraKollektivtransport
    , andelNyeBrukereGenererte = verdisettinger.andelNyeSyklisterGenererte
    , tsKostnad = verdisettinger.tsKostnadSykkel
    , eksterneKostnader = verdisettinger.eksterneKostnaderSykkel
    , turerPerYearMaybe = gsB_GsA.sykkelturerPerYear.value
    , totalReiseDistanceKm = verdisettinger.syklistTotalReiseDistanceKm
    , brukerGsB_GsA = verdisettinger.sykkelGsB_GsA
    , helseTSGevinstBruker = verdisettinger.helseTSGevinstSykkel
    , tsGevinstGsB_GsA = verdisettinger.tsGevinstGsB_GsASyklende
    }


fotgjengerForutsetninger gsB_GsA =
    { andelNyeBrukereFraBil = verdisettinger.andelNyeFotgjengereFraBil
    , andelNyeBrukereFraKollektivtransport = verdisettinger.andelNyeFotgjengereFraKollektivtransport
    , andelNyeBrukereGenererte = verdisettinger.andelNyeFotgjengereGenererte
    , tsKostnad = verdisettinger.tsKostnadGange
    , eksterneKostnader = verdisettinger.eksterneKostnaderGange
    , turerPerYearMaybe = gsB_GsA.gangturerPerYear.value
    , totalReiseDistanceKm = verdisettinger.fotgjengerTotalReiseDistanceKm
    , brukerGsB_GsA = verdisettinger.fotgjengerGsB_GsA
    , helseTSGevinstBruker = verdisettinger.helseTSGevinstGange
    , tsGevinstGsB_GsA = verdisettinger.tsGevinstGsB_GsAGaaende
    }


yearlySyklistNyttePerTur antallTurer =
    antallTurer * verdisettinger.reisetidSykkel * tidsbesparelsePerTur


yearlySyklistNytte this ({ gsB_GsA } as state) =
    Maybe.map2
        (\a b -> a * yearlySyklistNyttePerTur b)
        gsB_GsA.oppetidPercent.value
        gsB_GsA.sykkelturerPerYear.value


yearlyOverfoerteSykkelturer this ({ gsB_GsA } as state) =
    syklistForutsetninger gsB_GsA |> yearlyOverfoerteTurer this state


yearlySyklistNytteInklOverfoert this ({ gsB_GsA } as state) =
    let
        receiver =
            bindTiltak this state

        overfoertNytte =
            Maybe.map2
                (\antallTurer oppetidPercent ->
                    oppetidPercent * (yearlySyklistNyttePerTur antallTurer / 2)
                )
                (syklistForutsetninger gsB_GsA |> yearlyOverfoerteTurer this state)
                gsB_GsA.oppetidPercent.value
    in
    Maybe.map2 (+)
        (receiver .yearlySyklistNytte)
        overfoertNytte


yearlyFotgjengerNyttePerTur antallTurer =
    antallTurer * verdisettinger.reisetidGange * tidsbesparelsePerTur


yearlyFotgjengerNytte this ({ gsB_GsA } as state) =
    Maybe.map2
        (\a b -> a * yearlyFotgjengerNyttePerTur b)
        gsB_GsA.oppetidPercent.value
        gsB_GsA.gangturerPerYear.value


yearlyGangturer this ({ gsB_GsA } as state) =
    fotgjengerForutsetninger gsB_GsA |> yearlyOverfoerteTurer this state


yearlyFotgjengerNytteInklOverfoert this ({ gsB_GsA } as state) =
    let
        receiver =
            bindTiltak this state

        overfoertNytte =
            Maybe.map2
                (\antallTurer oppetidPercent ->
                    oppetidPercent * (yearlyFotgjengerNyttePerTur antallTurer / 2)
                )
                (fotgjengerForutsetninger gsB_GsA |> yearlyOverfoerteTurer this state)
                gsB_GsA.oppetidPercent.value
    in
    Maybe.map2 (+)
        (receiver .yearlyFotgjengerNytte)
        overfoertNytte


yearlyTrafikantNytteInklOverfoertForBruker this ({ gsB_GsA } as state) brukerForutsetninger =
    let
        receiver =
            bindTiltak this state

        overfoertNytte =
            Maybe.map4 (\a b c d -> a * b * c * d)
                gsB_GsA.oppetidPercent.value
                (Just brukerForutsetninger.totalReiseDistanceKm)
                (nyeTurerFra this state brukerForutsetninger .andelNyeBrukereFraBil)
                (Just verdisettinger.koekostnadBiler)
    in
    Maybe.map2 (+) (receiver .yearlyTrafikantNytte) overfoertNytte


yearlyTrafikantNytteInklOverfoert this ({ gsB_GsA } as state) =
    Maybe.map2 (+)
        (fotgjengerForutsetninger gsB_GsA |> yearlyTrafikantNytteInklOverfoertForBruker this state)
        (syklistForutsetninger gsB_GsA |> yearlyTrafikantNytteInklOverfoertForBruker this state)


yearlyHelsegevinstNytteInklOverfoert this ({ gsB_GsA } as state) =
    Maybe.map2 (+)
        (fotgjengerForutsetninger gsB_GsA
            |> yearlyHelsegevinstNytteInklOverfoertForBruker this state
        )
        (syklistForutsetninger gsB_GsA
            |> yearlyHelsegevinstNytteInklOverfoertForBruker this state
        )


yearlyHelsegevinstNytteInklOverfoertForBruker this ({ gsB_GsA } as state) brukerForutsetninger =
    Maybe.map4
        (\a b c d -> a * b * c * d)
        gsB_GsA.oppetidPercent.value
        (yearlyOverfoerteTurer this state brukerForutsetninger)
        (Just brukerForutsetninger.totalReiseDistanceKm)
        (Just brukerForutsetninger.helseTSGevinstBruker)


yearlyTSGevinstNytte : StateCalculationMethod
yearlyTSGevinstNytte this ({ gsB_GsA } as state) =
    Maybe.map2 (+)
        (fotgjengerForutsetninger gsB_GsA |> yearlyTSGevinstNytteForBrukere this state)
        (syklistForutsetninger gsB_GsA |> yearlyTSGevinstNytteForBrukere this state)


yearlyTSGevinstNytteForBrukere this ({ gsB_GsA } as state) brukerForutsetninger =
    Maybe.map3
        (\lengde turerPerYear oppetidPercent ->
            min lengde brukerForutsetninger.totalReiseDistanceKm
                * turerPerYear
                * brukerForutsetninger.tsKostnad
                * brukerForutsetninger.tsGevinstGsB_GsA
                * oppetidPercent
        )
        gsB_GsA.lengdeVeiKm.value
        brukerForutsetninger.turerPerYearMaybe
        gsB_GsA.oppetidPercent.value


yearlyTSGevinstNytteOverfoertForBrukere this ({ gsB_GsA } as state) brukerForutsetninger =
    let
        nyeTurerFunc =
            nyeTurerFra this state brukerForutsetninger

        beregning nyeTurerFraBil nyeTurerFraKollektiv nyeTurerFraGenererte =
            nyeTurerFraBil
                * (verdisettinger.tsKostnadBil
                    - brukerForutsetninger.tsKostnad
                  )
                + (nyeTurerFraKollektiv
                    * (verdisettinger.tsKostnadKollektiv
                        - brukerForutsetninger.tsKostnad
                      )
                  )
                - nyeTurerFraGenererte
                * brukerForutsetninger.tsKostnad
    in
    Maybe.map3 (\a b c -> a * b * c)
        gsB_GsA.oppetidPercent.value
        (Just brukerForutsetninger.totalReiseDistanceKm)
        (Maybe.map3
            beregning
            (nyeTurerFunc .andelNyeBrukereFraBil)
            (nyeTurerFunc .andelNyeBrukereFraKollektivtransport)
            (nyeTurerFunc .andelNyeBrukereGenererte)
        )


yearlyTSGevinstNytteOverfoert this ({ gsB_GsA } as state) =
    Maybe.map2 (+)
        (fotgjengerForutsetninger gsB_GsA |> yearlyTSGevinstNytteOverfoertForBrukere this state)
        (syklistForutsetninger gsB_GsA |> yearlyTSGevinstNytteOverfoertForBrukere this state)


yearlyTSGevinstNytteInklOverfoert this state =
    Maybe.map2 (+)
        (yearlyTSGevinstNytte this state)
        (yearlyTSGevinstNytteOverfoert this state)


yearlyEksterneEffekterNytteInklOverfoertForBruker this ({ gsB_GsA } as state) brukerForutsetninger =
    let
        nyeTurer =
            nyeTurerFra this state brukerForutsetninger

        overfoertFraBilNyttePerKm nyeTurerFraBil =
            nyeTurerFraBil
                * (verdisettinger.eksterneKostnaderBil
                    - brukerForutsetninger.eksterneKostnader
                  )

        overfoertFraKollektivNyttePerKm nyeTurerFraKollektiv =
            nyeTurerFraKollektiv
                * (verdisettinger.eksterneKostnaderKollektiv
                    - brukerForutsetninger.eksterneKostnader
                  )

        nytte nyeTurerFraBil nyeTurerFraKollektiv =
            brukerForutsetninger.totalReiseDistanceKm
                * (overfoertFraBilNyttePerKm nyeTurerFraBil + overfoertFraKollektivNyttePerKm nyeTurerFraKollektiv)
    in
    Maybe.map2 (*)
        gsB_GsA.oppetidPercent.value
        (Maybe.map2
            nytte
            (nyeTurer .andelNyeBrukereFraBil)
            (nyeTurer .andelNyeBrukereFraKollektivtransport)
        )


yearlyEksterneEffekterNytteInklOverfoert this ({ gsB_GsA } as state) =
    Maybe.map2 (+)
        (fotgjengerForutsetninger gsB_GsA |> yearlyEksterneEffekterNytteInklOverfoertForBruker this state)
        (syklistForutsetninger gsB_GsA |> yearlyEksterneEffekterNytteInklOverfoertForBruker this state)


yearlyOverfoerteTurer this state brukerForutsetninger =
    let
        receiver =
            nyeTurerFra this state brukerForutsetninger
    in
    Maybe.map3 (\a b c -> a + b + c)
        (receiver .andelNyeBrukereFraBil)
        (receiver .andelNyeBrukereFraKollektivtransport)
        (receiver .andelNyeBrukereGenererte)


nyeTurerFra this ({ gsB_GsA } as state) brukerForutsetninger andelsAccessor =
    Maybe.map3
        (\a b c -> a * b * c)
        brukerForutsetninger.turerPerYearMaybe
        (Just brukerForutsetninger.brukerGsB_GsA)
        (andelsAccessor brukerForutsetninger |> Just)
