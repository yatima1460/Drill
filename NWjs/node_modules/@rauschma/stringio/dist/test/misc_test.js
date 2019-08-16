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
const src_1 = require("../src");
test('chomp', () => {
    assert.strictEqual(src_1.chomp('abc'), 'abc');
    assert.strictEqual(src_1.chomp('abc\n'), 'abc');
    assert.strictEqual(src_1.chomp('abc\r\n'), 'abc');
    assert.strictEqual(src_1.chomp(''), '');
});
//# sourceMappingURL=misc_test.js.map