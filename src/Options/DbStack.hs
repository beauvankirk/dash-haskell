module Options.DbStack where
import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.M
-- import           FilePath
import qualified Data.List as L
import           Text.ParserCombinators.Parsec


import           Distribution.Package
import           Distribution.ParseUtils as CP
import           Distribution.Simple.Compiler as CC
import           Distribution.Simple.PackageIndex as CI
import           Distribution.Simple.Program as C
import           Distribution.Simple.Program.Db as CD
import           Distribution.Verbosity as CVB
import           Distribution.Version as CVS

import           Options.Applicative.Types (ReadM, readerError, readerAsk)

-- data GhcPkg = GhcPkg { args :: [String] , stack :: DbStack }
-- data DbStack = Single FilePath | Ghc (Maybe String) 
data Db     = 
  Sandbox (Maybe FilePath) 
  | Global 
  | User 
  | Path FilePath deriving (Ord, Eq)

defaultStack :: [Db] 
defaultStack = [Sandbox Nothing, Global, User]

-- TODO 
-- create args to handle this, e.g. 
--   --sandbox,s (automatically on if sourcing from cabal file) 
--   --global,g
--   --user,u
--   --db,db
     
-- TODO 
-- convert default stack to Set, and  


-- instance (Show DbStack) where
--   show dbp = 
--     let (cmd, args) = toExec dbp in 
--       L.intercalate "\n" [
--       "lookup strategy: ", 
--          case dbp of 
--            Sandbox _ -> "cabal sandbox db stack" 
--            Ghc          _ -> "ghc db stack" 
--            Db           _ -> "db index with directory narrowing" 
--       ]

fromSplit :: Char -> String -> ReadM (String, Maybe String)
fromSplit c opt = 
  case opt of 
    []      -> return ([], Nothing) 
    (s:str) ->
     if s == c then do
       param <- fromParam str 
       return ([], param)
     else do 
       (l, r) <- fromSplit c str
       return (s:l, r)
  where 
    fromParam []      =  return Nothing
    fromParam (c':str)=
      if c' == c then
        readerError $ "encountered delimeter(" ++ c:") twice"
      else
        Just . maybe [c'] (c':) <$> fromParam str

-- toExec :: DbStack -> (String, [String])
-- toExec (Sandbox args) =
--   (,) "cabal" $ ["sandbox", "hc-pkg", "list"] ++ maybeToList args
-- toExec (Ghc args)          = 
--   (,) "ghc-pkg" $ "list" : maybeToList args
-- toExec (Db fp)             = 
--   (,) "ghc-pkg" ("list":["--package-db=" ++ fp]) 

field :: String -> Parser String
field str =
  string str 
  >> char ':'
  >> many (char ' ') 
  >> manyTill anyToken (void (char '\n') <|> eof)

singleField :: String -> Parser String 
singleField str = try (field str) <|> (anyToken >> singleField str) 
 
parsedDb :: String -> M String 
parsedDb path = do
  buf <- liftIO $ readFile path
  case runParser (singleField "package-db") () path buf of
    Left  str -> err . show $ str
    Right db      -> return db 

toStack :: ReadM DbStack
toStack = do
  expr        <- readerAsk
  (prov, arg) <- fromSplit ',' expr
  
  join $ constructor prov <*> pure arg
  where 
    constructor :: String -> ReadM (Maybe String -> ReadM DbStack) 
    constructor prov = maybe (readerError "invalid db provider") return f
     where 
      f :: Maybe (Maybe String -> ReadM DbStack)
      f = L.lookup prov-- produce a constructor given an arg
            [("ghc"   , return . Ghc),
             ("cabal" , return . Sandbox),
             ("dir"   , 
               maybe (readerError "requires directory path") (return . Single))
            ]

sandboxConfig :: String
sandboxConfig = "cabal.sandbox.config" 

-- toSpecific :: FilePath -> M PackageDBStack
-- toSpecific fp = do 
--   maybe_err <- liftIO $ 
--     checkPath False (maybe sandboxConfig id fp) "cabal sandbox config"
--   case maybe_err of
--     Nothing      -> 
--       return [SpecificPackageDB fp] 
--     Just err_str ->
--       err err_str 
--   return ()
  
-- f (Ghc       _)     = return [UserPackageDB, GlobalPackageDB] 
-- f (Single path)     = return [SpecificPackageDB path] 


-- fromStack :: 
--   [C.Dependency] -- ^ dependencies to resolve to those provided by db
--   -> DbStack      -- ^ stack of databases
--   -> M [(FilePath, [(String, PackageIdentifier)])] 
-- fromStack stack pkgs =
-- fromStack :: DbStack -> M PackageDB 
-- fromStack (Sandbox        args) =  
-- fromStack (Ghc            args) =  
-- fromStack (B db_path args) = return $ SpecificPackageDb db_path 
