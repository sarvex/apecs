{-# LANGUAGE GeneralizedNewtypeDeriving, StandaloneDeriving, UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Control.ECS.Mutable where

import Control.Monad.State
import qualified Data.HashTable.IO as H
import Data.IORef
import Data.Maybe

import Control.ECS.Storage

newtype Global c = Global {getGlobal :: IORef c}

instance Monoid c => SStorage IO (Global c) where
  type SElem     (Global c) = c
  type SSafeElem (Global c) = c

  sEmpty = Global <$> newIORef mempty
  sSlice    _   = return []
  sMember   _ _ = return False
  sDestroy  _ _ = return ()
  sRetrieve (Global ref) _ = readIORef ref
  sStore    (Global ref) x _ = writeIORef ref x
  sOver     (Global ref) = modifyIORef' ref
  sForC     (Global ref) f = void $ readIORef ref >>= f


newtype HashTable c = HashTable {getHashTable :: H.BasicHashTable Int c}

instance SStorage IO (HashTable c) where
  type SSafeElem (HashTable c) = Maybe c
  type SElem     (HashTable c) = c

  sEmpty = HashTable <$> H.new
  sSlice    (HashTable h) = fmap fst <$> H.toList h
  sMember   (HashTable h) ety = isJust <$> H.lookup h ety
  sDestroy  (HashTable h) ety = H.delete h ety
  sRetrieve (HashTable h) ety = H.lookup h ety
  sStore    h Nothing ety = sDestroy h ety
  sStore    (HashTable h) (Just x) ety = H.insert h ety x
  sOver     (HashTable h) f = flip H.mapM_ h $ \(k,x) -> H.insert h k (f x)
  sForC     (HashTable h) fm = flip H.mapM_ h $ \(_,x) -> fm x

