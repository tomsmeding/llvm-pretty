{- |
Module      : Text.LLVM.Triple.Parse
Description : Parsing of LLVM target triples.
License     : BSD3
Maintainer  : Langston Barrett
Stability   : experimental
-}

module Text.LLVM.Triple.Parse
  ( parseVendor
  ) where

import Data.Maybe (fromMaybe)

import Text.LLVM.Triple.AST
import qualified Text.LLVM.Triple.Print as Print

enumTable :: Bounded a => Enum a => (a -> String) -> [(String, a)]
enumTable prnt = [(prnt a, a) | a <- enumFrom minBound]

parseVendor :: String -> Vendor
parseVendor s = fromMaybe UnknownVendor (lookup s (enumTable Print.vendorName))
