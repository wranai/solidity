;;
;; lz4-block-codec.wat: a WebAssembly implementation of LZ4 block format codec
;; Copyright (C) 2018 Raymond Hill
;;
;; BSD-2-Clause License (http://www.opensource.org/licenses/bsd-license.php)
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;;
;;   1. Redistributions of source code must retain the above copyright
;; notice, this list of conditions and the following disclaimer.
;;
;;   2. Redistributions in binary form must reproduce the above
;; copyright notice, this list of conditions and the following disclaimer
;; in the documentation and/or other materials provided with the
;; distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;
;; Home: https://github.com/gorhill/lz4-wasm
;;
;; I used the same license as the one picked by creator of LZ4 out of respect
;; for his creation, see https://lz4.github.io/lz4/
;;

(module
;;
;; module start
;;

;; (func $log (import "imports" "log") (param i32 i32 i32))

(memory (export "memory") <PAGE_COUNT>)

;;
;; Public functions
;;
;; void lz4BlockDecode(
;;     unsigned int inPtr,
;;     unsigned int outPtr
;; )
(func (export "lz4Decode")
	(param $inPtr i32)                 ;; start of input buffer
	(param $outPtr i32)                ;; start of output buffer
	(local $blockSize i32)             ;; current blockSize

	block $noMoreBlocks loop           ;; iterate through all blocks
		get_local $inPtr
		i32.load
		tee_local $blockSize

		get_local $inPtr
		i32.const 4
		i32.add
		set_local $inPtr

		i32.eqz
		br_if $noMoreBlocks

		get_local $blockSize
		i32.const 0x80000000
		i32.and
		if ;; uncompressed
			get_local $outPtr
			get_local $inPtr
			get_local $blockSize
			i32.const 0x7FFFFFFF
			i32.and
			tee_local $blockSize
			call $copy
			get_local $inPtr
			get_local $blockSize
			i32.add
			set_local $inPtr
			get_local $outPtr
			get_local $blockSize
			i32.add
			set_local $outPtr
			br 0
		end
		get_local $inPtr
		get_local $blockSize
		get_local $outPtr
		call $lz4BlockDecode
		get_local $outPtr
		i32.add
		set_local $outPtr
		get_local $inPtr
		get_local $blockSize
		i32.add
		set_local $inPtr
		br 0
	end end $noMoreBlocks
)

;;
;; Private functions
;;

;;
;; Reference:
;; https://github.com/lz4/lz4/blob/dev/doc/lz4_Block_format.md
;;
(func $lz4BlockDecode
    (param $inPtr0 i32)                 ;; start of input buffer
    (param $ilen i32)                   ;; length of input buffer
    (param $outPtr0 i32)                ;; start of output buffer
    (result i32)
    (local $inPtr i32)                  ;; current position in input buffer
    (local $inPtrEnd i32)               ;; end of input buffer
    (local $outPtr i32)                 ;; current position in output buffer
    (local $matchPtr i32)               ;; position of current match
    (local $token i32)                  ;; sequence token
    (local $clen i32)                   ;; number of bytes to copy
    (local $_ i32)                      ;; general purpose variable
    get_local $ilen                     ;; if ( ilen == 0 ) { return 0; }
    i32.eqz
    if
        i32.const 0
        return
    end
    get_local $inPtr0
    tee_local $inPtr                    ;; current position in input buffer
    get_local $ilen
    i32.add
    set_local $inPtrEnd
    get_local $outPtr0                  ;; start of output buffer
    set_local $outPtr                   ;; current position in output buffer
    block $noMoreSequence loop          ;; iterate through all sequences
        get_local $inPtr
        get_local $inPtrEnd
        i32.ge_u
        br_if $noMoreSequence           ;; break when nothing left to read in input buffer
        get_local $inPtr                ;; read token -- consume one byte
        i32.load8_u
        get_local $inPtr
        i32.const 1
        i32.add
        set_local $inPtr
        tee_local $token                ;; extract length of literals from token
        i32.const 4
        i32.shr_u
        tee_local $clen                 ;; consume extra length bytes if present
        i32.eqz
        if else
            get_local $clen
            i32.const 15
            i32.eq
            if loop
                get_local $inPtr
                i32.load8_u
                get_local $inPtr
                i32.const 1
                i32.add
                set_local $inPtr
                tee_local $_
                get_local $clen
                i32.add
                set_local $clen
                get_local $_
                i32.const 255
                i32.eq
                br_if 0
            end end
            get_local $outPtr           ;; copy literals to output buffer
            get_local $inPtr
            get_local $clen
            call $copy
            get_local $outPtr           ;; advance output buffer pointer past copy
            get_local $clen
            i32.add
            set_local $outPtr
            get_local $clen             ;; advance input buffer pointer past literals
            get_local $inPtr
            i32.add
            tee_local $inPtr
            get_local $inPtrEnd         ;; exit if this is the last sequence
            i32.eq
            br_if $noMoreSequence
        end
        get_local $outPtr               ;; read match offset
        get_local $inPtr
        i32.load8_u
        get_local $inPtr
        i32.load8_u offset=1
        i32.const 8
        i32.shl
        i32.or
        i32.sub
        tee_local $matchPtr
        get_local $outPtr               ;; match position can't be outside input buffer bounds
        i32.eq
        br_if $noMoreSequence
        get_local $matchPtr
        get_local $inPtrEnd
        i32.lt_u
        br_if $noMoreSequence
        get_local $inPtr                ;; advance input pointer past match offset bytes
        i32.const 2
        i32.add
        set_local $inPtr
        get_local $token                ;; extract length of match from token
        i32.const 15
        i32.and
        i32.const 4
        i32.add
        tee_local $clen
        i32.const 19                    ;; consume extra length bytes if present
        i32.eq
        if loop
            get_local $inPtr
            i32.load8_u
            get_local $inPtr
            i32.const 1
            i32.add
            set_local $inPtr
            tee_local $_
            get_local $clen
            i32.add
            set_local $clen
            get_local $_
            i32.const 255
            i32.eq
            br_if 0
        end end
        get_local $outPtr               ;; copy match to output buffer
        get_local $matchPtr
        get_local $clen
        call $copy
        get_local $clen                 ;; advance output buffer pointer past copy
        get_local $outPtr
        i32.add
        set_local $outPtr
        br 0
    end end $noMoreSequence
    get_local $outPtr                   ;; return number of written bytes
    get_local $outPtr0
    i32.sub
)

;;
;; Copy n bytes from source to destination.
;;
;; It is overlap-safe only from left-to-right -- which is only what is
;; required in the current module.
;;
(func $copy
    (param $dst i32)
    (param $src i32)
    (param $len i32)
    block $lessThan8 loop
        get_local $len
        i32.const 8
        i32.lt_u
        br_if $lessThan8
        get_local $dst
        get_local $src
        i32.load8_u
        i32.store8
        get_local $dst
        get_local $src
        i32.load8_u offset=1
        i32.store8 offset=1
        get_local $dst
        get_local $src
        i32.load8_u offset=2
        i32.store8 offset=2
        get_local $dst
        get_local $src
        i32.load8_u offset=3
        i32.store8 offset=3
        get_local $dst
        get_local $src
        i32.load8_u offset=4
        i32.store8 offset=4
        get_local $dst
        get_local $src
        i32.load8_u offset=5
        i32.store8 offset=5
        get_local $dst
        get_local $src
        i32.load8_u offset=6
        i32.store8 offset=6
        get_local $dst
        get_local $src
        i32.load8_u offset=7
        i32.store8 offset=7
        get_local $dst
        i32.const 8
        i32.add
        set_local $dst
        get_local $src
        i32.const 8
        i32.add
        set_local $src
        get_local $len
        i32.const -8
        i32.add
        set_local $len
        br 0
    end end $lessThan8
    get_local $len
    i32.const 4
    i32.ge_u
    if
        get_local $dst
        get_local $src
        i32.load8_u
        i32.store8
        get_local $dst
        get_local $src
        i32.load8_u offset=1
        i32.store8 offset=1
        get_local $dst
        get_local $src
        i32.load8_u offset=2
        i32.store8 offset=2
        get_local $dst
        get_local $src
        i32.load8_u offset=3
        i32.store8 offset=3
        get_local $dst
        i32.const 4
        i32.add
        set_local $dst
        get_local $src
        i32.const 4
        i32.add
        set_local $src
        get_local $len
        i32.const -4
        i32.add
        set_local $len
    end
    get_local $len
    i32.const 2
    i32.ge_u
    if
        get_local $dst
        get_local $src
        i32.load8_u
        i32.store8
        get_local $dst
        get_local $src
        i32.load8_u offset=1
        i32.store8 offset=1
        get_local $dst
        i32.const 2
        i32.add
        set_local $dst
        get_local $src
        i32.const 2
        i32.add
        set_local $src
        get_local $len
        i32.const -2
        i32.add
        set_local $len
    end
    get_local $len
    i32.eqz
    if else
        get_local $dst
        get_local $src
        i32.load8_u
        i32.store8
    end
)

;;
;; module end
;;
)
