package hjson.core;

typedef WriteOptions = {
    ?pretty:Bool,
    ?useCommas:Bool,
    ?indentSize:Int,
    ?quoteKeys:Bool
}

typedef ParseOptions = {
    ?allowCommas:Bool,
    ?keepNulls:Bool
}
  
