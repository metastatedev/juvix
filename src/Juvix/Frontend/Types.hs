{-# LANGUAGE TemplateHaskell #-}

module Juvix.Frontend.Types where

import Control.Lens
import Juvix.Library hiding (Product, Sum, Type)

data TopLevel
  = Type Type
  | ModuleOpen ModuleOpen
  | TypeClass
  | TypeClassInstance
  | ModuleSignature
  | Module Module
  | Signature
  | Function Function
  deriving (Show)

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

data Type
  = Typ
      { typeName ∷ !Symbol,
        typeForm ∷ TypeSum
      }
  deriving (Show)

data TypeSum
  = Alias Alias
  | -- Maybe not needed!?
    NewType NewType
  | Data Data
  deriving (Show)

-- | 'Data' is the data declaration in the Juvix language
data Data
  = Arrowed
      { dataArrow ∷ ArrowType,
        dataAdt ∷ Adt
      }
  | NonArrowed
      { dataAdt ∷ Adt
      }
  deriving (Show)

data NewType
  = Declare
      { newTypeAlias ∷ !Symbol,
        newTypeType' ∷ TypeRefine
      }
  deriving (Show)

newtype Alias
  = AliasDec
      {aliasType' ∷ TypeRefine}
  deriving (Show)

--------------------------------------------------
-- Arrows
--------------------------------------------------

data ArrowType
  = Refined TypeRefine
  | Arrows ArrowData
  | Parens ArrowType
  deriving (Show)

data ArrowData
  = Arr
      { arrowDataName ∷ !(Maybe Name),
        arrowDataRefine ∷ TypeRefine,
        arrowDataArrow ∷ !ArrowSymbol
      }
  deriving (Show)

--------------------------------------------------
-- Types Misc
--------------------------------------------------

data TypeRefine
  = TypeRefine
      { typeRefineName ∷ !TypeName,
        typeRefineRfeinement ∷ Maybe Expression
      }
  deriving (Show)

data Name
  = Implicit !Symbol
  | Concrete !Symbol
  deriving (Show)

type ArrowSymbol = Natural

-- I think we can do
-- Foo a u#b c ?
data TypeName
  = Final !Symbol
  | Next Symbol TypeName
  | Universe UniverseExpression TypeName
  deriving (Show)

data UniverseExpression
  = UniverseExpression
  deriving (Show)

--------------------------------------------------
-- ADTs
--------------------------------------------------

data Adt
  = Sum (NonEmpty Sum)
  | Product Product
  deriving (Show)

data Sum
  = S
      { sumConstructor ∷ !Symbol,
        sumValue ∷ !(Maybe Product)
      }
  deriving (Show)

data Product
  = Record !Record
  | Arrow !ArrowType
  deriving (Show)

data Record
  = Record'
      { recordFields ∷ NonEmpty NameType,
        recordFamilySignature ∷ !TypeName
      }
  deriving (Show)

data NameType
  = NonErased
      { nameTypeSignature ∷ !ArrowType,
        nameTypeName ∷ !Name
      }
  deriving (Show)

--------------------------------------------------------------------------------
-- Functions And Modules
--------------------------------------------------------------------------------

-- | 'Function' is a normal signature with a name arguments and a body
-- that may or may not have a guard before it
newtype Function
  = Func (FunctionLike TopLevel)
  deriving (Show)

-- | 'Module' is like function, however it allows multiple top levels
newtype Module
  = Mod (FunctionLike TopLevel)
  deriving (Show)

-- | 'FunctionLike' is the generic version for both modules and functions
data FunctionLike a
  = Like
      { functionLikedName ∷ NameSymb,
        functionLikeArgs ∷ [Args],
        functionLikeBody ∷ GuardBody a
      }
  deriving (Show)

-- | 'GuardBody' determines if a form is a guard or a body
data GuardBody a
  = Body a
  | Guard (Cond a)
  deriving (Show)

newtype ModuleOpen
  = Open ModuleName
  deriving (Show)

-- Very similar to name, but match instead of symbol
data Args
  = ImplicitA MatchLogic
  | ConcreteA MatchLogic
  deriving (Show)

newtype ModuleName = ModuleName' Symbol deriving (Show)

newtype Cond a
  = C (NonEmpty (CondLogic a))
  deriving (Show)

data CondLogic a
  = CondExpression
      { condLogicPred ∷ Expression,
        condLogicBody ∷ a
      }
  deriving (Show)

--------------------------------------------------------------------------------
-- Signatures
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Type Classes
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Expression
--------------------------------------------------------------------------------

data Expression
  = Cond (Cond Expression)
  | Number Numb
  | String String'
  | Let Let
  | Match Match
  | Name NameSymb
  deriving (Show)

data Numb
  = Integer' Integer
  | Double' Double
  | ExponentD Double Integer
  | Exponent Integer Integer
  deriving (Show)

newtype String'
  = Sho Text
  deriving (Show)

--------------------------------------------------
-- Symbol Binding
--------------------------------------------------

data Let
  = Let'
      { letBindings ∷ NonEmpty Binding,
        letBody ∷ Expression
      }
  deriving (Show)

data Binding
  = Bind
      { bindingPattern ∷ MatchLogic,
        bindingBody ∷ Expression
      }
  deriving (Show)

--------------------------------------------------
-- Matching
--------------------------------------------------

data Match
  = Match'
      { matchOn ∷ Expression,
        matchBindigns ∷ NonEmpty MatchL
      }
  deriving (Show)

data MatchL
  = MatchL
      { matchLPattern ∷ MatchLogic,
        matchLBody ∷ Expression
      }
  deriving (Show)

data MatchLogic
  = MatchLogic
      { matchLogicContents ∷ MatchLogicCont,
        matchLogicNamed ∷ Maybe NameSymb
      }
  deriving (Show)

data MatchLogicCont
  = MatchCon ConstructorName
  | MatchName NameSymb
  | MatchRecord NameSet
  deriving (Show)

data NameSet
  = Punned NameSymb
  | NonPunned NameSymb NameSymb
  deriving (Show)

type ConstructorName = Symbol

type NameSymb = Symbol

--------------------------------------------------------------------------------
-- Lens creation
--------------------------------------------------------------------------------

makeLensesWith camelCaseFields ''Data

makeLensesWith camelCaseFields ''Type

makeLensesWith camelCaseFields ''NewType

makeLensesWith camelCaseFields ''Sum

makeLensesWith camelCaseFields ''Record

makeLensesWith camelCaseFields ''CondLogic

makeLensesWith camelCaseFields ''Let

makeLensesWith camelCaseFields ''Match

makeLensesWith camelCaseFields ''MatchL

makeLensesWith camelCaseFields ''MatchLogic

makeLensesWith camelCaseFields ''Binding

makeLensesWith camelCaseFields ''FunctionLike

makeLensesWith camelCaseFields ''Module

makeLensesWith camelCaseFields ''Function

makePrisms ''TypeSum
