"use strict";
var __asyncValues = (this && this.__asyncValues) || function (o) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var m = o[Symbol.asyncIterator];
    return m ? m.call(o) : typeof __values === "function" ? __values(o) : o[Symbol.iterator]();
};
var __await = (this && this.__await) || function (v) { return this instanceof __await ? (this.v = v, this) : new __await(v); }
var __asyncGenerator = (this && this.__asyncGenerator) || function (thisArg, _arguments, generator) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var g = generator.apply(thisArg, _arguments || []), i, q = [];
    return i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i;
    function verb(n) { if (g[n]) i[n] = function (v) { return new Promise(function (a, b) { q.push([n, v, a, b]) > 1 || resume(n, v); }); }; }
    function resume(n, v) { try { step(g[n](v)); } catch (e) { settle(q[0][3], e); } }
    function step(r) { r.value instanceof __await ? Promise.resolve(r.value.v).then(fulfill, reject) : settle(q[0][2], r);  }
    function fulfill(value) { resume("next", value); }
    function reject(value) { resume("throw", value); }
    function settle(f, v) { if (f(v), q.shift(), q.length) resume(q[0][0], q[0][1]); }
};
Object.defineProperty(exports, "__esModule", { value: true });
const stream_1 = require("stream");
//---------- string -> stream
class StringStream extends stream_1.Readable {
    constructor(str) {
        super();
        this._str = str;
        this._done = false;
    }
    _read() {
        if (!this._done) {
            this._done = true;
            this.push(this._str);
            this.push(null);
        }
    }
}
exports.StringStream = StringStream;
//---------- stream -> string
function readableToString(readable, encoding = 'utf8') {
    return new Promise((resolve, reject) => {
        readable.setEncoding(encoding);
        let data = '';
        readable.on('data', function (chunk) {
            data += chunk;
        });
        readable.on('end', function () {
            resolve(data);
        });
        readable.on('error', function (err) {
            reject(err);
        });
    });
}
exports.readableToString = readableToString;
//---------- async tools
/**
 * Parameter: async iterable of chunks (strings)
 * Result: async iterable of lines (incl. newlines)
 */
function chunksToLinesAsync(chunks) {
    return __asyncGenerator(this, arguments, function* chunksToLinesAsync_1() {
        if (!Symbol.asyncIterator) {
            throw new Error('Current JavaScript engine does not support asynchronous iterables');
        }
        if (!(Symbol.asyncIterator in chunks)) {
            throw new Error('Parameter is not an asynchronous iterable');
        }
        let previous = '';
        try {
            for (var chunks_1 = __asyncValues(chunks), chunks_1_1; chunks_1_1 = yield __await(chunks_1.next()), !chunks_1_1.done;) {
                const chunk = yield __await(chunks_1_1.value);
                previous += chunk;
                let eolIndex;
                while ((eolIndex = previous.indexOf('\n')) >= 0) {
                    // line includes the EOL
                    const line = previous.slice(0, eolIndex + 1);
                    yield line;
                    previous = previous.slice(eolIndex + 1);
                }
            }
        }
        catch (e_1_1) { e_1 = { error: e_1_1 }; }
        finally {
            try {
                if (chunks_1_1 && !chunks_1_1.done && (_a = chunks_1.return)) yield __await(_a.call(chunks_1));
            }
            finally { if (e_1) throw e_1.error; }
        }
        if (previous.length > 0) {
            yield previous;
        }
        var e_1, _a;
    });
}
exports.chunksToLinesAsync = chunksToLinesAsync;
async function asyncIterableToArray(asyncIterable) {
    const result = new Array();
    try {
        for (var asyncIterable_1 = __asyncValues(asyncIterable), asyncIterable_1_1; asyncIterable_1_1 = await asyncIterable_1.next(), !asyncIterable_1_1.done;) {
            const elem = await asyncIterable_1_1.value;
            result.push(elem);
        }
    }
    catch (e_2_1) { e_2 = { error: e_2_1 }; }
    finally {
        try {
            if (asyncIterable_1_1 && !asyncIterable_1_1.done && (_a = asyncIterable_1.return)) await _a.call(asyncIterable_1);
        }
        finally { if (e_2) throw e_2.error; }
    }
    return result;
    var e_2, _a;
}
exports.asyncIterableToArray = asyncIterableToArray;
//---------- string tools
const RE_NEWLINE = /\r?\n$/u;
function chomp(line) {
    const match = RE_NEWLINE.exec(line);
    if (!match)
        return line;
    return line.slice(0, match.index);
}
exports.chomp = chomp;
//---------- Promisified writing to streams
/**
 * Usage:
 * <pre>
 * await streamWrite(someStream, 'abc');
 * await streamWrite(someStream, 'def');
 * await streamEnd(someStream);
 * </pre>
 *
 * @see https://nodejs.org/dist/latest-v10.x/docs/api/stream.html#stream_writable_write_chunk_encoding_callback
 */
function streamWrite(stream, chunk, encoding = 'utf8') {
    return streamPromiseHelper(stream, callback => stream.write(chunk, encoding, callback));
}
exports.streamWrite = streamWrite;
function streamEnd(stream) {
    return streamPromiseHelper(stream, callback => stream.end(callback));
}
exports.streamEnd = streamEnd;
function streamPromiseHelper(emitter, operation) {
    return new Promise((resolve, reject) => {
        const errListener = (err) => {
            emitter.removeListener('error', errListener);
            reject(err);
        };
        emitter.addListener('error', errListener);
        const callback = () => {
            emitter.removeListener('error', errListener);
            resolve(undefined);
        };
        operation(callback);
    });
}
//---------- Tools for child processes
function onExit(childProcess) {
    return new Promise((resolve, reject) => {
        childProcess.once('exit', (code, signal) => {
            if (code === 0) {
                resolve(undefined);
            }
            else {
                reject(new Error('Exit with error code: ' + code));
            }
        });
        childProcess.once('error', (err) => {
            reject(err);
        });
    });
}
exports.onExit = onExit;
//# sourceMappingURL=index.js.map