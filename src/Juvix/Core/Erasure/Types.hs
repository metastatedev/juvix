module Juvix.Core.Erasure.Types where

import qualified Juvix.Core.Erased as Erased
import qualified Juvix.Core.IR.Typechecker as TC
import Juvix.Library hiding (empty)

data Env primTy primVal
  = Env
      { typeAssignment :: Erased.TypeAssignment primTy primVal,
        context :: TC.Context primTy primVal,
        nextName :: Int,
        nameStack :: [Int],
        globals :: TC.Globals primTy primVal
      }
  deriving (Generic)

--deriving (Show, Eq, Generic)

type EnvEraAlias primTy primVal =
  ExceptT Error (State (Env primTy primVal))

newtype EnvT primTy primVal a
  = EnvEra (EnvEraAlias primTy primVal a)
  deriving (Functor, Applicative, Monad)
  deriving
    ( HasState "typeAssignment" (Erased.TypeAssignment primTy primVal),
      HasSink "typeAssignment" (Erased.TypeAssignment primTy primVal),
      HasSource "typeAssignment" (Erased.TypeAssignment primTy primVal)
    )
    via StateField "typeAssignment" (EnvEraAlias primTy primVal)
  deriving
    ( HasState "context" (TC.Context primTy primVal),
      HasSink "context" (TC.Context primTy primVal),
      HasSource "context" (TC.Context primTy primVal)
    )
    via StateField "context" (EnvEraAlias primTy primVal)
  deriving
    ( HasState "nextName" Int,
      HasSink "nextName" Int,
      HasSource "nextName" Int
    )
    via StateField "nextName" (EnvEraAlias primTy primVal)
  deriving
    ( HasState "nameStack" [Int],
      HasSink "nameStack" [Int],
      HasSource "nameStack" [Int]
    )
    via StateField "nameStack" (EnvEraAlias primTy primVal)
  deriving
    ( HasState "globals" (TC.Globals primTy primVal),
      HasSink "globals" (TC.Globals primTy primVal),
      HasSource "globals" (TC.Globals primTy primVal)
    )
    via StateField "globals" (EnvEraAlias primTy primVal)
  deriving
    (HasReader "globals" (TC.Globals primTy primVal))
    via ReaderField "globals" (EnvEraAlias primTy primVal)
  deriving
    (HasThrow "erasureError" Error)
    via MonadError (EnvEraAlias primTy primVal)

data Error
  = Unsupported
  | CannotEraseZeroUsageTerm Text
  | InternalError Text
  deriving (Show, Eq, Generic)
