{-# LANGUAGE OverloadedStrings, DataKinds, TypeOperators, FlexibleInstances #-}

module Api
  ( Coordinate(..)
  , runRoute
  , runExceptT
  , explainError )
where

import Protolude
import Servant.API
import Servant.Client
import Network.HTTP.Client (Manager)
import qualified Data.Text as T

import Response (Response(..))


data Coordinate = Coordinate
  { coordinateLongitude :: Double
  , coordinateLatitude  :: Double }
  deriving (Show)

instance ToHttpApiData Coordinate where
  toUrlPiece c = (show . coordinateLongitude $ c) <> "," <> (show . coordinateLatitude $ c)

instance ToHttpApiData [Coordinate] where
  toUrlPiece cs = T.intercalate ";" $ toUrlPiece <$> cs


data Alternatives
  = AlternativesFalse
  | AlternativesTrue
  deriving (Show, Eq)

instance ToHttpApiData Alternatives where
  toQueryParam AlternativesFalse = "false"
  toQueryParam AlternativesTrue  = "true"


data Steps
  = StepsTrue
  | StepsFalse
  deriving (Show, Eq)

instance ToHttpApiData Steps where
  toQueryParam StepsTrue  = "true"
  toQueryParam StepsFalse = "false"


data Geometries
  = GeometriesPolyline
  | GeometriesGeoJson
  deriving (Show, Eq)

instance ToHttpApiData Geometries where
  toQueryParam GeometriesGeoJson  = "geojson"
  toQueryParam GeometriesPolyline = "polyline"


data Overview
  = OverviewSimplified
  | OverviewFull
  | OverviewFalse
  deriving (Show, Eq)

instance ToHttpApiData Overview where
  toQueryParam OverviewSimplified = "simplified"
  toQueryParam OverviewFull       = "full"
  toQueryParam OverviewFalse      = "false"


type RouteAPI
  = "driving"
  :> Capture    "coordinates"  [Coordinate]
  :> QueryParam "alternatives" Alternatives
  :> QueryParam "steps"        Steps
  :> QueryParam "geometries"   Geometries
  :> QueryParam "overview"     Overview
  :> Get '[JSON] Response

api :: Proxy RouteAPI
api = Proxy

routeAPI
  :: [Coordinate]
  -> Maybe Alternatives
  -> Maybe Steps
  -> Maybe Geometries
  -> Maybe Overview
  -> Manager
  -> BaseUrl
  -> ExceptT ServantError IO Response
routeAPI = client api


runRoute :: Manager -> Text -> Int -> ExceptT ServantError IO Response
runRoute manager host port = routeAPI coordinates alternatives steps geometries overview manager baseurl
  where
    start        = Coordinate { coordinateLongitude = -3.279966, coordinateLatitude = 51.406314 }
    end          = Coordinate { coordinateLongitude = -3.281205, coordinateLatitude = 51.407274 }
    coordinates  = [start, end]
    alternatives = Just AlternativesFalse
    steps        = Just StepsTrue
    geometries   = Just GeometriesGeoJson
    overview     = Just OverviewFalse
    baseurl      = BaseUrl Http (T.unpack host) port "/route/v1"


explainError :: ServantError -> Text
explainError (FailureResponse _ _ _)        = "Response Failure" 
explainError (DecodeFailure m _ _)          = "Decode Failure: " <> T.pack m
explainError (UnsupportedContentType _ _)   = "Unsupported Content Type"
explainError (InvalidContentTypeHeader _ _) = "Invalid Content Type Header"
explainError (ConnectionError _)            = "Connection Error"
