package hjson.tokenizer;

using StringTools;

class Tokenizer {
    public var text:String;
    public var pos:Int = 0;
    public var length:Int;

    public function new(text:String) {
        this.text = text;
        this.length = text.length;
    }

    public function nextToken():Token {
        skipWhitespaceAndComments();

        if (pos >= length) return new Token(TokenType.EOF, "");

        var c = text.charAt(pos);

        return switch (c) {
            case "{": pos++; new Token(TokenType.LEFT_BRACE, "{");
            case "}": pos++; new Token(TokenType.RIGHT_BRACE, "}");
            case "[": pos++; new Token(TokenType.LEFT_BRACKET, "[");
            case "]": pos++; new Token(TokenType.RIGHT_BRACKET, "]");
            case ":": pos++; new Token(TokenType.COLON, ":");
            case ",": pos++; new Token(TokenType.COMMA, ",");
            case '"': readString();
            case 't', 'f': readBoolean();
            case 'n': readNull();
            default:
                if (isDigit(c) || c == "-") readNumber();
                else readIdentifier();
        }
    }

    private function skipWhitespaceAndComments():Void {
        while (pos < length) {
            var c = text.charAt(pos);
            if (c == " " || c == "\t" || c == "\n" || c == "\r") {
                pos++;
            } else if (c == "#") { 
                // Comentário de linha tipo Hash (#)
                while (pos < length && text.charAt(pos) != "\n") pos++;
            } else if (c == "/" && pos + 1 < length) {
                var next = text.charAt(pos + 1);
                if (next == "/") { 
                    // Comentário de linha (//)
                    while (pos < length && text.charAt(pos) != "\n") pos++;
                } else if (next == "*") { 
                    // Comentário de bloco (/* ... */)
                    pos += 2;
                    while (pos + 1 < length && !(text.charAt(pos) == "*" && text.charAt(pos + 1) == "/")) pos++;
                    pos += 2;
                } else {
                    break;
                }
            } else {
                break;
            }
        }
    }

    private function readString():Token {
        pos++; // Pula aspa inicial
        var buf = new StringBuf();
        
        while (pos < length) {
            var c = text.charAt(pos);
            if (c == '"') {
                pos++; // Pula aspa final
                break;
            }
            if (c == "\\") {
                pos++;
                if (pos >= length) break;
                c = text.charAt(pos);
                switch (c) {
                    case 'n': buf.add("\n");
                    case 'r': buf.add("\r");
                    case 't': buf.add("\t");
                    case '"': buf.add('"');
                    case '\\': buf.add('\\');
                    default: buf.add(c);
                }
            } else {
                buf.add(c);
            }
            pos++;
        }
        return new Token(TokenType.STRING, buf.toString());
    }

    private function readNumber():Token {
        var start = pos;
        while (pos < length && (isDigit(text.charAt(pos)) || text.charAt(pos) == "." || text.charAt(pos) == "-")) pos++;
        return new Token(TokenType.NUMBER, text.substring(start, pos));
    }

    private function readBoolean():Token {
        if (text.substr(pos, 4) == "true") {
            pos += 4;
            return new Token(TokenType.BOOLEAN, "true");
        }
        if (text.substr(pos, 5) == "false") {
            pos += 5;
            return new Token(TokenType.BOOLEAN, "false");
        }
        return readIdentifier();
    }

    private function readNull():Token {
        if (text.substr(pos, 4) == "null") {
            pos += 4;
            return new Token(TokenType.NULL, "null");
        }
        return readIdentifier();
    }

    private function readIdentifier():Token {
        var start = pos;
        var stopChars = "{}[]:,";
        while (pos < length && !isWhitespace(text.charAt(pos)) && stopChars.indexOf(text.charAt(pos)) == -1) pos++;
        return new Token(TokenType.IDENTIFIER, text.substring(start, pos));
    }

    private function isDigit(c:String):Bool {
        return c >= "0" && c <= "9";
    }

    private function isWhitespace(c:String):Bool {
        return c == " " || c == "\n" || c == "\r" || c == "\t";
    }
}
