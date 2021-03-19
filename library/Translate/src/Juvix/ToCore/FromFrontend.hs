{-# LANGUAGE LiberalTypeSynonyms #-}
{-# LANGUAGE UndecidableInstances #-}

module Juvix.ToCore.FromFrontend where

import qualified Data.HashMap.Strict as HM
import qualified Data.List.NonEmpty as NonEmpty
import qualified Generics.SYB as SYB
import qualified Juvix.Core.Common.Context as Ctx
import qualified Juvix.Core.HR as HR
import qualified Juvix.Core.IR as IR
import qualified Juvix.Core.IR.Types as IR
import qualified Juvix.Core.Parameterisation as P
import Juvix.Core.Translate (hrToIR)
import Juvix.Library
import qualified Juvix.Library.NameSymbol as NameSymbol
import qualified Juvix.Library.Sexp as Sexp
import qualified Juvix.Library.Usage as Usage
import Juvix.ToCore.Types
import Prelude (error)

-- P.stringVal p s
-- P.floatVal p d

paramConstant' ::
  P.Parameterisation primTy primVal ->
  Sexp.Atom ->
  Maybe primVal
paramConstant' p Sexp.N {atomNum} = P.intVal p atomNum
paramConstant' _p Sexp.A {} = Nothing

paramConstant ::
  (HasParam primTy primVal m, HasThrowFF primTy primVal m) =>
  Sexp.Atom ->
  m primVal
paramConstant k = do
  p <- ask @"param"
  case paramConstant' p k of
    Just x -> pure x
    Nothing -> throwFF $ UnsupportedConstant (Sexp.Atom k)

-- | N.B. doesn't deal with pattern variables since HR doesn't have them.
-- 'transformTermIR' does that.
transformTermHR ::
  ( Data primTy,
    Data primVal,
    HasThrowFF primTy primVal m,
    HasParam primTy primVal m,
    HasCoreSigs primTy primVal m
  ) =>
  NameSymbol.Mod ->
  Sexp.T ->
  m (HR.Term primTy primVal)
transformTermHR _ (Sexp.Atom a@Sexp.N {}) =
  HR.Prim <$> paramConstant a
transformTermHR _ (Sexp.Atom n@Sexp.N {}) =
  undefined
transformTermHR q p@(name Sexp.:> form)
  -- Unimplemented cases
  -- 1. _refinement_
  --    - TODO :: the name will only become relevant (outside of arrows)
  --              when refinements are supported
  -- 2. _universe names_
  --    - TODO :: for universe polymorphism
  | named ":record-no-pun" = throwFF $ RecordUnimplemented p
  | named ":refinement" = throwFF $ RefinementsUnimplemented p
  | named ":let-type" = throwFF $ ExprUnimplemented p
  | named ":list" = throwFF $ ListUnimplemented p
  | named "case" = throwFF $ ExprUnimplemented p
  | named ":u" = throwFF $ UniversesUnimplemented p
  -- Rest
  | named ":custom-arrow" = undefined
  | named ":let-match" = transformSimpleLet q form
  | named ":primitive" = transPrim form
  | named ":lambda" = transformSimpleLambda q form
  | named ":progn" = transformTermHR q (Sexp.car form)
  | named ":paren" = transformTermHR q (Sexp.car form)
  where
    named = Sexp.isAtomNamed name

transPrim (Sexp.List [parm])
  | Just Sexp.A {atomName = p} <- Sexp.atomFromT parm = do
    param <- ask @"param"
    maybe (throwFF $ UnknownPrimitive p) pure $
      primTy param p <|> primVal param p
  where
    primTy param p = HR.PrimTy <$> HM.lookup p (P.builtinTypes param)
    primVal param p = HR.Prim <$> HM.lookup p (P.builtinValues param)
transPrim _ = error "malfromed prim"

transformSimpleLambda ::
  ( Data primTy,
    Data primVal,
    HasThrowFF primTy primVal m,
    HasParam primTy primVal m,
    HasCoreSigs primTy primVal m
  ) =>
  NameSymbol.Mod ->
  Sexp.T ->
  m (HR.Term primTy primVal)
transformSimpleLambda q (Sexp.List [args, body])
  | Just pats <- Sexp.toList args >>= NonEmpty.nonEmpty =
    foldr HR.Lam <$> transformTermHR q body <*> traverse isVarPat pats
transformSimpleLambda _ _ = error "malformed lambda"

transformSimpleLet ::
  ( Data primTy,
    Data primVal,
    HasThrowFF primTy primVal m,
    HasParam primTy primVal m,
    HasCoreSigs primTy primVal m
  ) =>
  NameSymbol.Mod ->
  Sexp.T ->
  m (HR.Term primTy primVal)
transformSimpleLet p e@(Sexp.List [name, Sexp.List [arg, cbody], body])
  | Just Sexp.A {atomName} <- Sexp.atomFromT name,
    Just xs <- Sexp.toList arg = do
    args <- traverse isVarArg xs
    cbody <- transformTermHR p cbody
    rhs <- toElim (Sexp.Cons (Sexp.atom ":let-match=") e) $ foldr HR.Lam cbody args
    HR.Let Usage.Omega atomName rhs <$> transformTermHR p body
transformSimpleLet _p (Sexp.List [_name, fun, _body]) =
  throwFF $ ExprUnimplemented fun
transformSimpleLet _ _ = error "malformed let"

isVarArg ::
  HasThrowFF primTy primVal m =>
  Sexp.T ->
  m NameSymbol.T
isVarArg p@(name Sexp.:> _rest)
  | Sexp.isAtomNamed name ":implicit-a" =
    throwFF $ PatternUnimplemented p
isVarArg p =
  isVarPat p
isVarArg _ = error "malformed arg"

isVarPat ::
  HasThrowFF primTy primVal m =>
  Sexp.T ->
  m NameSymbol.T
isVarPat (Sexp.List [x])
  | Just Sexp.A {atomName} <- Sexp.atomFromT x =
    pure atomName
isVarPat p =
  throwFF $ PatternUnimplemented p

transformPat p@(asCon Sexp.:> con)
  -- implicit arguments are not supported
  | Sexp.isAtomNamed asCon ":as" =
    throwFF $ PatternUnimplemented p
  | otherwise =
    undefined

toElim ::
  HasThrowFF primTy primVal m =>
  -- | the original expression
  Sexp.T ->
  HR.Term primTy primVal ->
  m (HR.Elim primTy primVal)
toElim _ (HR.Elim e) = pure e
toElim e _ = throwFF $ NotAnElim e

--------------------------------------------------------------------------------
-- General Helpers
--------------------------------------------------------------------------------
eleToSymbol :: Sexp.T -> Maybe Symbol
eleToSymbol x
  | Just Sexp.A {atomName} <- Sexp.atomFromT x =
    Just (NameSymbol.toSymbol atomName)
  | otherwise = Nothing
