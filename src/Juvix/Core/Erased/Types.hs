module Juvix.Core.Erased.Types
  ( module Juvix.Core.Erased.Types,
    Term' (..),
    Type' (..),
    TypeAssignment',
    NoExt,
  )
where

import qualified Juvix.Core.Usage as Usage
import Juvix.Library hiding (Type)
import qualified Juvix.Library.HashMap as Map
import Juvix.Core.Erased.Extend
import Juvix.Core.HRAnn.Types (Annotation (..), AppAnnotation (..), BindAnnotation (..))
import qualified Juvix.Core.IR.Types.Base as IR
import Juvix.Core.IR.Types.Base hiding
  ( extDataArg,
    extDataCon,
    extDatatype,
    extFunClause,
    extFunction,
    extPattern,
  )

data T

IR.extendTerm "Term" [] [t|T|] extTerm

IR.extendType "Type" [] [t|T|] extType

IR.extendValue "Value" [] [t|T|] extValue

IR.extendNeutral "Neutral" [] [t|T|] extNeutral

IR.extendDatatype "Datatype" [] [t|T|] extDatatype

IR.extendDataArg "DataArg" [] [t|T|] extDataArg

IR.extendDataCon "DataCon" [] [t|T|] extDataCon

IR.extendFunction "Function" [] [t|T|] extFunction

IR.extendFunClause "FunClause" [] [t|T|] extFunClause

IR.extendPattern "Pattern" [] [t|T|] extPattern

type TypeAssignment primTy = TypeAssignment' NoExt primTy

data EvaluationError primVal
  = PrimitiveApplicationError primVal primVal
  deriving (Show, Eq, Generic)
