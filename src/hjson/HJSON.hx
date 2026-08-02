package hjson;

import hjson.core.HjsonOptions;

#if sys
import sys.io.File;
#end

class HJSON {
    
    public static function parse(text:String, ?options:ParseOptions):Dynamic {
        return HJSONParser.parse(text, options);
    }

    #if sys
    public static function parseFile(path:String, ?options:ParseOptions):Dynamic {
        var content = File.getContent(path);
        return parse(content, options);
    }

    public static function saveToFile(value:Dynamic, path:String, ?options:WriteOptions):Void {
        var content = stringify(value, options);
        File.saveContent(path, content);
    }
    #end

    public static function stringify(value:Dynamic, ?options:WriteOptions):String {
        return HJSONWriter.stringify(value, options);
    }
}
