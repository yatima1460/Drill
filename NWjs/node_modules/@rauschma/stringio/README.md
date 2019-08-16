# stringio: convert strings to Node.js streams and vice versa

```
npm install @rauschma/stringio
```
<!-- ########################################################## -->

## Strings ↔︎ streams

See line A and line B:

```js
import * as assert from 'assert';
import { StringStream, readableToString } from '@rauschma/stringio';

test('From string to stream to string', async () => {
  const str = 'Hello!\nHow are you?\n';
  const stringStream = new StringStream(str); // (A)
  const result = await readableToString(stringStream); // (B)
  assert.strictEqual(result, str);
});
```

### `StringStream`: from string to stream

```typescript
declare class StringStream extends Readable {
  constructor(str: string);
}
```

Used in line A.

### `readableToString`: from stream to string

```typescript
declare function readableToString(readable: Readable, encoding?: string): Promise<string>;
```

Default encoding is `'utf-8'`.

Used in line B.

#### Reading stdin into a string

```typescript
async function readStdin() {
  const str = await readableToString(process.stdin);
  console.log('STR: '+str);
}
```

### Related npm packages

* [`string-to-stream`](https://github.com/feross/string-to-stream): Convert a string into a stream.
* [`get-stream`](https://github.com/sindresorhus/get-stream): Get a stream as a string, buffer, or array.

<!-- ########################################################## -->

## Asynchronous iterables

### `chunksToLinesAsync`: async iterable over chunks to async iterable over lines

```typescript
declare function chunksToLinesAsync(chunks: AsyncIterable<string>): AsyncIterable<string>;
```

Each line includes the line break at the end (if any – the last line may not have one).

Example (starting with Node.js v.10, readable streams are asynchronous iterables):

```js
const fs = require('fs');
const {chunksToLinesAsync} = require('@rauschma/stringio');

async function main() {
  const stream = fs.createReadStream(process.argv[2]);
    // Works, too: const stream = process.stdin;
  for await (const line of chunksToLinesAsync(stream)) {
    console.log(chomp(line));
  }
}
main();
```

<!-- ########################################################## -->

## Promisified writing to streams

```typescript
declare function streamWrite(
  stream: Writable,
  chunk: string | Buffer | Uint8Array,
  encoding = 'utf8')
  : Promise<void>;

declare function streamEnd(
  stream: Writable)
  : Promise<void>;
```

Usage:

```js
await streamWrite(someStream, 'abc');
await streamWrite(someStream, 'def');
await streamEnd(someStream);
```

<!-- ########################################################## -->

## `onExit(childProcess)`: wait until a child process is finished

```ts
export declare function onExit(childProcess: ChildProcess): Promise<void>;
```

Usage:

```js
const childProcess = child_process.spawn(···);
await onExit(childProcess);
```

Errors emitted by `childProcess` or a non-zero exit code reject the Promise returned by `onExit()`.

<!-- ########################################################## -->

## String helper function

### `chomp`: remove a line break at the end of a line

```typescript
declare function chomp(line: string): string;
```

## Further reading

The following 2ality blog posts use `stringio`:

* [Reading streams via async iteration in Node.js](http://2ality.com/2018/04/async-iter-nodejs.html)
* [Working with stdout and stdin of a child process in Node.js](http://2ality.com/2018/05/child-process-streams.html)

## Acknowledgements

* `StringStream` is inspired by: https://github.com/feross/string-to-stream/blob/master/index.js