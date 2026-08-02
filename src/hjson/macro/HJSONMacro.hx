package hjson.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import sys.io.File;

class HjsonMacro {
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
            Context.error('Erro ao compilar arquivo HJSON ($path): $e', Context.currentPos());
            return macro null;
        }
    }
}
#end
  
