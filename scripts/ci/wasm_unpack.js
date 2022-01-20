(function(lz4BlockCodec, source, uncompressedSize) {
	function base64DecToArr (sB64Enc, aBytes) {
		/*\
		|*|
		|*|  Base64 / binary data / UTF-8 strings utilities (#1)
		|*|
		|*|  https://developer.mozilla.org/en-US/docs/Web/API/WindowBase64/Base64_encoding_and_decoding
		|*|
		|*|  Author: madmurphy
		|*|
		\*/
		/* Array of bytes to base64 string decoding */
		function b64ToUint6 (nChr) {
			return nChr > 64 && nChr < 91 ?
				nChr - 65
				: nChr > 96 && nChr < 123 ?
				nChr - 71
				: nChr > 47 && nChr < 58 ?
				nChr + 4
				: nChr === 43 ?
				62
				: nChr === 47 ?
				63
				:
				0;
		}
		var nInLen = sB64Enc.length,
			nOutLen = nInLen * 3 + 1 >>> 2;
		aBytes = aBytes || new Uint8Array(nOutLen);
		for (var nMod3, nMod4, nUint24 = 0, nOutIdx = 0, nInIdx = 0; nInIdx < nInLen; nInIdx++) {
			nMod4 = nInIdx & 3;
			nUint24 |= b64ToUint6(sB64Enc.charCodeAt(nInIdx)) << 18 - 6 * nMod4;
			if (nMod4 === 3 || nInLen - nInIdx === 1) {
				for (nMod3 = 0; nMod3 < 3 && nOutIdx < nOutLen; nMod3++, nOutIdx++) {
					aBytes[nOutIdx] = nUint24 >>> (16 >>> nMod3 & 24) & 255;
				}
				nUint24 = 0;
			}
		}
		return aBytes;
	}
	function lz4Decompress (encoded) {
		var src_len = encoded.length * 3 + 1 >>> 2;
		var lz4api = (new WebAssembly.Instance(new WebAssembly.Module(base64DecToArr(lz4BlockCodec)))).exports;
		var src = new Uint8Array(lz4api.memory.buffer, 0, src_len);
		base64DecToArr(encoded, src);
		lz4api.lz4Decode(0, src_len)
		return new Uint8Array(lz4api.memory.buffer, src_len, uncompressedSize);
	};
	return lz4Decompress(source);
})
