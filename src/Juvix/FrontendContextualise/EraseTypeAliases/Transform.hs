{-# LANGUAGE LiberalTypeSynonyms #-}

module Juvix.FrontendContextualise.EraseTypeAliases.Transform where

import qualified Juvix.Core.Common.Context as Context
import qualified Juvix.FrontendContextualise.Environment as Env
import qualified Juvix.FrontendContextualise.EraseTypeAliases.Types as New
import qualified Juvix.FrontendDesugar.RemoveDo.Types as Old --FIXME put in the last stage
import Juvix.Library
import qualified Juvix.Library.HashMap as Map

type Old f = f (NonEmpty (Old.FunctionLike Old.Expression)) Old.Signature Old.Type

type New f = f (NonEmpty (New.FunctionLike New.Expression)) New.Signature New.Type

type WorkingMaps m =
  ( HasState "old" (Old Context.T) m, -- old context
    HasReader "new" (New Context.T) m, -- new context
    HasState "aliases" (Map.T Symbol (New Context.Definition)) m -- a map of aliases
  )

-- The actual transform we are doing:
-- TODO: write the actual transform function

--------------------------------------------------------------------------------
-- Boilerplate Transforms
--------------------------------------------------------------------------------
-- transformTopLevel ::
-- WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
-- Old.TopLevel ->
-- m New.TopLevel
transformTopLevel (Old.Type t) = New.Type <$> transformType t
transformTopLevel (Old.ModuleOpen t) = New.ModuleOpen <$> transformModuleOpen t
transformTopLevel (Old.Function t) = New.Function <$> transformFunction t
transformTopLevel Old.TypeClass = pure New.TypeClass
transformTopLevel Old.TypeClassInstance = pure New.TypeClassInstance

-- transformExpression ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Expression ->
--   m New.Expression
transformExpression (Old.Constant c) = New.Constant <$> transformConst c
transformExpression (Old.Let l) = New.Let <$> transformLet l
transformExpression (Old.LetType l) = New.LetType <$> transformLetType l
transformExpression (Old.Match m) = New.Match <$> transformMatch m
transformExpression (Old.Name n) = pure $ New.Name n
transformExpression (Old.OpenExpr n) = New.OpenExpr <$> transformModuleOpenExpr n
transformExpression (Old.Lambda l) = New.Lambda <$> transformLambda l
transformExpression (Old.Application a) = New.Application <$> transformApplication a
transformExpression (Old.Block b) = New.Block <$> transformBlock b
transformExpression (Old.Infix i) = New.Infix <$> transformInfix i
transformExpression (Old.ExpRecord i) = New.ExpRecord <$> transformExpRecord i
transformExpression (Old.ArrowE i) = New.ArrowE <$> transformArrowExp i
transformExpression (Old.NamedTypeE i) = New.NamedTypeE <$> transformNamedType i
transformExpression (Old.RefinedE i) = New.RefinedE <$> transformTypeRefine i
transformExpression (Old.UniverseName i) = New.UniverseName <$> transformUniverseExpression i
transformExpression (Old.Parened e) = New.Parened <$> transformExpression e

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

-- transformType ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Type ->
--   m New.Type
transformType (Old.Typ usage name' args form) =
  New.Typ <$> traverse transformExpression usage <*> pure name' <*> pure args <*> transformTypeSum form

-- transformTypeSum ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.TypeSum ->
--   m New.TypeSum
transformTypeSum (Old.Alias a) = New.Alias <$> transformAlias a
transformTypeSum (Old.Data da) = New.Data <$> transformData da

-- transformAlias ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Alias ->
--   m New.Alias
transformAlias (Old.AliasDec exp) =
  New.AliasDec <$> transformExpression exp

--------------------------------------------------
-- Arrows
--------------------------------------------------

-- transformNamedType ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.NamedType ->
--   m New.NamedType
transformNamedType (Old.NamedType' name exp) =
  New.NamedType' <$> transformName name <*> transformExpression exp

-- transformTypeRefine ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.TypeRefine ->
--   m New.TypeRefine
transformTypeRefine (Old.TypeRefine name refine) =
  New.TypeRefine <$> transformExpression name <*> transformExpression refine

--------------------------------------------------
-- Types Misc
--------------------------------------------------

-- transformName ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Name ->
--   m New.Name
transformName (Old.Implicit s) = pure $ New.Implicit s
transformName (Old.Concrete s) = pure $ New.Concrete s

-- transformArrowSymbol ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.ArrowSymbol ->
--   m New.ArrowSymbol
transformArrowSymbol (Old.ArrowUse usage) =
  pure $ New.ArrowUse usage
transformArrowSymbol (Old.ArrowExp e) =
  New.ArrowExp <$> transformExpression e

-- transformUniverseExpression ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.UniverseExpression ->
--   m New.UniverseExpression
transformUniverseExpression (Old.UniverseExpression s) =
  pure $ New.UniverseExpression s

--------------------------------------------------
-- ADTs
--------------------------------------------------

-- transformData ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Data ->
--   m New.Data
transformData (Old.Arrowed exp adt) =
  New.Arrowed <$> transformExpression exp <*> transformAdt adt
transformData (Old.NonArrowed adt) =
  New.NonArrowed <$> transformAdt adt

-- transformAdt ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Adt ->
--   m New.Adt
transformAdt (Old.Sum oldsu) = New.Sum <$> traverse transformSum oldsu
transformAdt (Old.Product p) = New.Product <$> transformProduct p

-- transformSum ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Sum ->
--   m New.Sum
transformSum (Old.S sym prod) =
  New.S sym <$> traverse transformProduct prod

-- transformProduct ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Product ->
--   m New.Product
transformProduct (Old.Record rec') = New.Record <$> transformRecord rec'
transformProduct (Old.Arrow arrow) = New.Arrow <$> transformExpression arrow
transformProduct (Old.ADTLike adt) = New.ADTLike <$> traverse transformExpression adt

-- transformRecord ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Record ->
--   m New.Record
transformRecord (Old.Record'' fields sig) =
  New.Record'' <$> traverse transformNameType fields <*> traverse transformExpression sig

-- transformNameType ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.NameType ->
--   m New.NameType
transformNameType (Old.NameType' sig name) =
  New.NameType' <$> transformExpression sig <*> transformName name

-- transformFunction ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Function ->
--   m New.Function
transformFunction (Old.Func name f sig) =
  New.Func name <$> traverse transformFunctionLike f <*> traverse transformSignature sig

-- transformFunctionLike ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.FunctionLike Old.Expression ->
--   m (New.FunctionLike New.Expression)
transformFunctionLike (Old.Like args body) =
  New.Like <$> traverse transformArg args <*> transformExpression body

-- transformModuleOpen ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.ModuleOpen ->
--   m New.ModuleOpen
transformModuleOpen (Old.Open mod) = pure $ New.Open mod

-- transformModuleOpenExpr ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.ModuleOpenExpr ->
--   m New.ModuleOpenExpr
transformModuleOpenExpr (Old.OpenExpress modName expr) =
  New.OpenExpress modName <$> transformExpression expr

-- transformArg ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Arg ->
--   m New.Arg
transformArg (Old.ImplicitA ml) = New.ImplicitA <$> transformMatchLogic ml
transformArg (Old.ConcreteA ml) = New.ConcreteA <$> transformMatchLogic ml

--------------------------------------------------------------------------------
-- Signatures
--------------------------------------------------------------------------------

-- transformSignature ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Signature ->
--   m New.Signature
transformSignature (Old.Sig name usage arrow constraints) =
  New.Sig
    <$> pure name
    <*> traverse transformExpression usage
    <*> transformExpression arrow
    <*> traverse transformExpression constraints

--------------------------------------------------------------------------------
-- Expression
--------------------------------------------------------------------------------

-- transformArrowExp ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.ArrowExp ->
--   m New.ArrowExp
transformArrowExp (Old.Arr' left usage right) =
  New.Arr'
    <$> transformExpression left
    <*> transformExpression usage
    <*> transformExpression right

-- transformConst ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Constant ->
--   m New.Constant
transformConst (Old.Number numb) = New.Number <$> transformNumb numb
transformConst (Old.String str) = New.String <$> transformString str

-- transformNumb ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Numb ->
--   m New.Numb
transformNumb (Old.Integer' i) = pure $ New.Integer' i
transformNumb (Old.Double' d) = pure $ New.Double' d

-- transformString ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.String' ->
--   m New.String'
transformString (Old.Sho t) = pure $ New.Sho t

-- transformBlock ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Block ->
--   m New.Block
transformBlock (Old.Bloc expr) = New.Bloc <$> transformExpression expr

-- transformLambda ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Lambda ->
--   m New.Lambda
-- TODO update context
transformLambda (Old.Lamb args body) =
  New.Lamb <$> traverse transformMatchLogic args <*> transformExpression body

-- transformApplication ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Application ->
--   m New.Application
transformApplication (Old.App fun args) =
  New.App <$> transformExpression fun <*> traverse transformExpression args

-- transformExpRecord ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.ExpRecord ->
--   m New.ExpRecord
transformExpRecord (Old.ExpressionRecord fields) =
  New.ExpressionRecord <$> traverse (transformNameSet transformExpression) fields

--------------------------------------------------
-- Symbol Binding
--------------------------------------------------

-- transformLet ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Env.Context term0 ty0 sumRep0 termN tyN sumRepN Old.Let ->
--   Env.Context term0 ty0 sumRep0 termN tyN sumRepN New.Let
transformLet (Old.LetGroup name bindings body) = do
  originalVal <- Env.lookup name -- look up in "new" state
  let transform = do
        transformedBindings <- traverse transformFunctionLike bindings
        let def = Env.transLike transformedBindings Nothing Nothing
         in Env.add name def -- add to new context
        New.LetGroup name transformedBindings <$> transformExpression body
  case originalVal of
    Just originalV -> do
      res <- transform
      Env.add name originalV
      return res
    Nothing -> do
      res <- transform
      Env.remove name
      return res

-- transformLetType ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.LetType ->
--   m New.LetType
transformLetType (Old.LetType'' typ expr) =
  New.LetType'' <$> transformType typ <*> transformExpression expr

--------------------------------------------------
-- Symbol Binding
--------------------------------------------------

-- transformInfix ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Infix ->
--   m New.Infix
transformInfix (Old.Inf l o r) =
  New.Inf <$> transformExpression l <*> pure o <*> transformExpression r

--------------------------------------------------
-- Matching
--------------------------------------------------

-- transformMatch ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.Match ->
--   m New.Match
-- TODO update context
transformMatch (Old.Match'' on bindings) =
  New.Match'' <$> transformExpression on <*> traverse transformMatchL bindings

-- transformMatchL ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.MatchL ->
--   m New.MatchL
transformMatchL (Old.MatchL pat body) =
  New.MatchL <$> transformMatchLogic pat <*> transformExpression body

-- transformMatchLogic ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.MatchLogic ->
--   m New.MatchLogic
transformMatchLogic (Old.MatchLogic start name) =
  New.MatchLogic <$> (tranformMatchLogicStart start) <*> pure name

-- tranformMatchLogicStart ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   Old.MatchLogicStart ->
--   m New.MatchLogicStart
tranformMatchLogicStart (Old.MatchCon conName logic) =
  New.MatchCon conName <$> traverse transformMatchLogic logic
tranformMatchLogicStart (Old.MatchName s) =
  pure $ New.MatchName s
tranformMatchLogicStart (Old.MatchConst c) =
  New.MatchConst <$> transformConst c
tranformMatchLogicStart (Old.MatchRecord r) =
  New.MatchRecord <$> traverse (transformNameSet transformMatchLogic) r

-- transformNameSet ::
--   WorkingMaps m term0 ty0 sumRep0 termN tyN sumRepN =>
--   (t1 -> m t2) ->
--   Old.NameSet t1 ->
--   m (New.NameSet t2)
transformNameSet p (Old.NonPunned s e) =
  New.NonPunned s <$> p e
