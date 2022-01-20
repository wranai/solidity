#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
SOLJSON_JS="$1"
SOLJSON_WASM="$2"
SOLJSON_WASM_SIZE=$(wc -c "${SOLJSON_WASM}" | cut -d ' ' -f 1)
OUTPUT="$3"

(( $# == 3 )) || { >&2 echo "Usage: $0 soljson.js soljson.wasm packed_soljson.js"; exit 1; }

# If this changes in an emscripten update, it's probably nothing to worry about,
# but we should double-check when it happens.
[ "$(head -c 5 "${SOLJSON_JS}")" == "null;" ] || { >&2 echo 'Expected soljson.js to start with "null;"'; exit 1; }

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

lz4c --no-frame-crc --best --favor-decSpeed "${SOLJSON_WASM}" - | tail -c +8 > "${TMPDIR}/soljson.wasm.lz4"
SOLJSON_WASM_LZ4_SIZE=$(wc -c "${TMPDIR}/soljson.wasm.lz4" | cut -d ' ' -f 1)

sed -e "s/<PAGE_COUNT>/$(((SOLJSON_WASM_SIZE + SOLJSON_WASM_LZ4_SIZE + 65535) >> 16))/" "${SCRIPT_DIR}/lz4-block-codec.wat" > "${TMPDIR}/lz4-block-codec.wat"
wat2wasm "${TMPDIR}/lz4-block-codec.wat" -o "${TMPDIR}/lz4-block-codec.wasm"
wasm-opt "${TMPDIR}/lz4-block-codec.wasm" -O4 -o "${TMPDIR}/lz4-block-codec.wasm"

echo "Packing $SOLJSON_JS and $SOLJSON_WASM to $OUTPUT."
(
	echo -n 'var Module = Module || {}; Module["wasmBinary"] = '
	cat "${SCRIPT_DIR}/wasm_unpack.js"
	echo -n '("'
	base64 -w 0 "${TMPDIR}/lz4-block-codec.wasm" | sed 's/[^A-Za-z0-9\+\/]//g'
	echo -n '","'
	base64 -w 0 "${TMPDIR}/soljson.wasm.lz4" | sed 's/[^A-Za-z0-9\+\/]//g'
	echo -n "\",${SOLJSON_WASM_SIZE});"
	tail -c +6 "${SOLJSON_JS}"
) > "$OUTPUT"

echo "Testing $OUTPUT."

node <<EOF
var embeddedBinary = require('./upload/soljson.js').wasmBinary
require('fs').readFile("$SOLJSON_WASM", function(err, data) {
	if (err) throw err;
	if (data.length != embeddedBinary.length)
		throw "different size";
	for(var i = 0; i < data.length; ++i)
		if (data[i] != embeddedBinary[i])
			throw "different contents";
	console.log("Binaries match.")
})
EOF
