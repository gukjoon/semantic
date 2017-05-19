{-# LANGUAGE DataKinds, GADTs, ScopedTypeVariables, TypeOperators #-}
module Parser where

import Data.Functor.Union
import Data.Record
import qualified Data.Syntax as Syntax
import Data.Syntax.Assignment
import Data.Functor.Union (inj)
import qualified Data.Text as T
import Info hiding (Empty, Go)
import Language
import Language.Markdown
import Prologue hiding (Location)
import Source
import Syntax hiding (Go)
import Term
import qualified Text.Parser.TreeSitter as TS
import Text.Parser.TreeSitter.Language (Symbol)
import Text.Parser.TreeSitter.C
import Text.Parser.TreeSitter.Go
import Text.Parser.TreeSitter.Ruby
import Text.Parser.TreeSitter.TypeScript
import TreeSitter

data Parser term where
  ASTParser :: (Bounded grammar, Enum grammar) => Ptr TS.Language -> Parser (AST grammar)
  ALaCarteParser :: (InUnion fs (Syntax.Error [Error grammar]), Bounded grammar, Enum grammar, Eq grammar, Symbol grammar) => Parser (AST grammar) -> Assignment (Node grammar) (Term (Union fs) Location) -> Parser (Term (Union fs) Location)
  CParser :: Parser (SyntaxTerm Text DefaultFields)
  GoParser :: Parser (SyntaxTerm Text DefaultFields)
  MarkdownParser :: Parser (SyntaxTerm Text DefaultFields)
  RubyParser :: Parser (SyntaxTerm Text DefaultFields)
  TypeScriptParser :: Parser (SyntaxTerm Text DefaultFields)
  LineByLineParser :: Parser (SyntaxTerm Text DefaultFields)

-- | Return a 'Langauge'-specific 'Parser', if one exists, falling back to the 'LineByLineParser'.
parserForLanguage :: Maybe Language -> Parser (SyntaxTerm Text DefaultFields)
parserForLanguage Nothing = LineByLineParser
parserForLanguage (Just language) = case language of
  C -> CParser
  TypeScript -> TypeScriptParser
  Markdown -> MarkdownParser
  Ruby -> RubyParser
  Language.Go -> GoParser

runParser :: Parser term -> Source -> IO term
runParser parser = case parser of
  ASTParser language -> parseToAST language
  ALaCarteParser parser assignment -> \ source -> do
    ast <- runParser parser source
    let Result errors term = assign assignment source ast
    pure (fromMaybe (cofree ((totalRange source :. totalSpan source :. Nil) :< inj (Syntax.Error errors))) term)
  CParser -> treeSitterParser C tree_sitter_c
  GoParser -> treeSitterParser Go tree_sitter_go
  MarkdownParser -> cmarkParser
  RubyParser -> treeSitterParser Ruby tree_sitter_ruby
  TypeScriptParser -> treeSitterParser TypeScript tree_sitter_typescript
  LineByLineParser -> lineByLineParser

-- | A fallback parser that treats a file simply as rows of strings.
lineByLineParser :: Source -> IO (SyntaxTerm Text DefaultFields)
lineByLineParser source = pure . cofree . root $ case foldl' annotateLeaves ([], 0) lines of
  (leaves, _) -> cofree <$> leaves
  where
    lines = actualLines source
    root children = (sourceRange :. Program :. rangeToSourceSpan source sourceRange :. Nil) :< Indexed children
    sourceRange = Source.totalRange source
    leaf byteIndex line = (Range byteIndex (byteIndex + T.length line) :. Program :. rangeToSourceSpan source (Range byteIndex (byteIndex + T.length line)) :. Nil) :< Leaf line
    annotateLeaves (accum, byteIndex) line =
      (accum <> [ leaf byteIndex (Source.toText line) ] , byteIndex + Source.length line)
