{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

-- | This module provides some simple pretty-printing output verification tests.
-- This amounts to spot-checking a few places in the pretty printing that are
-- examined by hand: in general, it its much more effective to do round-trip
-- testing using AST's parsed from bitcode generated by actual programs, which is
-- what occurs in the llvm-pretty-bc-parser package (i.e. much more comprehensive
-- testing is deferred to the llvm-pretty-bc-parser package, which might then
-- reveal issues that need to be fixed in this llvm-pretty package).

module Output ( tests ) where

import           Control.Monad ( unless )
import qualified Data.Text as T
import           GHC.Float (castWord32ToFloat, castWord64ToDouble)
import qualified Test.Tasty as Tasty
import           Test.Tasty.HUnit
import qualified Text.PrettyPrint as PP

import           Text.LLVM.AST
import           Text.LLVM.PP

import           TQQDefs

tests :: Tasty.TestTree
tests = Tasty.testGroup "LLVM pretty-printing output tests"
  $ let -- s1 is a non-sensical construct whose primary intention is to hold two
        -- sub-structures that change their pretty representations at different
        -- LLVM versions.  The pretty output will be checked at different LLVM
        -- versions to ensure that the desired version-specific changes in the
        -- output are seen.
        s1, s2 :: Stmt
        s1 = Effect
             (GEP True (Alias (Ident "hi")) (Typed Opaque dcu) [])
             []
        s2 = Effect (Load PtrOpaque (Typed Opaque ValNull) Nothing Nothing)
             [ ("location", ValMdLoc $ DebugLoc { dlLine = 12
                                                , dlCol = 34
                                                , dlScope = ValMdRef 5
                                                , dlIA = Nothing
                                                , dlImplicit = True })
             ]
        dcu :: Value
        dcu = ValMd
              $ ValMdDebugInfo
              $ DebugInfoCompileUnit
              $ DICompileUnit { dicuLanguage = 12
                              , dicuFile = Nothing
                              , dicuProducer = Just "llvm-pretty-test"
                              , dicuIsOptimized = True
                              , dicuFlags = Just "some flags"
                              , dicuRuntimeVersion = 3
                              , dicuSplitDebugFilename = Nothing
                              , dicuEmissionKind = 1
                              , dicuEnums = Just dtt
                              , dicuRetainedTypes = Nothing
                              , dicuSubprograms = Nothing
                              , dicuGlobals = Nothing
                              , dicuImports = Nothing
                              , dicuMacros = Nothing
                              , dicuDWOId = 2
                              , dicuSplitDebugInlining = False
                              , dicuDebugInfoForProf = True
                              , dicuNameTableKind = 4
                              , dicuRangesBaseAddress = True
                              , dicuSysRoot = Just "the root"
                              , dicuSDK = Just "SDK"
                              }
        dtt = ValMdDebugInfo
              $ DebugInfoTemplateTypeParameter
              $ DITemplateTypeParameter { dittpName = Just "ttp"
                                        , dittpType = Nothing
                                        , dittpIsDefault = Just True
                                        }
        blk1 = BasicBlock { bbLabel = Just $ Named $ Ident "blk1"
                          , bbStmts =
                            [ Result (Ident "r1") (Comment "insanity follows...") []
                            , Effect (Jump $ Named $ Ident "blk1") []
                            , Result (Ident "oh no") RetVoid []
                            , Effect (Br (Typed (PrimType Metadata) ValZeroInit) (Anon 3) (Named "oh no")) []
                            ]
                          }
        blk2 = BasicBlock { bbLabel = Just $ Anon 123
                          , bbStmts = []
                          }
        ppToText = T.pack
                   -- render with a line-length of 30 to encourage wrapping on
                   -- most list elements or arguments for consistent output to
                   -- verify against any changes.
                   . PP.renderStyle (PP.Style PP.PageMode 30 1.0)
  in
  [
    testCase "Stmt 1, LLVM 3.5" $
    assertEqLines [sq|
      ----
      getelementptr inbounds opaque !DICompileUnit(language: 12,
                                                   producer: "llvm-pretty-test",
                                                   isOptimized: true,
                                                   flags: "some flags",
                                                   runtimeVersion: 3,
                                                   emissionKind: 1,
                                                   enums: !DITemplateTypeParameter(name: ttp),
                                                   dwoId: 2,
                                                   splitDebugInlining: false,
                                                   debugInfoForProfiling: true,
                                                   nameTableKind: 4)
      ----
      |]
      (ppToText $ ppLLVM35 ppStmt s1)

  , testCase "Stmt 1, LLVM 3.7" $
    assertEqLines [sq|
      In LLVM 3.7, the GEP instruction output shows the additional type
      ----
      getelementptr inbounds %hi, opaque !DICompileUnit(language: 12,
                                                        producer: "llvm-pretty-test",
                                                        isOptimized: true,
                                                        flags: "some flags",
                                                        runtimeVersion: 3,
                                                        emissionKind: 1,
                                                        enums: !DITemplateTypeParameter(name: ttp),
                                                        dwoId: 2,
                                                        splitDebugInlining: false,
                                                        debugInfoForProfiling: true,
                                                        nameTableKind: 4)
      ----
      |]
      (ppToText $ ppLLVM37 ppStmt s1)

  , testCase "Stmt 1, LLVM 10" $
    assertEqLines (ppToText $ ppLLVM 10 $ ppStmt s1) [sq|
      No change from LLVM 3.7 through LLVM 10
      ----
      getelementptr inbounds %hi, opaque !DICompileUnit(language: 12,
                                                        producer: "llvm-pretty-test",
                                                        isOptimized: true,
                                                        flags: "some flags",
                                                        runtimeVersion: 3,
                                                        emissionKind: 1,
                                                        enums: !DITemplateTypeParameter(name: ttp),
                                                        dwoId: 2,
                                                        splitDebugInlining: false,
                                                        debugInfoForProfiling: true,
                                                        nameTableKind: 4)
      ----
      |]

  , testCase "Stmt 1, LLVM 11" $
    assertEqLines (ppToText $ ppLLVM 11 $ ppStmt s1) [sq|
      In LLVM 11, DICompileUnit adds rangesBaseAddress, sysroot, and sdk
      ----
      getelementptr inbounds %hi, opaque !DICompileUnit(language: 12,
                                                        producer: "llvm-pretty-test",
                                                        isOptimized: true,
                                                        flags: "some flags",
                                                        runtimeVersion: 3,
                                                        emissionKind: 1,
                                                        enums: !DITemplateTypeParameter(name: ttp),
                                                        dwoId: 2,
                                                        splitDebugInlining: false,
                                                        debugInfoForProfiling: true,
                                                        nameTableKind: 4,
                                                        rangesBaseAddress: true,
                                                        sysroot: "the root",
                                                        sdk: "SDK")
      ----
      |]

  ------------------------------------------------------------

  , testCase "Stmt 2, LLVM 3.5" $
    assertEqLines [sq|
      ----
      load opaque null, !location !MDLocation(line: 12,
                                              column: 34,
                                              scope: !5, implicit)
      ----
      |]
      (ppToText $ ppLLVM35 ppStmt s2)

  , testCase "Stmt 2, LLVM 3.7" $
    assertEqLines [sq|
      Beginning in LLVM 3.7, the type is no longer implicit and is explicitly
      shown, and the DebugLoc metadata is DILocation instead of MDLocation
      ----
      load ptr, opaque null, !location !DILocation(line: 12,
                                                   column: 34,
                                                   scope: !5, implicit)
      ----
      |]
      (ppToText $ ppLLVM37 ppStmt s2)

  , testCase "Stmt 2, LLVM 10" $
    assertEqLines [sq|
      No change since LLVM 3.7
      ----
      load ptr, opaque null, !location !DILocation(line: 12,
                                                   column: 34,
                                                   scope: !5, implicit)
      ----
      |]
      (ppToText $ ppLLVM 10 $ ppStmt s2)

  ------------------------------------------------------------
  -- Verify named labels and label targets are emitted correctly

  , testCase "Blk 1, LLVM 3.5" $
    assertEqLines (ppToText $ ppLLVM35 ppBasicBlock blk1) [sq|
      --------
      blk1:
        %r1 = ; insanity follows...
        br label %blk1
        %"oh no" = ret void
        br metadata zeroinitializer, label %3, label %"oh no"
      --------
      |]

  , testCase "Blk 1, LLVM 3.7" $
    assertEqLines (ppToText $ ppLLVM37 ppBasicBlock blk1) [sq|
      --------
      blk1:
        %r1 = ; insanity follows...
        br label %blk1
        %"oh no" = ret void
        br metadata zeroinitializer, label %3, label %"oh no"
      --------
      |]

  ------------------------------------------------------------
  -- Verify anonymous labels are emitted correctly

  , testCase "Blk 2, LLVM 3.5" $
    assertEqLines (ppToText $ ppLLVM35 ppBasicBlock blk2) [sq|
      --------
      ; <label>: 123
      --------
      |]

  , testCase "Blk 2, LLVM 3.7" $
    assertEqLines (ppToText $ ppLLVM37 ppBasicBlock blk2) [sq|
      --------
      ; <label>: 123
      --------
      |]

  -- NOTE: The following tests' expected output may look surprising.  See the "WARNING" note in
  -- `ppValue'` for details.

  , testCase "Floats should use 64-bit constants" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValFloat (castWord32ToFloat 0x42280000)))
      "0x4045000000000000"

  , testCase "Positive Infinity (float)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValFloat (castWord32ToFloat 0x7F800000)))
      "0x7ff0000000000000"

  , testCase "Negative Infinity (float)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValFloat (castWord32ToFloat 0xFF800000)))
      "0xfff0000000000000"

  , testCase "NaN 1 (float)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValFloat (castWord32ToFloat 0x7FC00000)))
      "0x7ff8000000000000"

  , testCase "NaN 2 (float)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValFloat (castWord32ToFloat 0x7FD00000)))
      "0x7ffa000000000000"

  , testCase "Positive Infinity (double)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValDouble (castWord64ToDouble 0x7FF0000000000000)))
      "0x7ff0000000000000"

  , testCase "Negative Infinity (double)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValDouble (castWord64ToDouble 0xFFF0000000000000)))
      "0xfff0000000000000"

  , testCase "NaN 1 (double)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValDouble (castWord64ToDouble 0x7FFC000000000000)))
      "0x7ffc000000000000"

  , testCase "NaN 2 (double)" $
    assertEqLines
      (ppToText $ ppLLVM37 ppValue (ValDouble (castWord64ToDouble 0x7FFD000000000000)))
      "0x7ffd000000000000"

  ]

----------------------------------------------------------------------

assertEqLines :: T.Text -> T.Text -> IO ()
assertEqLines t1 t2 =
  unless (t1 == t2) $ assertFailure $ multiLineDiff t1 t2

-- | The multiLineDiff is another helper function that can be used to
-- format a line-by-line difference display of two Text
-- representations.  This is provided as a convenience function to
-- help format large text regions for easier comparison.

multiLineDiff :: T.Text -> T.Text -> String
multiLineDiff expected actual =
  let dl (e,a) = if e == a then db e else de " ↱" e <> "\n    " <> da " ↳" a
      db b = "|        > " <> b
      de m e = "|" <> m <> "expect> " <> e
      da m a = "|" <> m <> "actual> " <> a
      el = take 1450 (visible <$> T.lines expected)
      al = take 1450 (visible <$> T.lines actual)
      visible = T.replace " " "␠"
                . T.replace "\n" "␤"
                . T.replace "\t" "␉"
                . T.replace "\012" "␍"
      addnum :: Int -> T.Text -> T.Text
      addnum n l = let nt = T.pack (show n)
                       nl = T.length nt
                   in T.take (4 - nl) "    " <> nt <> l
      ll = T.pack . show . length
      tl = T.pack . show . T.length
      banner = "MISMATCH between "
               <> ll el <> "l/" <> tl expected <> "c expected and "
               <> ll al <> "l/" <> tl actual <> "c actual"
      diffReport = fmap (uncurry addnum) $
                   zip [1..] $ concat $
                   -- Highly simplistic "diff" output assumes
                   -- correlated lines: added or removed lines just
                   -- cause everything to shown as different from that
                   -- point forward.
                   [ fmap dl $ zip el al
                   , fmap (de "∌ ") $ drop (length al) el
                   , fmap (da "∹ ") $ drop (length el) al
                   ]
                   -- n.b. T.lines seems to consume trailing whitespace before
                   -- newlines as well.  This will show any of this whitespace
                   -- difference on the last line, but not for other lines with
                   -- whitespace.
                   <> if el == al
                      then let maxlen = max (T.length expected) (T.length actual)
                               end x = T.drop (maxlen - 5) x
                           in [ [ de "∌ ending " $ visible $ end expected ]
                              , [ da "∹ ending " $ visible $ end actual ]
                              ]
                      else mempty
      details = banner : diffReport
  in if expected == actual then "<no difference>" else T.unpack (T.unlines details)
