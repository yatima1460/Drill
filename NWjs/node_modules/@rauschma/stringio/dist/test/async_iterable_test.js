"use strict";
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
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) result[k] = mod[k];
    result["default"] = mod;
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const assert = __importStar(require("assert"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const src_1 = require("../src");
test('Chunk iterable to lines', async () => {
    function createChunks() {
        return __asyncGenerator(this, arguments, function* createChunks_1() {
            yield 'line A\nline B\n';
        });
    }
    const arr = await src_1.asyncIterableToArray(src_1.chunksToLinesAsync(createChunks()));
    assert.deepStrictEqual(arr, [
        'line A\n',
        'line B\n',
    ]);
});
test('String stream to lines', async () => {
    const stream = new src_1.StringStream('line A\nline B\n'); // temporary work-around
    const arr = await src_1.asyncIterableToArray(src_1.chunksToLinesAsync(stream));
    assert.deepStrictEqual(arr, [
        'line A\n',
        'line B\n',
    ]);
});
test('File stream to lines', async () => {
    const PATH = path.resolve(__dirname, '../../ts/test/test_file.txt');
    const stream = fs.createReadStream(PATH); // temporary work-around
    const arr = await src_1.asyncIterableToArray(src_1.chunksToLinesAsync(stream));
    assert.deepStrictEqual(arr, [
        'First line.\n',
        'Second line.\n',
    ]);
});
//# sourceMappingURL=async_iterable_test.js.map