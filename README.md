# hjson4haxe
![logo](https://github.com/anthonydudeh/hjson-haxe/blob/main/hlogo.png)

A native Haxe library for reading, parsing, and writing HJSON (Human JSON) files with comment support and cross-platform flexibility.

![License](https://img.shields.io/badge/license-MIT-green)
![Haxe Version](https://img.shields.io/badge/haxe-4.3.6%2B-orange)

## Features

- **HJSON Parsing & Stringify**: Parse HJSON strings into native Haxe Anonymous Objects `{}`.
- **Comment Support**: Automatically skips line (`//`, `#`) and block (`/* */`) comments.
- **Flexible Options**: Custom indentation sizes, optional quote formatting, and comma toggles.
- **Compile-Time Macros**: Parse and validate HJSON files directly at compile time via `HJSONMacro`.
- **Cross-Platform**: Works across all Haxe targets, including Sys targets (C++, HashLink, Neko) and Web/JS targets.

## Installation

Via Haxelib:
```bash
haxelib install hjson4haxe
```

Or directly from GitHub (latest updates):
```bash
haxelib git hjson4haxe https://github.com/anthonydudeh/hjson-haxe
```

## Usage

**1. Basic Parsing & Stringify**
```haxe
import hjson.HJSON;

class Main {
    static function main() {
        var hjsonText = '
        {
            # Camila profile
            name: Camila Almeida
            age: 27
            skills: [
                Communication
            ]
        }';

        // Parse HJSON into a standard Haxe object
        var data = HJSON.parse(hjsonText);
        trace(data.name);
        trace(data.skills[0]);

        // Stringify back to HJSON
        var output = HJSON.stringify(data, { pretty: true, indentSize: 2 });
        trace(output);
    }
}
```

**2. Reading and Saving Files (Sys targets)**
```Haxe
import hjson.HJSON;

class FileExample {
    static function run() {
        // Parse directly from a .hjson file
        var config = HJSON.parseFile("haxelib.hjson");
        
        // Modify and save back to file
        config.version = "1.0.4";
        HJSON.saveToFile(config, "config.hjson", { pretty: true, quoteKeys: false });
    }
}
```

**3. Compile-Time Macro Parsing**
*Load and validate HJSON files at compile time without any runtime I/O overhead:*
```haxe
import hjson.macro.HJSONMacro;

class MacroExample {
    static function main() {
        // File is embedded and converted to Haxe objects at compile time
        var buildConfig = HJSONMacro.parseFile("build.hjson");
        trace(buildConfig.title);
    }
}
```
---

Read [CHANGELOG.md](https://github.com/anthonydudeh/hjson-haxe/blob/main/CHANGELOG.md)
for the detailed version fixes and changes!
