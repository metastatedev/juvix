{-# LANGUAGE LiberalTypeSynonyms #-}

module Juvix.FrontendContextualise.ModuleOpen.Environment
  ( module Juvix.FrontendContextualise.ModuleOpen.Environment,
    module Juvix.FrontendContextualise.Environment,
  )
where

import qualified Data.HashSet as Set
import qualified Juvix.Core.Common.Context as Context
import qualified Juvix.Core.Common.NameSymbol as NameSymbol
import Juvix.FrontendContextualise.Environment
import qualified Juvix.FrontendContextualise.ModuleOpen.Types as New
import qualified Juvix.FrontendDesugar.RemoveDo.Types as Old
import Juvix.Library
import qualified Juvix.Library.HashMap as Map

type Old f =
  f (NonEmpty (Old.FunctionLike Old.Expression)) Old.Signature Old.Type

type New f =
  f (NonEmpty (New.FunctionLike New.Expression)) New.Signature New.Type

type WorkingMaps m =
  ( HasState "old" (Old Context.T) m,
    HasState "new" (New Context.T) m,
    HasThrow "error" Error m,
    HasState "modMap" ModuleMap m
  )

data Environment
  = Env
      { old :: Old Context.T,
        new :: New Context.T,
        modMap :: ModuleMap
      }
  deriving (Generic)

type FinalContext = New Context.T

data Error
  = UnknownModule Context.NameSymbol
  | OpenNonModule (Set.HashSet Context.NameSymbol)
  | IllegalModuleSwitch Context.NameSymbol
  | ConflictingSymbols Context.NameSymbol
  deriving (Show)

data Open a
  = Implicit a
  | Explicit a
  deriving (Show, Eq, Ord)

type ContextAlias =
  ExceptT Error (State Environment)

type ModuleMap = Map.T Symbol NameSymbol.T

newtype Context a
  = Ctx {antiAlias :: ContextAlias a}
  deriving (Functor, Applicative, Monad)
  deriving
    ( HasState "old" (Old Context.T),
      HasSink "old" (Old Context.T),
      HasSource "old" (Old Context.T)
    )
    via StateField "old" ContextAlias
  deriving
    ( HasState "new" (New Context.T),
      HasSink "new" (New Context.T),
      HasSource "new" (New Context.T)
    )
    via StateField "new" ContextAlias
  deriving
    ( HasState "modMap" ModuleMap,
      HasSink "modMap" ModuleMap,
      HasSource "modMap" ModuleMap
    )
    via StateField "modMap" ContextAlias
  deriving
    (HasThrow "error" Error)
    via MonadError ContextAlias

--------------------------------------------------------------------------------
-- Types for resolving opens
--------------------------------------------------------------------------------
-- - before we are able to qaulify all symbols, we need the context at
--   a fully realized state.
-- - This hosts
--   1. the module
--   2. the inner modules (which thus have implciit opens of all
--      opens)
--   3. All opens
-- - Since we desugar all modules to records, we can't have opens over
--   them, hence no need to store it separately
-- - Any resolution will thus happen at the explicit module itself, as
--   trying to do so in the inner modules would lead to a path error

data PreQualified
  = Pre
      { opens :: [NameSymbol.T],
        implicitInner :: [NameSymbol.T],
        explicitModule :: NameSymbol.T
      }
  deriving (Show, Eq)

type OpenMap = Map.T Context.NameSymbol [Open NameSymbol.T]

data Resolve a b c
  = Res
      { resolved :: [(Context.From (Context.Definition a b c), NameSymbol.T)],
        notResolved :: [NameSymbol.T]
      }
  deriving (Show)

--------------------------------------------------------------------------------
-- Running functions
--------------------------------------------------------------------------------

runEnv ::
  Context a -> Old Context.T -> (Either Error a, Environment)
runEnv (Ctx c) old =
  Env old (Context.empty (Context.currentName old)) mempty
    |> runState (runExceptT c)

-- for this function just the first part of the symbol is enough
qualifyName ::
  HasState "modMap" ModuleMap m => NonEmpty Symbol -> m (NonEmpty Symbol)
qualifyName sym@(s :| _) = do
  qualifieds <- get @"modMap"
  case qualifieds Map.!? s of
    Just preQualified ->
      pure $ preQualified <> sym
    Nothing ->
      pure sym

addModMap ::
  HasState "modMap" ModuleMap m => Symbol -> NonEmpty Symbol -> m ()
addModMap toAdd qualification =
  Juvix.Library.modify @"modMap" (Map.insert toAdd qualification)

lookupModMap ::
  HasState "modMap" ModuleMap m => Symbol -> m (Maybe (NonEmpty Symbol))
lookupModMap s =
  (Map.!? s) <$> get @"modMap"

removeModMap ::
  HasState "modMap" ModuleMap m => Symbol -> m ()
removeModMap s = Juvix.Library.modify @"modMap" (Map.delete s)

--------------------------------------------------------------------------------
-- fully resolve module opens
--------------------------------------------------------------------------------

resolve :: Context.T a b c -> [PreQualified] -> ModuleMap -> Either Error OpenMap
resolve ctx preQual nameMap = undefined

resolveSingle ::
  Context.T a b c -> PreQualified -> ModuleMap -> Either Error OpenMap
resolveSingle ctx Pre {opens, implicitInner, explicitModule} nameMap =
  case Context.switchNameSpace explicitModule ctx of
    Left (Context.VariableShared err) ->
      Left (IllegalModuleSwitch err)
    Right ctx -> do
      resolved <- pathsCanBeResolved ctx opens
      qualifiedNames <- resolveLoop ctx mempty resolved
      mempty
        |> Map.insert explicitModule (fmap Explicit qualifiedNames)
        |> ( \map ->
               foldr
                 (\mod -> Map.insert mod (fmap Implicit qualifiedNames))
                 map
                 implicitInner
           )
        |> Right

-- this goes off after the checks have passed regarding if the paths
-- are even possible to resolve
resolveLoop ::
  Context.T a b c -> ModuleMap -> Resolve a b c -> Either Error [NameSymbol.T]
resolveLoop ctx map Res {resolved, notResolved = cantResolveNow} = do
  map <- foldM undefined map fullyQualifyRes
  resolveLoop ctx map undefined
  where
    fullyQualifyRes =
      Context.resolveName ctx <$> resolved
    qualifedAns =
      fmap snd fullyQualifyRes
    qualifyCant newMap term =
      case newMap Map.!? NameSymbol.hd term of
        Nothing ->
          term
        Just x ->
          x <> term

-- Since Locals and top level beats opens, we can determine from the
-- start that any module which tries to open a nested path fails,
-- yet any previous part succeeds, that an illegal open is happening,
-- and we can error out immediately

-- | @pathsCanBeResolved@ takes a context and a list of opens,
-- we then try to resolve if the opens are legal, if so we return
-- a list of ones that can be determined now, and a list to be resolved
pathsCanBeResolved ::
  Context.T a b c -> [NameSymbol.T] -> Either Error (Resolve a b c)
pathsCanBeResolved ctx opens
  | fmap firstName (notResolved resFull) == notResolved resFirst =
    Right resFull
  | otherwise =
    Left (OpenNonModule diff)
  where
    resFull = resolveWhatWeCan ctx opens
    resFirst = resolveWhatWeCan ctx (firstName <$> opens)
    -- O(n log₁₆(n))
    diff =
      Set.difference
        (Set.fromList (notResolved resFull))
        (Set.fromList (notResolved resFirst))

resolveWhatWeCan :: Context.T a b c -> [NameSymbol.T] -> Resolve a b c
resolveWhatWeCan ctx opens = Res {resolved, notResolved}
  where
    dupLook =
      fmap (\openMod -> (Context.lookup openMod ctx, openMod))
    (resolved, notResolved) =
      splitMaybes (dupLook opens)

----------------------------------------
-- Helpers for resolve
----------------------------------------

splitMaybes :: [(Maybe a, b)] -> ([(a, b)], [b])
splitMaybes = foldr f ([], [])
  where
    f (Just a, b) = first ((a, b) :)
    f (Nothing, b) = second (b :)

firstName :: NameSymbol.T -> NameSymbol.T
firstName = NameSymbol.fromSymbol . NameSymbol.hd
