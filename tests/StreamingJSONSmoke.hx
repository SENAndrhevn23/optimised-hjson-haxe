import hjson.StreamingJSON;

class StreamingJSONSmoke
{
    static function main():Void
    {
        var fixture = "tests/fixtures/streaming.json";
        var tree:Dynamic = StreamingJSON.parseFile(fixture);
        if (tree.engine != "H-Slice+ADR") throw "parseFile() failed to read root metadata";
        if (tree.song.notes.length != 2) throw "parseFile() failed to parse nested array";
        var numbers:Dynamic = tree.numericCases;
        if (numbers[0] != 0 || numbers[1] != -1 || numbers[2] != 2147483647)
            throw "fast integer parsing failed on small/signed integers";
        if (numbers[3] != 2147483648.0 || numbers[4] != -2147483648)
            throw "fast integer parsing failed on Int boundary values";
        if (Math.abs(numbers[5] - 12.5) > 0.0000001 || Math.abs(numbers[6] + 0.125) > 0.0000001)
            throw "fast decimal parsing failed";
        if (Math.abs(numbers[7] - 100.0) > 0.0000001 || Math.abs(numbers[8] - 0.055) > 0.0000001 || numbers[9] != 0)
            throw "fast exponent parsing failed";

        var count:Int = 0;
        var noteTotal:Int = 0;
        StreamingJSON.forEachArrayItemFile(fixture, ["song", "notes"], function(section:Dynamic):Void {
            count++;
            if (section.sectionNotes != null) noteTotal += section.sectionNotes.length;
        });
        if (count != 2) throw 'Expected 2 streamed sections, got $count';
        if (noteTotal != 3) throw 'Expected 3 notes across streamed sections, got $noteTotal';

        var filteredCount:Int = 0;
        var filteredNotes:Int = 0;
        StreamingJSON.forEachObjectInArrayFile(fixture, ["song", "notes"], ["mustHitSection", "sectionNotes"], function(section:Dynamic):Void {
            filteredCount++;
            if (section.sectionNotes != null) filteredNotes += section.sectionNotes.length;
            if (Reflect.hasField(section, "bpm")) throw "Filtered parser retained a field outside the allowlist";
        });
        if (filteredCount != 2 || filteredNotes != 3)
            throw 'Expected 2 filtered sections / 3 notes; got $filteredCount / $filteredNotes';
        trace("StreamingJSON smoke test passed");
    }
}
