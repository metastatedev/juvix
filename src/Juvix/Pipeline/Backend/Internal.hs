{-# LANGUAGE TypeFamilyDependencies #-}

module Juvix.Pipeline.Backend.Internal
  ( HasBackend (..),
    writeout,
  )
where

import qualified Data.Text as Text
import qualified Data.Text.IO as T
import qualified Juvix.Core.Application as CoreApp
import qualified Juvix.Core.Common.Context as Context
import qualified Juvix.Core.ErasedAnn as ErasedAnn
import Juvix.Library
import qualified Juvix.Library.Feedback as Feedback
import qualified Juvix.Library.Sexp as Sexp
import Juvix.Pipeline.Compile
import qualified Juvix.Pipeline.Internal as Pipeline
import qualified System.IO.Temp as Temp

class HasBackend b where
  type Ty b = ty | ty -> b
  type Val b = val | val -> b

  stdlibs :: b -> [FilePath]
  default stdlibs :: b -> [FilePath]
  stdlibs _ = []

  parse :: b -> Text -> Pipeline (Context.T Sexp.T Sexp.T Sexp.T)
  default parse :: b -> Text -> Pipeline (Context.T Sexp.T Sexp.T Sexp.T)
  parse b code = do
    core <- liftIO $ toCore_wrap code
    case core of
      Right ctx -> return ctx
      Left err -> Feedback.fail $ show err
    where
      toCore_wrap :: Text -> IO (Either Pipeline.Error (Context.T Sexp.T Sexp.T Sexp.T))
      toCore_wrap code = do
        fp <- Temp.writeSystemTempFile "juvix-toCore.ju" (Text.unpack code)
        Pipeline.toCore
          (["stdlib/Prelude.ju", fp] ++ stdlibs b)

  typecheck :: Context.T Sexp.T Sexp.T Sexp.T -> Pipeline (ErasedAnn.AnnTerm (Ty b) (CoreApp.Return' ErasedAnn.T (NonEmpty (Ty b)) (Val b)))
  compile :: FilePath -> ErasedAnn.AnnTerm (Ty b) (CoreApp.Return' ErasedAnn.T (NonEmpty (Ty b)) (Val b)) -> Pipeline ()

-- | Write the output code to a given file.
writeout :: FilePath -> Text -> Pipeline ()
writeout fout code = liftIO $ T.writeFile fout code
