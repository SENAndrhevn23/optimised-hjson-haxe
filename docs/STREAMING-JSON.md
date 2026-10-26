# Streaming JSON API

`hjson.StreamingJSON` is an additional strict-JSON API designed for large `.json` files. Existing `HJSON.parse()` and `HJSON.parseFile()` keep their existing HJSON syntax and behavior.

## Parse a file without a full source string

```haxe
import hjson.StreamingJSON;

var document:Dynamic = StreamingJSON.parseFile("metadata.json");
trace(document.version);
```

This removes the extra full-file `String` allocation, but `parseFile()` still builds the complete Haxe object tree. For very large arrays, use the callback API.

## Visit an array one item at a time

```haxe
import hjson.StreamingJSON;

StreamingJSON.forEachArrayItemFile("chart.json", ["song", "notes"], function(section:Dynamic) {
    // Process one section and then let it be reclaimed.
    trace(section.mustHitSection);
});
```

`objectPath` is an array of object keys, not JSONPath syntax. It must end at an array value. For charts stored without a `song` wrapper, use `["notes"]` instead of `["song", "notes"]`.

The parser constructs only one outer-array item at a time; values outside the requested path are skipped without creating dynamic arrays/objects. The callback should avoid retaining every item, otherwise memory use will grow with the file.

## Keep only selected fields from each item

```haxe
StreamingJSON.forEachObjectInArrayFile(
    "chart.json",
    ["song", "notes"],
    ["sectionNotes", "mustHitSection", "gfSection", "altAnim", "changeBPM", "bpm"],
    function(section:Dynamic) {
        // Only the listed section fields are materialized.
    }
);
```

This variant requires each array item to be an object. Values of non-allowlisted fields are scanned and discarded from the input stream, without allocating their arrays/objects/strings.

## Important limits

- `StreamingJSON` accepts strict JSON. HJSON comments, unquoted keys, and unquoted strings remain for `HJSON.parse()`.
- A callback can make ingestion incremental, but an individual array item is materialized as one object. For a single enormous item, split the file into smaller array items or stream a deeper array.
- `parseFile()` still returns the full document tree and therefore does not make very large documents constant-memory.
- Streaming eliminates the duplicate source `String`; it does not eliminate the cost of reading bytes, parsing values, allocating retained gameplay objects, or generating sustain notes. A 1.1 GB file cannot be promised to load instantly.

## Smoke test

From the repository root, when Haxe is installed:

```sh
haxe -cp src -cp tests -main StreamingJSONSmoke --interp
```
