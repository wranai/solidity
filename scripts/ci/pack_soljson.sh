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

echo "Packing $SOLJSON_JS and $SOLJSON_WASM to $OUTPUT."
(
	echo -n 'var Module = Module || {}; Module["wasmBinary"] = '
	cat "${SCRIPT_DIR}/wasm_unpack.js"
	echo -n '("'
	lz4c --no-frame-crc --best --favor-decSpeed "${SOLJSON_WASM}" - | base64 -w 0 | sed 's/[^A-Za-z0-9\+\/=]//g'
	echo -n "\",${SOLJSON_WASM_SIZE});"
	tail -c +6 "${SOLJSON_JS}"
) > "$OUTPUT"

TEST=$(cat <<EOF
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
)

echo "Testing $OUTPUT."

node <<EOF
$TEST
EOF

echo "Testing $OUTPUT without Uint8Array.fill."

node <<EOF
Uint8ArrayFull = Uint8Array;
Uint8Array = function(size) {
	var result = new Uint8ArrayFull(size);
	result.fill = undefined;
	return result;
}
var dst = new Uint8Array(32);
if (dst.fill !== undefined)
	throw "Mocking failed.";
$TEST
EOF
