module Example where

open import Function
open import Data.Nat
open import Data.Nat.Properties
open import Data.Fin hiding (_≤_)
open import Relation.Binary.PropositionalEquality

open import Usage
open import NatUsage
open import QTT NoSub.any

variable
  n : ℕ
  e : Elim n

A : ∀ {n} → Tm n
A = sort 0

f = Fin 2 ∋ # 1
x = Fin 2 ∋ # 0

-- 2 f: (2 x: A) (3 y: A) → A, 10 x: A ⊢ 2 f x x: A
-- though note that the usages in the context are *outputs*
-- i.e. they're not checked against anything
example : ε ⨟ Π 2 A (Π 3 A A) ⨟ A ⊢ 2 - ` f ∙ [ ` x ] ∙ [ ` x ] ∈ A ▷ ε ⨟ 2 ⨟ 10
example =
  app refl refl
    (app refl refl
      (var refl (ε ⨟[ refl ] ⨟ refl))
      (elim refl
        (var refl (ε ⨟ refl ⨟[ refl ]))))
    (elim refl
      (var refl (ε ⨟ refl ⨟[ refl ])))
