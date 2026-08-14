package hjson.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import sys.io.File;
#end

class HJSONMacro {
    /**
     * Reads and parses an HJSON file at compile time.
     * E.g. var config = HJSONMacro.parseFile("config.hjson");
     */
    public static macro function parseFile(path:String):Expr {
        try {
            var content = File.getContent(path);
            var parsedData = hjson.HJSONParser.parse(content);
            return Context.makeExpr(parsedData, Context.currentPos());
        } catch (e:Dynamic) {
            Context.error('Error while compiling HJSON: ' + e, Context.currentPos());
            return macro null;
        }
    }
}
