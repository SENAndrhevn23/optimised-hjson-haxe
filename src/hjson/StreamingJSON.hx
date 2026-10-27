package hjson;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.Input;
#if sys
import sys.io.File;
#end

/**
 * Buffered streaming reader for strict JSON files.
 *
 * Unlike HJSON.parse(), this class reads from an Input and does not require a
 * second, full-size String copy of the source file. `parseFile()` still builds
 * the complete result tree, so use `forEachArrayItemFile()` when a large array
 * can be handled one item at a time.
 *
 * This is an RFC-8259 JSON reader. HJSON-only syntax (comments, unquoted keys,
 * and unquoted strings) remains supported by HJSON.parse(), not this class.
 */
class StreamingJSON
{
    public static inline var DEFAULT_BUFFER_SIZE:Int = 4 * 1024 * 1024;
    static inline var MAX_DEPTH:Int = 1024;

    var input:Input;
    var buffer:Bytes;
    var bufferPosition:Int = 0;
    var bufferLength:Int = 0;
    var peekedByte:Int = -2;
    var bufferSize:Int;

    public function new(input:Input, ?bufferSize:Int)
    {
        if (input == null) throw "StreamingJSON requires a non-null Input";
        this.input = input;
        this.bufferSize = bufferSize == null || bufferSize <= 0 ? DEFAULT_BUFFER_SIZE : bufferSize;
        this.buffer = Bytes.alloc(this.bufferSize);
    }

    /** Parse a JSON stream into a normal Haxe object tree. Does not close input. */
    public static function parseInput(input:Input, ?bufferSize:Int):Dynamic
    {
        var parser = new StreamingJSON(input, bufferSize);
        var result = parser.parseValue(0);
        parser.skipWhitespace();
        if (parser.peekByte() >= 0) throw "Unexpected trailing data after JSON value";
        return result;
    }

    #if sys
    /** Read a JSON file without first loading its entire contents into a String. */
    public static function parseFile(path:String, ?bufferSize:Int):Dynamic
    {
        var input:Input = File.read(path, false);
        try
        {
            var result = parseInput(input, bufferSize);
            input.close();
            return result;
        }
        catch (e:Dynamic)
        {
            try { input.close(); } catch (_:Dynamic) {}
            throw e;
        }
    }

    /**
     * Stream an object-key path ending in an array and invoke `callback` once
     * for every array item. Only the current item is materialized at a time;
     * all values outside the requested path are skipped without allocation.
     *
     * Example: forEachArrayItemFile("chart.json", ["song", "notes"], fn)
     * handles one Psych section object at a time.
     */
    public static function forEachArrayItemFile(path:String, objectPath:Array<String>, callback:Dynamic->Void, ?bufferSize:Int):Void
    {
        var input:Input = File.read(path, false);
        try
        {
            forEachArrayItemInput(input, objectPath, callback, bufferSize);
            input.close();
        }
        catch (e:Dynamic)
        {
            try { input.close(); } catch (_:Dynamic) {}
            throw e;
        }
    }
    #end

    /** Same as forEachArrayItemFile, but leaves input ownership to the caller. */
    public static function forEachArrayItemInput(input:Input, objectPath:Array<String>, callback:Dynamic->Void, ?bufferSize:Int):Void
    {
        if (objectPath == null || objectPath.length == 0)
            throw "StreamingJSON requires a non-empty object path";
        if (callback == null) throw "StreamingJSON requires a callback";

        var parser = new StreamingJSON(input, bufferSize);
        parser.streamObjectPath(objectPath, 0, callback, 0);
        parser.skipWhitespace();
        if (parser.peekByte() >= 0) throw "Unexpected trailing data after JSON value";
    }

    #if sys
    /**
     * Like forEachArrayItemFile(), but each streamed item must be an object and
     * only the listed fields are parsed. Other fields are skipped directly from
     * the byte stream. This is useful for large records when callers need only
     * a few runtime fields.
     */
    public static function forEachObjectInArrayFile(path:String, objectPath:Array<String>, fieldsToKeep:Array<String>, callback:Dynamic->Void, ?bufferSize:Int):Void
    {
        var input:Input = File.read(path, false);
        try
        {
            forEachObjectInArrayInput(input, objectPath, fieldsToKeep, callback, bufferSize);
            input.close();
        }
        catch (e:Dynamic)
        {
            try { input.close(); } catch (_:Dynamic) {}
            throw e;
        }
    }
    #end

    /** Same as forEachObjectInArrayFile, but leaves input ownership to the caller. */
    public static function forEachObjectInArrayInput(input:Input, objectPath:Array<String>, fieldsToKeep:Array<String>, callback:Dynamic->Void, ?bufferSize:Int):Void
    {
        if (objectPath == null || objectPath.length == 0)
            throw "StreamingJSON requires a non-empty object path";
        if (fieldsToKeep == null) throw "StreamingJSON requires an explicit object field allowlist";
        if (callback == null) throw "StreamingJSON requires a callback";

        var parser = new StreamingJSON(input, bufferSize);
        parser.streamObjectPath(objectPath, 0, callback, 0, fieldsToKeep);
        parser.skipWhitespace();
        if (parser.peekByte() >= 0) throw "Unexpected trailing data after JSON value";
    }

    function streamObjectPath(path:Array<String>, pathIndex:Int, callback:Dynamic->Void, depth:Int, ?fieldsToKeep:Array<String>):Void
    {
        checkDepth(depth);
        skipWhitespace();
        expectByte(123); // {
        skipWhitespace();
        if (peekByte() == 125) throw 'JSON path component "${path[pathIndex]}" was not found';

        var found:Bool = false;
        while (true)
        {
            skipWhitespace();
            if (peekByte() != 34) throw "Expected a quoted JSON object key while locating stream path";
            var key:String = parseString();
            skipWhitespace();
            expectByte(58); // :

            if (key == path[pathIndex])
            {
                if (found) throw 'Duplicate JSON path key "${key}" is ambiguous';
                found = true;
                if (pathIndex == path.length - 1)
                {
                    if (fieldsToKeep == null) streamTargetArray(callback, depth + 1);
                    else streamTargetObjectArray(callback, depth + 1, fieldsToKeep);
                }
                else
                    streamObjectPath(path, pathIndex + 1, callback, depth + 1, fieldsToKeep);
            }
            else
            {
                skipValueRaw();
            }

            skipWhitespace();
            var separator:Int = readByte();
            if (separator == 125) break; // }
            if (separator != 44) throw "Expected ',' or '}' in JSON object";
        }
        if (!found) throw 'JSON path component "${path[pathIndex]}" was not found';
    }

    function streamTargetArray(callback:Dynamic->Void, depth:Int):Void
    {
        checkDepth(depth);
        skipWhitespace();
        expectByte(91); // [
        skipWhitespace();
        if (peekByte() == 93) { readByte(); return; }

        while (true)
        {
            var item:Dynamic = parseValue(depth + 1);
            callback(item);
            skipWhitespace();
            var separator:Int = readByte();
            if (separator == 93) break; // ]
            if (separator != 44) throw "Expected ',' or ']' in streamed JSON array";
        }
    }

    function streamTargetObjectArray(callback:Dynamic->Void, depth:Int, fieldsToKeep:Array<String>):Void
    {
        checkDepth(depth);
        skipWhitespace();
        expectByte(91); // [
        skipWhitespace();
        if (peekByte() == 93) { readByte(); return; }

        while (true)
        {
            if (peekByte() != 123) throw "Expected an object item in streamed JSON array";
            var item:Dynamic = parseObjectFiltered(depth + 1, fieldsToKeep);
            callback(item);
            skipWhitespace();
            var separator:Int = readByte();
            if (separator == 93) break; // ]
            if (separator != 44) throw "Expected ',' or ']' in streamed object array";
        }
    }

    function parseObjectFiltered(depth:Int, fieldsToKeep:Array<String>):Dynamic
    {
        checkDepth(depth);
        expectByte(123); // {
        var object:Dynamic = {};
        skipWhitespace();
        if (peekByte() == 125) { readByte(); return object; }

        while (true)
        {
            skipWhitespace();
            if (peekByte() != 34) throw "Expected quoted key in streamed JSON object";
            var key:String = parseString();
            skipWhitespace();
            expectByte(58); // :
            if (fieldsToKeep.indexOf(key) >= 0)
                Reflect.setField(object, key, parseValue(depth + 1));
            else
                skipValueRaw();

            skipWhitespace();
            var separator:Int = readByte();
            if (separator == 125) break; // }
            if (separator != 44) throw "Expected ',' or '}' in streamed JSON object";
            skipWhitespace();
            if (peekByte() == 125) throw "Trailing commas are not valid JSON";
        }
        return object;
    }

    function parseValue(depth:Int):Dynamic
    {
        checkDepth(depth);
        skipWhitespace();
        var c:Int = peekByte();
        if (c < 0) throw "Unexpected end of JSON input";
        return switch (c)
        {
            case 123: parseObject(depth + 1);
            case 91: parseArray(depth + 1);
            case 34: parseString();
            default: parsePrimitive();
        }
    }

    function parseObject(depth:Int):Dynamic
    {
        checkDepth(depth);
        expectByte(123); // {
        var object:Dynamic = {};
        skipWhitespace();
        if (peekByte() == 125) { readByte(); return object; }

        while (true)
        {
            skipWhitespace();
            if (peekByte() != 34) throw "Expected quoted JSON object key";
            var key:String = parseString();
            skipWhitespace();
            expectByte(58); // :
            Reflect.setField(object, key, parseValue(depth + 1));
            skipWhitespace();
            var separator:Int = readByte();
            if (separator == 125) break; // }
            if (separator != 44) throw "Expected ',' or '}' in JSON object";
            skipWhitespace();
            if (peekByte() == 125) throw "Trailing commas are not valid JSON";
        }
        return object;
    }

    function parseArray(depth:Int):Array<Dynamic>
    {
        checkDepth(depth);
        expectByte(91); // [
        var result:Array<Dynamic> = [];
        skipWhitespace();
        if (peekByte() == 93) { readByte(); return result; }

        while (true)
        {
            result.push(parseValue(depth + 1));
            skipWhitespace();
            var separator:Int = readByte();
            if (separator == 93) break; // ]
            if (separator != 44) throw "Expected ',' or ']' in JSON array";
            skipWhitespace();
            if (peekByte() == 93) throw "Trailing commas are not valid JSON";
        }
        return result;
    }

    function parseString():String
    {
        var bytes = new BytesBuffer();
        var first:Int = readByte();
        if (first != 34) throw "Expected JSON string";
        bytes.addByte(first);
        var escaped:Bool = false;
        while (true)
        {
            var c:Int = readByte();
            if (c < 0) throw "Unterminated JSON string";
            bytes.addByte(c);
            if (escaped) escaped = false;
            else if (c == 92) escaped = true; // backslash
            else if (c == 34) break; // closing quote
            else if (c < 32) throw "Unescaped control byte in JSON string";
        }
        var raw:Bytes = bytes.getBytes();
        return cast haxe.Json.parse(raw.getString(0, raw.length));
    }

    /**
     * Parse primitive values without allocating a temporary String for every
     * numeric token. Large FNF charts are dominated by small numeric note
     * fields (time, lane and sustain length), so this is the hot path for the
     * streaming chart loader.
     */
    function parsePrimitive():Dynamic
    {
        var c:Int = peekByte();
        switch (c)
        {
            case 116: readLiteral("true"); return true;  // t
            case 102: readLiteral("false"); return false; // f
            case 110: readLiteral("null"); return null;   // n
            default: return parseNumberFast();
        }
    }

    inline function readLiteral(expected:String):Void
    {
        for (i in 0...expected.length)
        {
            var actual:Int = readByte();
            if (actual != expected.charCodeAt(i))
                throw 'Invalid JSON literal; expected "$expected"';
        }
    }

    /** Strict JSON number parsing with no per-number StringBuf/String allocation. */
    function parseNumberFast():Dynamic
    {
        var negative:Bool = false;
        if (peekByte() == 45) // -
        {
            readByte();
            negative = true;
        }

        var integerPart:Float = 0.0;
        var first:Int = peekByte();
        if (first == 48) // zero cannot be followed by another integer digit
        {
            readByte();
            if (isDigitChar(peekByte())) throw "Leading zero in JSON number";
        }
        else if (isNonZeroDigit(first))
        {
            while (isDigitChar(peekByte()))
            {
                integerPart = integerPart * 10.0 + (readByte() - 48);
            }
        }
        else
            throw "Expected JSON number";

        // The zero branch consumed its first digit above; the non-zero branch
        // consumed every integer digit in its loop.
        if (first == 48) integerPart = 0.0;
        var value:Float = integerPart;
        var floating:Bool = false;

        if (peekByte() == 46) // .
        {
            floating = true;
            readByte();
            var fractionDigits:Int = 0;
            var place:Float = 0.1;
            while (isDigitChar(peekByte()))
            {
                value += (readByte() - 48) * place;
                place *= 0.1;
                fractionDigits++;
            }
            if (fractionDigits == 0) throw "Missing fraction digits in JSON number";
        }

        if (peekByte() == 101 || peekByte() == 69) // e/E
        {
            floating = true;
            readByte();
            var exponentNegative:Bool = false;
            if (peekByte() == 43 || peekByte() == 45) // + or -
            {
                exponentNegative = peekByte() == 45;
                readByte();
            }
            var exponentDigits:Int = 0;
            var exponent:Float = 0.0;
            while (isDigitChar(peekByte()))
            {
                // Cap the accumulated exponent to avoid numeric overflow while
                // still consuming and validating the complete exponent token.
                exponent = Math.min(10000.0, exponent * 10.0 + (readByte() - 48));
                exponentDigits++;
            }
            if (exponentDigits == 0) throw "Missing exponent digits in JSON number";
            if (exponentNegative) exponent = -exponent;
            if (value != 0.0) value *= Math.pow(10.0, exponent);
        }

        if (negative) value = -value;

        // Match the common Haxe JSON representation: small integral values are
        // Ints, while decimal/exponent and out-of-range values remain Floats.
        if (!floating && value >= -2147483648.0 && value <= 2147483647.0)
            return Std.int(value);
        return value;
    }

    function parseNumberToken(value:String):Dynamic
    {
        var length:Int = value.length;
        if (length == 0) throw "Expected JSON value";
        var i:Int = 0;
        if (value.charAt(i) == "-") i++;
        if (i >= length) throw 'Invalid JSON number "$value"';

        if (value.charAt(i) == "0")
        {
            i++;
            if (i < length && isDigitChar(value.charCodeAt(i))) throw 'Leading zero in JSON number "$value"';
        }
        else if (isNonZeroDigit(value.charCodeAt(i)))
        {
            while (i < length && isDigitChar(value.charCodeAt(i))) i++;
        }
        else throw 'Invalid JSON number "$value"';

        var floating:Bool = false;
        if (i < length && value.charAt(i) == ".")
        {
            floating = true;
            i++;
            var start:Int = i;
            while (i < length && isDigitChar(value.charCodeAt(i))) i++;
            if (i == start) throw 'Invalid fraction in JSON number "$value"';
        }
        if (i < length && (value.charAt(i) == "e" || value.charAt(i) == "E"))
        {
            floating = true;
            i++;
            if (i < length && (value.charAt(i) == "+" || value.charAt(i) == "-")) i++;
            var start:Int = i;
            while (i < length && isDigitChar(value.charCodeAt(i))) i++;
            if (i == start) throw 'Invalid exponent in JSON number "$value"';
        }
        if (i != length) throw 'Invalid trailing characters in JSON number "$value"';
        if (floating) return Std.parseFloat(value);
        var integer:Null<Int> = Std.parseInt(value);
        return integer == null ? Std.parseFloat(value) : integer;
    }

    /** Skip a JSON value without constructing its arrays, objects, or strings. */
    function skipValueRaw():Void
    {
        skipWhitespace();
        var first:Int = peekByte();
        if (first < 0) throw "Unexpected end while skipping JSON value";
        if (first == 34)
        {
            readByte();
            var escaped:Bool = false;
            while (true)
            {
                var c:Int = readByte();
                if (c < 0) throw "Unterminated string while skipping JSON value";
                if (escaped) escaped = false;
                else if (c == 92) escaped = true;
                else if (c == 34) break;
                else if (c < 32) throw "Unescaped control byte in JSON string";
            }
            return;
        }
        if (first == 123 || first == 91)
        {
            var depth:Int = 0;
            var inString:Bool = false;
            var escaped:Bool = false;
            var stack:Array<Int> = [];
            while (true)
            {
                var c:Int = readByte();
                if (c < 0) throw "Unexpected end while skipping JSON container";
                if (inString)
                {
                    if (escaped) escaped = false;
                    else if (c == 92) escaped = true;
                    else if (c == 34) inString = false;
                    else if (c < 32) throw "Unescaped control byte in JSON string";
                    continue;
                }
                if (c == 34) inString = true;
                else if (c == 123 || c == 91)
                {
                    stack.push(c);
                    depth++;
                }
                else if (c == 125 || c == 93)
                {
                    if (depth == 0) throw "Unexpected closing delimiter while skipping JSON container";
                    var open:Null<Int> = stack.pop();
                    if (open == null) throw "Unexpected closing delimiter while skipping JSON container";
                    if ((open == 123 && c != 125) || (open == 91 && c != 93))
                        throw "Mismatched JSON container delimiter";
                    depth--;
                    if (depth == 0) break;
                }
            }
            return;
        }
        while (true)
        {
            var c:Int = peekByte();
            if (c < 0 || c == 44 || c == 93 || c == 125 || isWhitespace(c)) break;
            readByte();
        }
    }

    function skipWhitespace():Void
    {
        while (isWhitespace(peekByte())) readByte();
    }

    inline function isWhitespace(c:Int):Bool
        return c == 32 || c == 9 || c == 10 || c == 13;

    function expectByte(expected:Int):Void
    {
        var actual:Int = readByte();
        if (actual != expected)
            throw 'Expected "${String.fromCharCode(expected)}" in JSON, got "${actual < 0 ? "EOF" : String.fromCharCode(actual)}"';
    }

    function peekByte():Int
    {
        if (peekedByte == -2) peekedByte = readByteFromBuffer();
        return peekedByte;
    }

    function readByte():Int
    {
        if (peekedByte != -2)
        {
            var result:Int = peekedByte;
            peekedByte = -2;
            return result;
        }
        return readByteFromBuffer();
    }

    function readByteFromBuffer():Int
    {
        if (bufferPosition >= bufferLength)
        {
            try
            {
                bufferLength = input.readBytes(buffer, 0, buffer.length);
            }
            catch (e:Dynamic)
            {
                if (Std.isOfType(e, haxe.io.Eof)) bufferLength = 0;
                else throw e;
            }
            bufferPosition = 0;
            if (bufferLength <= 0) return -1;
        }
        return buffer.get(bufferPosition++);
    }

    inline function checkDepth(depth:Int):Void
    {
        if (depth > MAX_DEPTH) throw 'JSON nesting exceeds maximum depth $MAX_DEPTH';
    }

    inline function isDigitChar(c:Int):Bool return c >= 48 && c <= 57;
    inline function isNonZeroDigit(c:Int):Bool return c >= 49 && c <= 57;
}
