-- | Datatype declarations are typechecked here. Usages are passed along.
module Juvix.Core.IR.CheckDatatype
  ( module Juvix.Core.IR.CheckDatatype,
  )
where

import Juvix.Core.IR.CheckTerm
import qualified Juvix.Core.IR.Evaluator as Eval
-- import SPos ( sposConstructor )

import qualified Juvix.Core.IR.TransformExt.OnlyExts as OnlyExts
import Juvix.Core.IR.Typechecker.Types as Typed
import Juvix.Core.IR.Types (NoExt, pattern VStar)
import Juvix.Core.IR.Types.Base as IR
import Juvix.Core.IR.Types.Globals as IR
import qualified Juvix.Core.Parameterisation as Param
import Juvix.Library
import qualified Juvix.Library.Usage as Usage

typeCheckConstructor ::
  forall ext primTy primVal m.
  ( HasThrowTC' NoExt ext primTy primVal m,
    -- HasState "typeSigs" _ m,
    Eq primTy,
    Eq primVal,
    CanTC' ext primTy primVal m,
    Param.CanApply primTy,
    Param.CanApply (TypedPrim primTy primVal),
    Eval.NoExtensions ext primTy (TypedPrim primTy primVal),
    Eval.CanEval ext NoExt primTy (TypedPrim primTy primVal)
  ) =>
  -- | The targeted parameterisation
  Param.Parameterisation primTy primVal ->
  -- | The constructor name
  GlobalName ->
  -- | Positivity of its parameters
  [IR.Pos] ->
  RawTelescope ext primTy primVal ->
  -- | a hashmap of global names and their info (TODO do I need this?)
  GlobalsT' NoExt ext primTy primVal ->
  -- | The term to be checked
  IR.Term' ext primTy primVal ->
  TypeCheck ext primTy primVal m [GlobalT' NoExt ext primTy primVal]
typeCheckConstructor param cname pos tel globals ty = do
  -- sig <- get @"typeSigs" -- get signatures
  let (name, t) = teleToType tel ty
      numberOfParams = length tel
  -- FIXME replace 'lift' with whatever capability does
  typechecked <- lift $ typeTerm param t (Annotation mempty (VStar 0))
  evaled <- lift $ liftEval $ Eval.evalTerm (Eval.lookupFun @ext globals) typechecked
  -- _ <- checkConType 0 [] [] numberOfParams evaled
  let (_, target) = typeToTele (name, t)
  -- FIXME replace 'lift'
  lift $ checkDeclared cname tel target
  -- vt <- eval [] tt
  -- put (addSig sig n (ConSig vt))
  return undefined --TODO return the list of globals

teleToType ::
  RawTelescope ext primTy primVal ->
  IR.Term' ext primTy primVal ->
  (Maybe Name, IR.Term' ext primTy primVal)
teleToType [] t = (Nothing, t)
teleToType (hd : tel) t2 =
  ( Just (rawName hd),
    Pi
      (rawUsage hd)
      (rawTy hd)
      (snd (teleToType tel t2))
      (rawExtension hd)
  )

typeToTele ::
  (Maybe Name, IR.Term' ext primTy primVal) ->
  (RawTelescope ext primTy primVal, IR.Term' ext primTy primVal)
typeToTele (n, t) = ttt (n, t) []
  where
    ttt ::
      (Maybe Name, IR.Term' ext primTy primVal) ->
      RawTelescope ext primTy primVal ->
      (RawTelescope ext primTy primVal, IR.Term' ext primTy primVal)
    ttt (Just n, Pi usage t' t2 ext) tel =
      ttt
        (Nothing, t2)
        ( tel
            <> [ RawTeleEle
                   { rawName = n,
                     rawUsage = usage,
                     rawTy = t',
                     rawExtension = ext
                   }
               ]
        )
    ttt x tel = (tel, snd x)

-- | checkDataType takes 5 arguments.
checkDataType ::
  (HasThrow "typecheckError" (TypecheckError' extV ext primTy primVal) m) =>
  -- | the next fresh generic value.
  Int ->
  -- | an env that binds fresh generic values to variables.
  Telescope extV extT primTy primVal ->
  -- | an env that binds the type value corresponding to these generic values.
  Telescope extV extT primTy primVal ->
  -- | the length of the telescope, or the no. of parameters.
  Int ->
  -- | the expression that is left to be checked.
  IR.Term' ext primTy primVal ->
  m ()
checkDataType k rho gamma p (Pi x t1 t2 _) = undefined
-- _ <-
--   if k < p -- if k < p then we're checking the parameters
--     then checkType k rho gamma t1 -- checks params are valid types
--     else checkSType k rho gamma t1 -- checks arguments Θ are Star types
--   v_t1 <- eval rho t1
--   checkDataType (k + 1) (updateTel rho x (VGen k)) (updateTel gamma x v_t1) p t2
-- check that the data type is of type Star
checkDataType _k _rho _gamma _p (Star _ _) = return ()
checkDataType _k _rho _gamma _p e =
  throwTC $ DatatypeError e

-- | checkConType check constructor type
checkConType ::
  ( HasThrow "typecheckError" (TypecheckError' extV ext primTy primVal) m,
    Param.CanApply primTy,
    Param.CanApply primVal,
    Eval.CanEval extT NoExt primTy primVal,
    Eval.HasPatSubstTerm (OnlyExts.T NoExt) primTy primVal primTy,
    Eval.HasPatSubstTerm (OnlyExts.T NoExt) primTy primVal primVal,
    Eq primTy,
    Eq primVal,
    IR.ValueAll Eq extV primTy primVal,
    IR.NeutralAll Eq extV primTy primVal,
    CanTC' extT primTy primVal m,
    Param.CanApply (TypedPrim primTy primVal),
    HasThrow "typecheckError" (TypecheckError' extV extT primTy primVal) m,
    HasThrow "typecheckError" (TypecheckError' extV NoExt primTy primVal) m
  ) =>
  -- | an env that contains the parameters of the datatype
  Telescope extV extT primTy primVal ->
  -- | name of the datatype
  GlobalName ->
  Param.Parameterisation primTy primVal ->
  -- | the expression that is left to be checked.
  IR.Value' extV primTy primVal ->
  m ()
checkConType tel datatypeName param e =
  case e of
    VPi' _ _ t2 _ ->
      -- recurse with updated envs
      checkConType
        tel
        datatypeName
        param
        t2
    IR.VNeutral' app _ ->
      let (dtName, paraTel) = unapps app []
       in case dtName of
            NFree' (Global name) _ ->
              if -- the datatype name matches
              name == datatypeName
                &&
                -- the parameters match
                map IR.ty tel == paraTel
                then return ()
                else -- datatype name or para don't match
                  throwTC $ ConDatatypeName dtName
            _ -> throwTC $ ConTypeError e
      where
        unapps (IR.NApp' f x _) acc = unapps f (x : acc)
        unapps f acc = (f, acc)
    _ -> throwTC $ ConTypeError e

-- check that the data type and the parameter arguments
-- are written down like declared in telescope
checkDeclared ::
  (HasThrow "typecheckError" (TypecheckError' extV ext primTy primVal) m) =>
  GlobalName ->
  RawTelescope ext primTy primVal ->
  IR.Term' ext primTy primVal ->
  m ()
checkDeclared name tel tg@(IR.Elim' (IR.App' (Free (Global n) _) term _) _) =
  if n == name
    then do
      checkParams tel term -- check parameters
    else throwTC $ DeclError tg name tel
checkDeclared name tel tg@(IR.Elim' (IR.Free' (Global n) _) _) =
  if n == name && null tel
    then return ()
    else throwTC $ DeclError tg name tel
checkDeclared name tel tg =
  throwTC $ DeclError tg name tel

-- check parameters
checkParams ::
  (HasThrow "typecheckError" (TypecheckError' extV ext primTy primVal) m) =>
  RawTelescope ext primTy primVal ->
  IR.Term' ext primTy primVal ->
  m ()
checkParams tel@(hd : tl) para@(Elim elim _) =
  let n = rawName hd
   in case elim of
        Free n' _ ->
          if n == n'
            then return ()
            else throwTC $ ParamVarNError tel n n'
        App (Free n' _) term _ ->
          if n == n'
            then checkParams tl term
            else throwTC $ ParamVarNError tel n n'
        _ -> throwTC $ ParamError para
checkParams [] _ = return ()
checkParams _ exps =
  throwTC $ ParamError exps
