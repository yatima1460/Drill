/// <reference types="node" />
import { Readable, Writable } from 'stream';
import { ChildProcess } from 'child_process';
export declare class StringStream extends Readable {
    private _done;
    private _str;
    constructor(str: string);
    _read(): void;
}
export declare function readableToString(readable: Readable, encoding?: string): Promise<string>;
/**
 * Parameter: async iterable of chunks (strings)
 * Result: async iterable of lines (incl. newlines)
 */
export declare function chunksToLinesAsync(chunks: AsyncIterable<string>): AsyncIterable<string>;
export declare function asyncIterableToArray<T>(asyncIterable: AsyncIterable<T>): Promise<Array<T>>;
export declare function chomp(line: string): string;
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
export declare function streamWrite(stream: Writable, chunk: string | Buffer | Uint8Array, encoding?: string): Promise<void>;
export declare function streamEnd(stream: Writable): Promise<void>;
export declare function onExit(childProcess: ChildProcess): Promise<void>;
