# datefmt

Date formatting and **parsing** based on `strftime`.

## Basic Usage
You can parse something by just calling `parse`:

```D
import datefmt;
auto st = "Thu, 17 Apr 2014 14:47:35 GMT".parse("%a, %d %b %Y %H:%M:%S GMT");
assert(st == SysTime(DateTime(2014, 4, 17, 14, 47, 35), UTC()));
```

And you can convert it to string the same way:

```D
auto st = SysTime(DateTime(2014, 4, 17, 14, 47, 35), UTC());
auto formatted = st.format("%a, %d %b %Y %H:%M:%S GMT");
assert(formatted == "Thu, 17 Apr 2014 14:47:35 GMT");
```

datefmt also supports the tryParse pattern popularized by C#:

```D
SysTime st;
if (tryParse(userInput, "%a, %d %b %Y %H:%M:%S GMT", st))
{
    // use the value
}
```

## Format sets
Some standards, like ISO8601, specify a collection of related formats. If you have a document that
must provide values in ISO8601 format, a compliant document might include a date like `20100418`,
`2018-12-15T13:00`, or `1904-10-18 04:00:00.000000Z`.

To handle this, datefmt has a notion of format collections, simply called `Format`. A Format has a
primary format, which is used for converting to string, and an array of alternative forms that are
used for parsing.

It's simple to make your own:

```D
Format customFormat = {
    primaryFormat: "%a, %d %b %Y %H:%M:%S %Z",
    formatOptions: [
        "%d %b %Y %H:%M:%S %Z",
        "%a %d %b %Y %H:%M:%S %Z",
        "%a, %d %b %Y %H:%M:%S",
    ]
};
SysTime st = parse(someRfcishString, customFormat);
```


## Dub

Add a dependency on `"datefmt": "~>1.0.0"`.
