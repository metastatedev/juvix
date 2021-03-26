{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LiberalTypeSynonyms #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeFamilyDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
module Juvix.Pipeline.Backend.Internal where
import qualified Juvix.Core.Application as CoreApp
import qualified Juvix.Core.ErasedAnn as ErasedAnn
import qualified Juvix.Core.IR as IR
import qualified Juvix.Core.IR.TransformExt.OnlyExts as OnlyExts
import qualified Juvix.Core.IR.Typechecker.Types as TypeChecker
import Juvix.Core.IR.Types.Base
import Juvix.Core.IR.Types.Globals
import Juvix.Core.Parameterisation
import Juvix.Library
import qualified Juvix.Pipeline.Internal as Pipeline
import Juvix.Pipeline.Compile
import qualified Juvix.Library.Sexp as Sexp
import qualified Juvix.Core.Common.Context as Context

class HasBackend b where
  type Ty b = ty | ty -> b
  type Val b = val | val -> b

  typecheck :: Context.T Sexp.T Sexp.T Sexp.T -> Pipeline (ErasedAnn.AnnTerm (Ty b) (CoreApp.Return' ErasedAnn.T (NonEmpty (Ty b)) (Val b)))
  compile :: ErasedAnn.AnnTerm (Ty b) (CoreApp.Return' ErasedAnn.T (NonEmpty (Ty b)) (Val b)) -> Pipeline Text


