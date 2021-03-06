-- |
-- - Types used internally by the Michelson backend.
module Juvix.Backends.Michelson.Compilation.Types
  ( PrimTy (..),
    RawPrimVal (..),
    Return',
    Take,
    Arg',
    PrimVal',
    PrimValIR,
    PrimValHR,
    RawTerm,
    Term,
    Value,
    Type,
    Op,
    CompilationLog (..),
    CompilationError (..),
    SomeInstr (..),
    EmptyInstr (..),
    CoreErased.AnnTerm (..),
  )
where

import qualified Juvix.Core.Application as App
import qualified Juvix.Core.Erased.Ann.Types as CoreErased
import qualified Juvix.Core.IR.Types as IR
import qualified Juvix.Core.Parameterisation as P
import Juvix.Library hiding (Type)
import qualified Juvix.Library.NameSymbol as NameSymbol
import qualified Michelson.TypeCheck as M
import qualified Michelson.Typed as MT
import qualified Michelson.Untyped as M
import qualified Michelson.Untyped.Instr as Instr

data PrimTy
  = PrimTy M.Ty
  | -- extra types that need arguments
    Pair
  | Lambda
  | Map
  | BigMap
  | Option
  | List
  | Set
  | ContractT
  | Application PrimTy (NonEmpty PrimTy)
  deriving (Show, Eq, Generic, Data)

data RawPrimVal
  = Constant (M.Value' Op)
  | Inst (Instr.InstrAbstract Op)
  | AddN
  | AddI
  | AddTimeStamp
  | AddMutez
  | NegN
  | NegI
  | SubN
  | SubI
  | SubMutez
  | SubTimeStamp
  | MulI
  | MulN
  | MulMutez
  | EDivI
  | EDivN
  | EDivMutez
  | OrB
  | ORI
  | AndI
  | AndB
  | XorI
  | XorB
  | NotI
  | NotB
  | CompareI
  | CompareS
  | CompareP
  | CompareTimeStamp
  | CompareMutez
  | CompareBytes
  | CompareHash
  | SizeMap
  | SizeSet
  | SizeList
  | SizeBytes
  | SizeS
  | MemSet
  | MemMap
  | UpdateSet
  | UpdateMap
  | UpdateBMap
  | GetMap
  | GetBMap
  | -- Extra values which need types
    Right'
  | Left'
  | Nil
  | Cons
  | None
  | EmptyS
  | EmptyM
  | EmptyBM
  | Cast
  | Contract
  | CreateContract
  | Loop
  | Iter
  | MapOp
  deriving (Show, Eq, Generic, Data)

type Return' ext = App.Return' ext (P.PrimType PrimTy) RawPrimVal

type Take = App.Take (P.PrimType PrimTy) RawPrimVal

type Arg' ext = App.Arg' ext (P.PrimType PrimTy) RawPrimVal

type PrimVal' ext = Return' ext

type PrimValIR = PrimVal' IR.T

type PrimValHR = PrimVal' CoreErased.T

type RawTerm = CoreErased.AnnTerm PrimTy RawPrimVal

type Term = CoreErased.AnnTerm PrimTy PrimValHR

type Type = CoreErased.Type PrimTy

type Value = M.Value' M.ExpandedOp

type Op = M.ExpandedOp

data CompilationError
  = NotYetImplemented Text
  | InvalidInputType Text
  | InternalFault Text
  | DidNotTypecheck Instr.ExpandedOp M.TCError
  | DidNotTypecheckAfterOptimisation Instr.ExpandedOp M.TCError
  | NotEnoughArguments
  | NotInStack NameSymbol.T
  | -- Should never happen!
    NotEnoughStackSpace
  | OpInMichelsonValue
  | FieldEltInMichelsonValue
  | AppliedConstantToArgument
  | TooManyArguments
  deriving (Show, Eq, Generic)

data CompilationLog
  = TermToInstr Term Op
  | OptimisedByJuvix Op Op
  | OptimisedByMorley SomeInstr SomeInstr
  deriving (Generic, Show)

data EmptyInstr where
  EmptyInstr :: forall b. MT.Instr '[] b -> EmptyInstr

data SomeInstr where
  SomeInstr :: forall a b. MT.Instr a b -> SomeInstr

deriving instance Show SomeInstr

deriving instance Show EmptyInstr

instance Eq SomeInstr where
  _ == _ = False
