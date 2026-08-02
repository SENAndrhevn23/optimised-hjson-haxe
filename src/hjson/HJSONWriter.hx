package hjson;

import EReg;
import Std;
import Reflect;
import hjson.core.HJSONOptions.WriteOptions;

using StringTools;

class HJSONWriter {

    public static function stringify(v:Dynamic, ?options:WriteOptions):String {
        var opts:WriteOptions = options != null ? options : {};
        if (opts.pretty == null) opts.pretty = true;
        if (opts.useCommas == null) opts.useCommas = false;
        if (opts.indentSize == null) opts.indentSize = 2;
        if (opts.quoteKeys == null) opts.quoteKeys = false;

        return writeValue(v, 0, opts);
    }

    static function writeValue(v:Dynamic, indent:Int, opts:WriteOptions):String {
        if (v == null) return "null";

        if (Std.isOfType(v, String)) return escapeString(cast v);
        if (Std.isOfType(v, Int) || Std.isOfType(v, Float)) return Std.string(v);
        if (Std.isOfType(v, Bool)) return v ? "true" : "false";
        if (Std.isOfType(v, Array)) return writeArray(cast v, indent, opts);

        return writeObject(v, indent, opts);
    }

    static function writeObject(o:Dynamic, indent:Int, opts:WriteOptions):String {
        var fields:Array<String> = Reflect.fields(o);
        var result = "{";

        if (opts.pretty && fields.length > 0) result += "\n";

        for (i in 0...fields.length) {
            var key = fields[i];
            var value = Reflect.field(o, key);

            if (opts.pretty) result += StringTools.lpad("", " ", (indent + 1) * opts.indentSize);
            
            var formattedKey = opts.quoteKeys ? escapeString(key) : escapeKey(key);
            result += formattedKey + ": " + writeValue(value, indent + 1, opts);

            if (i < fields.length - 1 && opts.useCommas) result += ",";
            if (opts.pretty) result += "\n";
        }

        if (opts.pretty && fields.length > 0) result += StringTools.lpad("", " ", indent * opts.indentSize);
        result += "}";
        return result;
    }

    static function writeArray(a:Array<Dynamic>, indent:Int, opts:WriteOptions):String {
        var result = "[";

        if (opts.pretty && a.length > 0) result += "\n";

        for (i in 0...a.length) {
            var value = a[i];
            if (opts.pretty) result += StringTools.lpad("", " ", (indent + 1) * opts.indentSize);
            result += writeValue(value, indent + 1, opts);

            if (i < a.length - 1 && opts.useCommas) result += ",";
            if (opts.pretty) result += "\n";
        }

        if (opts.pretty && a.length > 0) result += StringTools.lpad("", " ", indent * opts.indentSize);
        result += "]";
        return result;
    }

    static function escapeString(s:String):String {
        var r = new EReg("\"", "g");
        return "\"" + r.replace(s, "\\\"") + "\"";
    }

    static function escapeKey(s:String):String {
        var needsQuote = s.indexOf(" ") != -1 || s.indexOf("\"") != -1 || s.indexOf("\n") != -1;
        if (needsQuote) return escapeString(s);
        return s;
    }
}
