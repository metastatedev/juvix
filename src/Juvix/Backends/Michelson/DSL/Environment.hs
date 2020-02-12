module Juvix.Backends.Michelson.DSL.Environment where

import Juvix.Library
import qualified Juvix.Backends.Michelson.Compilation.Types as Types
import qualified Juvix.Backends.Michelson.Compilation.VirtualStack as VStack

data Env
  = Env
     { -- | The Virtual stack that mimics the real Michelson stack.
       stack ∷ VStack.T,
       -- | Information during Compilation.
       compilationLog ∷ [Types.CompilationLog],
       -- | The Operations for the Michelson Contract.
       ops ∷ [Types.Op],
       -- | count of unnamed arguments for primitives.
       count ∷ Word,
       -- | Debug level.
       debug ∷ Int
     }
     deriving (Show, Generic)

type CompError = Types.CompilationError

newtype MichelsonCompilation a =
  Compilation (ExceptT CompError (State Env) a)
  deriving (Functor, Applicative, Monad)
  deriving
    ( HasStream "compilationLog" [Types.CompilationLog],
      HasWriter "compilationLog" [Types.CompilationLog]
    )
    via WriterLog (Field "compilationLog" () (MonadState (ExceptT CompError (State Env))))
  deriving
    (HasState "stack" VStack.T)
    via Field "stack" () (MonadState (ExceptT CompError (State Env)))
  deriving
    (HasState "ops" [Types.Op])
    via Field "ops" () (MonadState (ExceptT CompError (State Env)))
  deriving
    (HasState "count" Word)
    via Field "count" () (MonadState (ExceptT CompError (State Env)))
  deriving
    (HasThrow "compilationError" CompError)
    via MonadError (ExceptT CompError (State Env))
  deriving
    (HasReader "debug" Int)
    via Field "debug" () (ReadStatePure (MonadState (ExceptT CompError (State Env))))
