import hjson.HJSON;
import hjson.macro.HJSONMacro;

class Test {
    static function main() {
        trace("--- 1. Testing String Parse ---");
        var hjsonStr = '{
            // Test comment
            name: Haxe Lib
            version: "1.0.4"
            features: [
                macros
                comments
            ]
        }';

        var obj = HJSON.parse(hjsonStr);
        trace("Name: " + obj.name);
        trace("Version: " + obj.version);

        trace("\n--- 2. Testing Stringify ---");
        var output = HJSON.stringify(obj, { pretty: true, indentSize: 2 });
        trace("Result:\n" + output);

        #if sys
        trace("\n--- 3. Testing File Save and Parse ---");
        HJSON.saveToFile(obj, "test_output.hjson");
        var loaded = HJSON.parseFile("test_output.hjson");
        trace("File reloaded successfully: " + loaded.name);
        #end
    }
}

