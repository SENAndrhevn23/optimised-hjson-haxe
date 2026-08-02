package hjson;

import hjson.tokenizer.*;
import hjson.core.HJSONOptions.ParseOptions;

class HJSONParser {
    public var tokenizer:Tokenizer;
    public var current:Token;
    public var options:ParseOptions;

    public function new(text:String, ?options:ParseOptions) {
        this.options = options != null ? options : {};
        tokenizer = new Tokenizer(text);
        current = tokenizer.nextToken();
    }

    public static function parse(text:String, ?options:ParseOptions):Dynamic {
        return (new HJSONParser(text, options)).parseValue();
    }

    function parseValue():Dynamic {
        return switch (current.type) {
            case TokenType.LEFT_BRACE: parseObject();
            case TokenType.LEFT_BRACKET: parseArray();
            case TokenType.STRING:
                var v = current.value;
                advance();
                v;
            case TokenType.NUMBER:
                var n = Std.parseFloat(current.value);
                advance();
                n;
            case TokenType.BOOLEAN:
                var b = current.value == "true";
                advance();
                b;
            case TokenType.NULL:
                advance();
                null;
            case TokenType.IDENTIFIER:
                var id = current.value;
                advance();
                id;
            default: null;
        }
    }

    function parseObject():Dynamic {
        advance(); // Skip {
        var obj:Dynamic = {};

        while (current.type != TokenType.RIGHT_BRACE && current.type != TokenType.EOF) {
            var key:String = "";

            if (current.type == TokenType.STRING || current.type == TokenType.IDENTIFIER) {
                key = current.value;
                advance();
            }

            if (current.type == TokenType.COLON) advance();

            var value = parseValue();
            if (key != "") {
                Reflect.setField(obj, key, value);
            }

            // Vírgulas são totalmente opcionais no HJSON
            if (current.type == TokenType.COMMA) advance();
        }

        if (current.type == TokenType.RIGHT_BRACE) advance();
        return obj;
    }

    function parseArray():Dynamic {
        advance(); // Skip [
        var arr:Array<Dynamic> = [];

        while (current.type != TokenType.RIGHT_BRACKET && current.type != TokenType.EOF) {
            arr.push(parseValue());
            if (current.type == TokenType.COMMA) advance();
        }

        if (current.type == TokenType.RIGHT_BRACKET) advance();
        return arr;
    }

    function advance():Void {
        current = tokenizer.nextToken();
    }
}
