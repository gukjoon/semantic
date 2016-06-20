{-# LANGUAGE DataKinds, FlexibleContexts, GeneralizedNewtypeDeriving #-}
module Info where

import Data.Record
import Prologue
import Category
import Range

newtype Size = Size { unSize :: Integer }
  deriving (Eq, Num, Show)
newtype Cost = Cost { unCost :: Integer }
  deriving (Eq, Num, Show)

type InfoFields = '[ Range, Category, Size, Cost ]

type Info = Record InfoFields

characterRange :: HasField fields Range => Record fields -> Range
characterRange = getField

setCharacterRange :: HasField fields Range => Record fields -> Range -> Record fields
setCharacterRange = setField

category :: HasField fields Category => Record fields -> Category
category = getField

setCategory :: HasField fields Category => Record fields -> Category -> Record fields
setCategory = setField

size :: HasField fields Size => Record fields -> Size
size = getField

setSize :: HasField fields Size => Record fields -> Size -> Record fields
setSize = setField

cost :: HasField fields Cost => Record fields -> Cost
cost = getField

setCost :: HasField fields Cost => Record fields -> Cost -> Record fields
setCost = setField
