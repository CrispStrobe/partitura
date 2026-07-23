library;

enum TokenKind {
  command,
  word,
  string,
  symbol,
  eof,
}

class Token {
  final TokenKind kind;
  final String value;
  final int line;
  final int column;

  const Token(this.kind, this.value, this.line, this.column);

  @override
  String toString() => '$kind($value) at $line:$column';
}

class LilyPondLexer {
  final String source;
  int _pos = 0;
  int _line = 1;
  int _col = 1;

  LilyPondLexer(this.source);

  List<Token> tokenize() {
    final tokens = <Token>[];
    while (_pos < source.length) {
      _skipWhitespaceAndComments();
      if (_pos >= source.length) break;

      final startLine = _line;
      final startCol = _col;
      final char = source[_pos];

      if (char == '"') {
        tokens.add(Token(TokenKind.string, _readString(), startLine, startCol));
        continue;
      }

      if (char == '\\') {
        final peek = _peek();
        if (peek == '\\') {
          _advance(2);
          tokens.add(Token(TokenKind.symbol, '\\\\', startLine, startCol));
        } else if (_isAlpha(peek)) {
          tokens.add(Token(TokenKind.command, _readCommand(), startLine, startCol));
        } else {
          _advance(1);
          tokens.add(Token(TokenKind.symbol, '\\', startLine, startCol));
        }
        continue;
      }

      if (_isSymbolPrefix(char)) {
        final sym = _readSymbol();
        tokens.add(Token(TokenKind.symbol, sym, startLine, startCol));
        continue;
      }

      final word = _readWord();
      if (word.isNotEmpty) {
        tokens.add(Token(TokenKind.word, word, startLine, startCol));
      } else {
        // Unknown character, just skip or treat as symbol
        _advance(1);
      }
    }
    tokens.add(Token(TokenKind.eof, '', _line, _col));
    return tokens;
  }

  void _skipWhitespaceAndComments() {
    while (_pos < source.length) {
      final char = source[_pos];
      if (char == ' ' || char == '\t' || char == '\r' || char == '\n') {
        if (char == '\n') {
          _line++;
          _col = 1;
        } else {
          _col++;
        }
        _pos++;
      } else if (char == '%') {
        final peek = _peek();
        if (peek == '{') {
          _advance(2);
          _skipBlockComment();
        } else {
          _skipLineComment();
        }
      } else {
        break;
      }
    }
  }

  void _skipLineComment() {
    while (_pos < source.length && source[_pos] != '\n') {
      _advance(1);
    }
  }

  void _skipBlockComment() {
    while (_pos < source.length) {
      if (source[_pos] == '%' && _peek() == '}') {
        _advance(2);
        break;
      }
      if (source[_pos] == '\n') {
        _line++;
        _col = 1;
      } else {
        _col++;
      }
      _pos++;
    }
  }

  String _readString() {
    _advance(1); // skip "
    final start = _pos;
    while (_pos < source.length) {
      if (source[_pos] == '\\' && _peek() == '"') {
        _advance(2);
        continue;
      }
      if (source[_pos] == '"') {
        final result = source.substring(start, _pos).replaceAll('\\"', '"');
        _advance(1);
        return result;
      }
      if (source[_pos] == '\n') {
        _line++;
        _col = 1;
      } else {
        _col++;
      }
      _pos++;
    }
    return source.substring(start);
  }

  String _readCommand() {
    _advance(1); // skip \
    final start = _pos;
    while (_pos < source.length && _isAlpha(source[_pos])) {
      _advance(1);
    }
    return source.substring(start, _pos);
  }

  bool _isSymbolPrefix(String char) {
    const symbols = '{ } < > ( ) [ ] ~ | = - ^ _';
    return symbols.contains(char) && char != ' ';
  }

  String _readSymbol() {
    final char = source[_pos];
    final peek = _peek();
    if (char == '<' && peek == '<') {
      _advance(2);
      return '<<';
    }
    if (char == '>' && peek == '>') {
      _advance(2);
      return '>>';
    }
    if (char == '-' && (peek == '.' || peek == '>' || peek == '^' || peek == '-')) {
      _advance(2);
      return '$char$peek';
    }
    _advance(1);
    return char;
  }

  String _readWord() {
    final start = _pos;
    while (_pos < source.length) {
      final char = source[_pos];
      if (char == ' ' || char == '\t' || char == '\r' || char == '\n' || char == '%' || char == '"' || char == '\\' || _isSymbolPrefix(char)) {
        break;
      }
      _advance(1);
    }
    return source.substring(start, _pos);
  }

  String? _peek() => (_pos + 1 < source.length) ? source[_pos + 1] : null;

  void _advance(int count) {
    for (var i = 0; i < count; i++) {
      if (_pos < source.length) {
        if (source[_pos] == '\n') {
          _line++;
          _col = 1;
        } else {
          _col++;
        }
        _pos++;
      }
    }
  }

  bool _isAlpha(String? char) {
    if (char == null) return false;
    final code = char.codeUnitAt(0);
    return (code >= 97 && code <= 122) || (code >= 65 && code <= 90);
  }
}
