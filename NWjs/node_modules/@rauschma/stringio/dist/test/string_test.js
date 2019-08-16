"use strict";
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
test('From string to stream to string', async () => {
    const str = 'Hello!\nHow are you?\n';
    const stringStream = new src_1.StringStream(str);
    const result = await src_1.readableToString(stringStream);
    assert.strictEqual(result, str);
});
test('File stream stream to string', async () => {
    const PATH = path.resolve(__dirname, '../../ts/test/test_file.txt');
    const stream = fs.createReadStream(PATH);
    const str = await src_1.readableToString(stream);
    assert.strictEqual(str, 'First line.\nSecond line.\n');
});
//# sourceMappingURL=string_test.js.map