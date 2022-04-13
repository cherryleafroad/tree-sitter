#
# Rust's emscripten target is kinda broken and needs additional help to compile properly
# You need to install Rust target `wasm32-unknown-emscripten` for this
#

param(
    [switch]$release
)

$CUR_DIR = Split-Path -Path $PSScriptRoot -Parent | ForEach-Object { $_ -replace "\\","/" } 
$LIB_DIR = "$CUR_DIR/lib"
$WEB_DIR = "$LIB_DIR/binding_web"


$OUT_DIR = "$CUR_DIR/build/"
if (!(test-path $OUT_DIR))
{
    New-Item -ItemType "directory" -Path $OUT_DIR > $null
} else {
    Remove-Item "$OUT_DIR/*"
}

# set up debug vs release flags
$EMCC_FLAGS_EXTRA = "-O3"
if (-Not $release) {
    $EMCC_FLAGS_EXTRA = "-s ASSERTIONS=1 -s SAFE_HEAP=1 -O0"
}

# relocation model is required to stop the WASM linking errors
# relocation R_WASM_TABLE_INDEX_SLEB cannot be used against symbol
# we also need the obj files for compilation in order to avoid the error
$Env:RUSTFLAGS ="--emit=obj -C relocation-model=pic"

$outdir = ""
# don't link as the command to link is borked on Rust
if ($release) {
    cargo build -p tree-sitter-highlight --target=wasm32-unknown-emscripten --release
    $outdir = "release"
} else { 
    cargo build -p tree-sitter-highlight --target=wasm32-unknown-emscripten
    $outdir = "debug"
}

$o_files = Get-ChildItem -Path "target/wasm32-unknown-emscripten/$outdir/deps/*" -Filter "*.o" | Join-String -Property FullName -DoubleQuote -Separator ' ' | ForEach-Object { $_ -replace "\\","/" }
$EMCC = @"
  emcc
  --no-entry
  -s ERROR_ON_UNDEFINED_SYMBOLS=0
  -s WASM=1
  -s TOTAL_MEMORY=33554432
  -s ALLOW_MEMORY_GROWTH=1
  -s MAIN_MODULE=2
  -s NO_FILESYSTEM=1
  -s NODEJS_CATCH_EXIT=0
  -s NODEJS_CATCH_REJECTION=0
  -s EXPORTED_FUNCTIONS=@$WEB_DIR/exports-highlight.json
  $EMCC_FLAGS_EXTRA
  --js-library $WEB_DIR/imports.js
  --pre-js $WEB_DIR/prefix.js
  --post-js $WEB_DIR/binding.js
  --post-js $WEB_DIR/suffix.js
  $o_files
  -o $OUT_DIR/tree-sitter.wasm
"@ | foreach-object { $_ -replace [Environment]::NewLine, "" }

#$Env:EMCC_CFLAGS = $EMCC_CFLAGS

Invoke-Expression $EMCC

#Move-Item -Path "$CUR_DIR/target/wasm32-unknown-emscripten/$outdir/*.wasm" -Destination "$OUT_DIR"
#Move-Item -Path "$CUR_DIR/target/wasm32-unknown-emscripten/$outdir/deps/*.map" -Destination "$OUT_DIR"
