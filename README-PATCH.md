# Optimised HJSON Haxe — buffered JSON streaming patch

This overlay adds `src/hjson/StreamingJSON.hx`, a new opt-in reader for large strict JSON files. The reader uses a 4 MiB default buffer and a no-temporary-string fast path for numeric tokens. Existing `HJSON.parse()` and `HJSON.parseFile()` are not replaced, so HJSON comments, unquoted keys, and unquoted strings retain their current behavior.

## APIs added

- `StreamingJSON.parseFile(path)` — reads from a buffered input stream instead of first allocating a full-file string, but still creates the complete Haxe tree.
- `StreamingJSON.forEachArrayItemFile(path, objectPath, callback)` — visits an array item at a time; unrelated fields are scanned without building their values.
- `StreamingJSON.forEachObjectInArrayFile(path, objectPath, fieldsToKeep, callback)` — streams an array of objects and materializes only selected fields from each item. This is the variant H-Slice uses for streamed chart sections.

`objectPath` is an array of object keys, e.g. `["song", "notes"]`; it is not general JSONPath syntax. The callback should not retain every item, or the application will recreate the memory pressure streaming is intended to avoid.

## Apply / test

Overlay `src/`, `tests/`, and `docs/` into the repository. Append the usage section in `docs/STREAMING-JSON.md` to the main README if desired. Then run, with Haxe installed:

```sh
haxe -cp src -cp tests -main StreamingJSONSmoke --interp
```

The code in this patch has been source-reviewed but could not be compiled in this environment because Haxe is not installed. Run the smoke test before committing/pushing.

## Performance scope

The fast numeric path reduces parser allocations, but this is not zero-copy parsing and it does not make 1.1 GB files instant. `parseFile()` still materializes a complete object tree; the callback APIs are preferable for large arrays. In H-Slice, generated note-head and sustain records are still retained for gameplay, which can exhaust RAM for charts containing hundreds of millions of notes.
