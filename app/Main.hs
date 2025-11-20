{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

import qualified Control.Exception as Exception
import qualified Crypto.Hash.SHA256 as Sha256
import Data.Aeson (FromJSON, (.=))
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Base16 as Base16
import qualified Data.ByteString.UTF8 as Utf8
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Lazy as LText
import qualified Network.HTTP.Types as Http
import System.Directory.OsPath as OsPath
import System.Directory.Internal as Directory
import System.Exit (ExitCode (..))
import qualified System.Process as Process
import Web.Scotty (ActionM)
import qualified Web.Scotty as Scotty

-- Define the expected JSON input structure
newtype RPackageList = RPackageList {unRPackageList :: [Text]}
    deriving (Show)
    deriving (FromJSON) via [Text]

getImageHandler :: ActionM ()
getImageHandler = do
    -- Parse JSON input
    input <- Scotty.body
    let maybePackages = Aeson.decode input :: Maybe RPackageList
    case maybePackages of
        Nothing -> do
            Scotty.status Http.status400
            Scotty.text "Expecting package list"
        Just packageList -> do
            let nixList = "[ \"" <> Text.intercalate "\" \"" (unRPackageList packageList) <> "\" ]"
            let hash = Base16.encode $ Sha256.hash $ TextEncoding.encodeUtf8 nixList
            let outLinkPath = "build-result-" <> Utf8.toString hash

            cacheHit <- Scotty.liftIO $ OsPath.doesFileExist $ Directory.os outLinkPath
            if cacheHit
                then do
                    Scotty.setHeader "Content-Type" "application/octet-stream"
                    Scotty.setHeader "Content-Disposition" ("attachment; filename=\"r-container-" <> LText.pack outLinkPath <> ".tar.gz\"")
                    Scotty.status Http.ok200
                    Scotty.file outLinkPath
                else do
                    let nixBuildArgs =
                            [ "nix/pkgs/r-builder.nix"
                            , "--out-link"
                            , outLinkPath
                            , "--arg"
                            , "extra-r-packages"
                            , Text.unpack nixList
                            ]
                    let cmd = Process.proc "nix-build" nixBuildArgs

                    let exceptionHandler (e :: Exception.SomeException) = do
                            pure (ExitFailure 1, "", "System Exception: " <> show e, "")

                    result <- Scotty.liftIO $ Exception.handle exceptionHandler $ do
                        (eCode, out, err) <- Process.readCreateProcessWithExitCode cmd ""
                        return (eCode, out, err, outLinkPath)

                    case result of
                        (ExitSuccess, _, _, imagePath) -> do
                            -- Success: Set headers and stream the binary image file
                            Scotty.setHeader "Content-Type" "application/octet-stream"
                            Scotty.setHeader "Content-Disposition" ("attachment; filename=\"r-container-" <> LText.pack outLinkPath <> ".tar.gz\"")
                            Scotty.status Http.ok200
                            Scotty.file imagePath
                        (ExitFailure n, stdOut, stdErr, _) -> do
                            -- Failure: Return error message with logs as JSON
                            Scotty.status Http.internalServerError500
                            Scotty.json $
                                Aeson.object
                                    [ "error" .= LText.pack ("Nix build failed with exit code " <> show n)
                                    , "stdout" .= LText.pack stdOut
                                    , "stderr" .= LText.pack stdErr
                                    ]

main :: IO ()
main = Scotty.scotty 3000 $ do
    Scotty.get "/" $ do
        Scotty.setHeader "content-type" "application/html"
        Scotty.file "index.html"

    Scotty.get "/all-packages" $ do
        Scotty.setHeader "Content-Type" "text/json"
        Scotty.file "packages/var/r-packages-all.json"

    Scotty.get "/default-packages" $ do
        Scotty.setHeader "Content-Type" "text/json"
        Scotty.file "packages/var/r-packages-preinstalled.json"

    -- The main route
    Scotty.post "/get-image" $ do
        getImageHandler
