{-# LANGUAGE LiberalTypeSynonyms #-}
{-# LANGUAGE UndecidableInstances #-}

module Juvix.ToCore.Types where

import Data.HashMap.Strict (HashMap)
import qualified Juvix.Context as Ctx
import qualified Juvix.Core.Base.Types as Core
import qualified Juvix.Core.HR as HR
import qualified Juvix.Core.IR as IR
import qualified Juvix.Core.Parameterisation as P
import Juvix.Library hiding (show)
import qualified Juvix.Library.LineNum as LineNum
import qualified Juvix.Library.NameSymbol as NameSymbol
import qualified Juvix.Library.Usage as Usage
import qualified Juvix.Sexp as Sexp
import Text.Show (Show (..))
import Juvix.Core.Translate ( hrToIR )

type ReduceEff ext primTy primVal m =
  ( HasThrowFF ext primTy primVal m,
    HasParam primTy primVal m,
    HasCoreSigs ext primTy primVal m
  )

deriving instance Data LineNum.T

deriving instance Data Sexp.Atom

deriving instance Data Sexp.T


data Error ext primTy primVal
  = -- features not yet implemented

    -- | constraints are not yet implemented
    ConstraintsUnimplemented NameSymbol.T Sexp.T
  | -- | refinements are not yet implemented
    RefinementsUnimplemented Sexp.T
  | -- | universe polymorphism is not yet implemented
    UniversesUnimplemented Sexp.T
  | -- | implicit arguments are not yet implemented
    ImplicitsUnimplemented Sexp.T
  | -- | implicit arguments are not yet implemented
    ImplicitsUnimplementedA Sexp.T
  | -- | type inference for definitions is not yet implemented
    SigRequired NameSymbol.T (Ctx.Definition Sexp.T Sexp.T Sexp.T)
  | -- | head of application not an Elim
    NotAnElim Sexp.T
  | -- | pattern matching etc not yet implemented
    ExprUnimplemented Sexp.T
  | -- | local datatypes etc not yet implemented
    DefUnimplemented (Ctx.Definition Sexp.T Sexp.T Sexp.T)
  | -- | patterns other than single vars in @let@ not yet implemented
    PatternUnimplemented Sexp.T
  | -- | records not yet implemented
    RecordUnimplemented Sexp.T
  | -- | records not yet implemented
    ExpRecordUnimplemented Sexp.T
  | -- | records not yet implemented
    MatchRecordUnimplemented Sexp.T
  | -- | lists not yet implemented
    ListUnimplemented Sexp.T
  | -- actual errors

    -- | unknown found at declaration level
    UnknownUnsupported (Maybe Symbol)
  | -- | current backend doesn't support this type of constant
    UnsupportedConstant Sexp.T
  | -- | current backend doesn't have this primitive
    UnknownPrimitive NameSymbol.T
  | -- | expression is not a usage
    NotAUsage Sexp.T
  | -- | expression is not 0 or ω
    NotAGUsage Sexp.T
  | -- | expression is not a natural number
    NotAUniverse Sexp.T
  | -- | usage is not 0 or ω
    UsageNotGUsage Usage.T
  | -- | invalid signature for declaration (bug in this module)
    -- @'Just' s@ if @s@ is a signature of the wrong shape,
    -- 'Nothing' if no signature found
    WrongSigType NameSymbol.T (Maybe (CoreSig ext primTy primVal))
  | -- | e.g. single anonymous constructor that is not a record
    InvalidDatatype Sexp.T
  | -- | e.g. ml-style constructor in a datatype with a GADT header
    InvalidConstructor NameSymbol.T Sexp.T
  | -- | type is something other than a set of arrows ending in *
    InvalidDatatypeType NameSymbol.T (HR.Term primTy primVal)
  | -- | Unknown %Builtin.X
    UnknownBuiltin NameSymbol.T
  | -- | Builtin with usage
    BuiltinWithUsage (Ctx.Definition Sexp.T Sexp.T Sexp.T)
  | -- | Builtin with type signature
    BuiltinWithTypeSig (Ctx.Definition Sexp.T Sexp.T Sexp.T)
  | -- | Wrong number of arguments for a builtin
    WrongNumberBuiltinArgs Special Int Sexp.T
  | -- | Using omega as an expression
    UnexpectedOmega
  deriving (Generic)

deriving instance 
   (Core.CoreEq ext primTy primVal
  , Eq primTy
  , Eq primVal) => Eq (Error ext primTy primVal)
-- FIXME replace with PrettyText
instance (Show primTy, Show primVal, Show ext,
    Core.CoreShow ext primTy primVal
  ) => Show (Error ext primTy primVal) where
  show = \case
    ConstraintsUnimplemented x cons ->
      "Definition " <> show x <> " has constraints\n"
        <> show cons
        <> "\n"
        <> "but constraints are not yet implemented"
    RefinementsUnimplemented r ->
      "Refinement\n" <> show r <> "\n"
        <> "found but refinements are not yet implemented"
    UniversesUnimplemented u ->
      "Universe\n" <> show u <> "\n"
        <> "found but universes in expressions are not yet implemented"
    ImplicitsUnimplemented arr ->
      "Implicit function type\n" <> show arr <> "\n"
        <> "found but implicits are not yet implemented"
    ImplicitsUnimplementedA arg ->
      "Implicit argument\n" <> show arg <> "\n"
        <> "found but implicits are not yet implemented"
    SigRequired x _def ->
      "Signature required for definition " <> show x <> "\n"
        <> "because type inference is not yet implemented"
    NotAnElim exp ->
      "Annotation required on expression\n" <> show exp <> "\n"
        <> "because type inference is not yet implemented"
    ExprUnimplemented exp ->
      "Elaboration of expression\n" <> show exp <> "\n"
        <> "is not yet implemented"
    DefUnimplemented def ->
      "Elaboration of definition\n" <> show def <> "\n"
        <> "is not yet implemented"
    PatternUnimplemented pat ->
      "Elaboration of pattern\n" <> show pat <> "\n"
        <> "is not yet implemented"
    RecordUnimplemented rec ->
      "Elaboration of record\n" <> show rec <> "\n"
        <> "is not yet implemented"
    ExpRecordUnimplemented rec ->
      "Elaboration of record expression\n" <> show rec <> "\n"
        <> "is not yet implemented"
    MatchRecordUnimplemented rec ->
      "Elaboration of record pattern\n" <> show rec <> "\n"
        <> "is not yet implemented"
    ListUnimplemented lst ->
      "Elaboration of list literal\n" <> show lst <> "\n"
        <> "is not yet implemented"
    UnknownUnsupported Nothing ->
      "Nameless unknown found in context"
    UnknownUnsupported (Just x) ->
      "Unknown " <> show x <> " found in context"
    UnsupportedConstant k ->
      "Constant " <> show k <> " unsupported by current backend"
    UnknownPrimitive p ->
      "Primitive " <> show p <> " unsupported by current backend"
    NotAUsage exp ->
      "Expected a usage, but got\n" <> show exp
    NotAGUsage exp ->
      "Expected a global usage, but got\n" <> show exp
    NotAUniverse exp ->
      "Expected a universe, but got\n" <> show exp
    UsageNotGUsage π ->
      "Usage " <> show π <> " cannot be applied to a global"
    WrongSigType x Nothing ->
      "Name " <> show x <> " not in scope\n"
        <> "(probably a bug in the elaborator from frontend)"
    WrongSigType x (Just sig) ->
      "Name " <> show x <> " has the wrong signature form\n"
        <> show sig
        <> "\n"
        <> "(probably a bug in the elaborator from frontend)"
    InvalidDatatype dt ->
      "Invalid datatype\n" <> show dt
    InvalidConstructor x con ->
      "Invalid constructor " <> show x <> " with form\n" <> show con
    InvalidDatatypeType x ty ->
      "Type of datatype " <> show x <> " is\n"
        <> show ty
        <> "\n"
        <> "which is not a valid sort" -- TODO rephrase this
    UnknownBuiltin x ->
      "Unknown builtin " <> show x
    BuiltinWithUsage def ->
      "Builtin binding\n" <> show def <> "\nshould not have a usage"
    BuiltinWithTypeSig def ->
      "Builtin binding\n" <> show def <> "\nshould not have a type signature"
    WrongNumberBuiltinArgs s n args ->
      "Builtin " <> show s <> " should have " <> show n <> " args\n"
        <> "but has been applied to "
        <> show (length $ Sexp.toList args)
        <> "\n"
        <> show args
    UnexpectedOmega ->
      "%Builtin.Omega cannot be used as an arbitrary term, only as\n"
        <> "the first argument of %Builtin.Arrow or %Builtin.Pair"

data CoreSig ext primTy primVal
  = DataSig
      { dataType :: !(Core.Term' ext primTy primVal),
        dataCons :: [NameSymbol.T]
      }
  | ConSig
      { conType :: !(Maybe (Core.Term' ext primTy primVal))
      }
  | ValSig
      { valUsage :: !Core.GlobalUsage,
        valType :: !(Core.Term' ext primTy primVal)
      }
  | SpecialSig !Special
  deriving (Generic)

-- | If two signatures can be merged (currently, only constructor signatures),
-- then do so, otherwise return the *first* unchanged
-- (since @insertWith@ calls it as @mergeSigs new old@).
mergeSigs ::
  CoreSig ext primTy primVal ->
  CoreSig ext primTy primVal ->
  CoreSig ext primTy primVal
mergeSigs (ConSig newTy) (ConSig oldTy) =
  ConSig (newTy <|> oldTy)
mergeSigs _ second = second

-- | Bindings that can't be given types, but can be given new names by the user.
data Special
  = -- | pi type, possibly with usage already supplied
    ArrowS (Maybe Usage.T)
  | -- | sigma type
    PairS (Maybe Usage.T)
  | -- | type annotation
    ColonS
  | -- | type of types
    TypeS
  | -- | omega usage
    OmegaS
  deriving (Eq, Show, Data, Generic)

deriving instance
  ( Eq primTy,
    Eq primVal,
    Core.TermAll Eq ext primTy primVal,
    Core.ElimAll Eq ext primTy primVal
  ) =>
  Eq (CoreSig ext primTy primVal)

deriving instance
  ( Show primTy,
    Show primVal,
    Core.TermAll Show ext primTy primVal,
    Core.ElimAll Show ext primTy primVal
  ) =>
  Show (CoreSig ext primTy primVal)


deriving instance
  ( Data ext,
    Data primTy,
    Data primVal,
    Core.TermAll Data ext primTy primVal,
    Core.ElimAll Data ext primTy primVal
  ) =>
  Data (CoreSig ext primTy primVal)

type CoreSigIR = CoreSig IR.T

type CoreSigHR = CoreSig HR.T

type CoreSigs ext primTy primVal =
  HashMap Core.GlobalName (CoreSig ext primTy primVal)

type CoreSigsIR primTy primVal = CoreSigs IR.T primTy primVal

type CoreSigsHR primTy primVal = CoreSigs HR.T primTy primVal

hrToIRSig :: CoreSigHR ty val -> CoreSigIR ty val
hrToIRSig d@DataSig { dataType }  = d { dataType = hrToIR dataType}
hrToIRSig c@ConSig{ conType } = c { conType = hrToIR <$> conType}
hrToIRSig v@ValSig {valType} = v { valType = hrToIR valType }
hrToIRSig (SpecialSig s) = SpecialSig s

hrToIRSigs :: CoreSigsHR ty val -> CoreSigsIR ty val
hrToIRSigs sigs = hrToIRSig <$> sigs

data CoreDef ext primTy primVal
  = CoreDef !(Core.RawGlobal' ext primTy primVal)
  | SpecialDef !NameSymbol.T !Special
  deriving (Generic)

deriving instance 
  ( Show primTy,
    Show primVal,
    Core.TermAll Show ext primTy primVal,
    Core.ElimAll Show ext primTy primVal,
    Core.PatternAll Show ext primTy primVal
  ) =>
  Show (CoreDef ext primTy primVal)

deriving instance 
  ( Eq primTy,
    Eq primVal,
    Core.TermAll Eq ext primTy primVal,
    Core.ElimAll Eq ext primTy primVal,
    Core.PatternAll Eq ext primTy primVal
  ) =>
  Eq (CoreDef ext primTy primVal)

deriving instance 
  ( Data primTy,
    Data primVal,
    Data ext,
    Core.TermAll Data ext primTy primVal,
    Core.ElimAll Data ext primTy primVal,
    Core.PatternAll Data ext primTy primVal
  ) =>
  Data (CoreDef ext primTy primVal)

type CoreDefIR = CoreDef IR.T
type CoreDefHR = CoreDef HR.T 

data CoreDefs' ext primTy primVal = CoreDefs
  { order :: [NonEmpty NameSymbol.T],
    defs :: CoreDefMap' ext primTy primVal
  }
  deriving (Generic)

deriving instance 
  ( Show primTy,
    Show primVal,
    Core.TermAll Show ext primTy primVal,
    Core.ElimAll Show ext primTy primVal,
    Core.PatternAll Show ext primTy primVal
  ) =>
  Show (CoreDefs' ext primTy primVal)

deriving instance 
  ( Eq primTy,
    Eq primVal,
    Core.TermAll Eq ext primTy primVal,
    Core.ElimAll Eq ext primTy primVal,
    Core.PatternAll Eq ext primTy primVal
  ) =>
  Eq (CoreDefs' ext primTy primVal)

deriving instance 
  ( Data primTy,
    Data primVal,
    Data ext,
    Core.TermAll Data ext primTy primVal,
    Core.ElimAll Data ext primTy primVal,
    Core.PatternAll Data ext primTy primVal
  ) =>
  Data (CoreDefs' ext primTy primVal)

type CoreDefs = CoreDefs' IR.T
type CoreDefsHR = CoreDefs' HR.T 

type CoreDefMap' ext primTy primVal = HashMap Core.GlobalName (CoreDef ext  primTy primVal)
type CoreDefMapHR primTy primVal = CoreDefMap' HR.T primTy primVal 
type CoreDefMap primTy primVal = CoreDefMap' IR.T primTy primVal 

type FFStateIR = FFState' IR.T
type FFStateHR = FFState' HR.T

data FFState' ext primTy primVal = FFState
  { frontend :: Ctx.T Sexp.T Sexp.T Sexp.T,
    param :: P.Parameterisation primTy primVal,
    -- TODO: Do signatures need to be
    coreSigs :: CoreSigs ext primTy primVal,
    core :: CoreDefMap' ext primTy primVal,
    patVars :: HashMap Core.GlobalName Core.PatternVar,
    nextPatVar :: Core.PatternVar
    -- TODO: Add order here and remove CorDefs
  }
  deriving (Generic)
type EnvAlias ext primTy primVal =
  ExceptT (Error ext primTy primVal) (State (FFState' ext primTy primVal))

newtype Env ext primTy primVal a = Env {unEnv :: EnvAlias ext primTy primVal a}
  deriving newtype (Functor, Applicative, Monad)
  deriving
    (HasThrow "fromFrontendError" (Error ext primTy primVal))
    via MonadError (EnvAlias ext primTy primVal)
  deriving
    ( HasSource "frontend" (Ctx.T Sexp.T Sexp.T Sexp.T),
      HasReader "frontend" (Ctx.T Sexp.T Sexp.T Sexp.T)
    )
    via ReaderField "frontend" (EnvAlias ext primTy primVal)
  deriving
    ( HasSource "param" (P.Parameterisation primTy primVal),
      HasReader "param" (P.Parameterisation primTy primVal)
    )
    via ReaderField "param" (EnvAlias ext primTy primVal)
  deriving
    ( HasSource "coreSigs" (CoreSigs ext primTy primVal),
      HasSink "coreSigs" (CoreSigs ext primTy primVal),
      HasState "coreSigs" (CoreSigs ext primTy primVal)
    )
    via StateField "coreSigs" (EnvAlias ext primTy primVal)
  deriving
    ( HasSource "core" (CoreDefMap' ext primTy primVal),
      HasSink "core" (CoreDefMap' ext primTy primVal),
      HasState "core" (CoreDefMap' ext primTy primVal)
    )
    via StateField "core" (EnvAlias ext primTy primVal)
  deriving
    ( HasSource "patVars" (HashMap Core.GlobalName Core.PatternVar),
      HasSink "patVars" (HashMap Core.GlobalName Core.PatternVar),
      HasState "patVars" (HashMap Core.GlobalName Core.PatternVar)
    )
    via StateField "patVars" (EnvAlias ext primTy primVal)
  deriving
    ( HasSource "nextPatVar" Core.PatternVar,
      HasSink "nextPatVar" Core.PatternVar,
      HasState "nextPatVar" Core.PatternVar
    )
    via StateField "nextPatVar" (EnvAlias ext primTy primVal)

type HasThrowFF ext primTy primVal =
  HasThrow "fromFrontendError" (Error ext primTy primVal)
type HasFrontend =
  HasReader "frontend" (Ctx.T Sexp.T Sexp.T Sexp.T)
type HasParam primTy primVal =
  HasReader "param" (P.Parameterisation primTy primVal)

type HasCoreSigs ext primTy primVal =
  HasState "coreSigs" (CoreSigs ext primTy primVal)

type HasCore ext primTy primVal =
  HasState "core" (CoreDefMap' ext primTy primVal)

type HasPatVars =
  HasState "patVars" (HashMap Core.GlobalName Core.PatternVar)
type HasNextPatVar =
  HasState "nextPatVar" Core.PatternVar
execEnv ::
  Ctx.T Sexp.T Sexp.T Sexp.T ->
  P.Parameterisation primTy primVal ->
  Env ext primTy primVal a ->
  Either (Error ext primTy primVal) a
execEnv ctx param env =
  fst $ runEnv ctx param env

evalEnv ::
  Ctx.T Sexp.T Sexp.T Sexp.T ->
  P.Parameterisation primTy primVal ->
  Env ext primTy primVal a ->
  FFState' ext primTy primVal
evalEnv ctx param env =
  snd $ runEnv ctx param env

runEnv ::
  Ctx.T Sexp.T Sexp.T Sexp.T ->
  P.Parameterisation primTy primVal ->
  Env ext primTy primVal a ->
  (Either (Error ext primTy primVal) a, FFState' ext primTy primVal)
runEnv ctx param (Env env) =
  runIdentity $ runStateT (runExceptT env) initState where
    initState =
      FFState
        { frontend = ctx,
          param,
          coreSigs = mempty,
          core = mempty,
          patVars = mempty,
          nextPatVar = 0
        }

throwFF :: HasThrowFF ext primTy primVal m => Error ext primTy primVal -> m a
throwFF = throw @"fromFrontendError"
