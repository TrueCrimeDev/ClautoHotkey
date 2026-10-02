#!/usr/bin/env python3
"""jqlite: a dependency-free stand-in for the part of jq the ClautoHotkey hooks use.

Every hook parses its stdin with jq. On a machine without jq, _harness-env.sh
defines a `jq` shell function that runs this file instead, so hook code stays
unchanged. It implements the jq language core rather than a list of canned
filters: paths, iteration, pipes, comma, alternatives, comparisons and
arithmetic, and/or, object and array construction, string interpolation and
@formats, if/elif/else, try/catch and `?`, `as` bindings, reduce/foreach, and
the common builtins (length, tonumber, tostring, select, map, keys, has, sort,
group_by, unique, add, to_entries, test/sub/gsub, ...).

Anything outside that - function definitions (def), assignment and other path
expressions (=, |=, +=, del, path), destructuring, modules, label/break and the
stream/date-format builtins - fails loudly with "jqlite: unsupported filter: ..."
on stderr and exit status 3. Printing nothing would be worse: an empty result is
exactly what a hook reads as "that field is not present".

Command line and exit status follow jq. Flags: -r -j -c -n -s -e -a -S -R -M,
--tab, --indent n, --arg, --argjson, --slurpfile, --rawfile, --args, --jsonargs,
-f file. Exit: 0 ok; with -e, 1 when the last output is false or null and 4 when
there was no output; 2 usage error or input that is not JSON; 3 compile error or
unsupported filter; 5 runtime error.

Needs Python 3.8 or newer and nothing outside the standard library.
"""

import json
import math
import os
import re
import sys

VERSION = "jqlite-1.0"


class JQError(Exception):
    """A jq runtime error. `value` is what `try ... catch` hands its handler."""

    def __init__(self, value):
        Exception.__init__(self)
        self.value = value

    def text(self):
        if isinstance(self.value, str):
            return self.value
        return "(not a string): " + dumps(self.value)


class CompileError(Exception):
    """The filter does not parse (exit 3)."""


class Unsupported(CompileError):
    """Valid jq that jqlite does not implement (exit 3, never silent)."""


class InputError(Exception):
    """Input that is not JSON (exit 2)."""


class Halt(Exception):
    """halt / halt_error: stop at once with this exit status."""

    def __init__(self, code):
        Exception.__init__(self)
        self.code = code


# Values: null, booleans, numbers, strings, arrays and objects map onto None,
# bool, int/float, str, list and dict. Nothing below mutates a value it was
# handed, so values can be shared freely between outputs.

def is_num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def jtype(v):
    if v is None:
        return "null"
    if v is True or v is False:
        return "boolean"
    if isinstance(v, (int, float)):
        return "number"
    if isinstance(v, str):
        return "string"
    if isinstance(v, list):
        return "array"
    return "object"


def truthy(v):
    return v is not None and v is not False


def _rank(v):
    if v is None:
        return 0
    if v is False:
        return 1
    if v is True:
        return 2
    if isinstance(v, (int, float)):
        return 3
    if isinstance(v, str):
        return 4
    if isinstance(v, list):
        return 5
    return 6


def jcmp(a, b):
    """jq's total order: null < false < true < numbers < strings < arrays < objects."""
    ra, rb = _rank(a), _rank(b)
    if ra != rb:
        return -1 if ra < rb else 1
    if ra in (3, 4):
        return -1 if a < b else (1 if a > b else 0)
    if ra == 5:
        for x, y in zip(a, b):
            c = jcmp(x, y)
            if c:
                return c
        return -1 if len(a) < len(b) else (1 if len(a) > len(b) else 0)
    if ra == 6:
        ka, kb = sorted(a), sorted(b)
        c = jcmp(ka, kb)
        if c:
            return c
        for k in ka:
            c = jcmp(a[k], b[k])
            if c:
                return c
    return 0


def jeq(a, b):
    return jcmp(a, b) == 0


_SORT_KEY = None


def sort_key(v):
    global _SORT_KEY
    if _SORT_KEY is None:
        import functools
        _SORT_KEY = functools.cmp_to_key(jcmp)
    return _SORT_KEY(v)


_MAX_DOUBLE = 1.7976931348623157e308


def _clean(v):
    """Numbers as jq prints them: integral floats without '.0', nan as null."""
    if isinstance(v, float):
        if v != v:
            return None
        if v in (float("inf"), float("-inf")):
            return _MAX_DOUBLE if v > 0 else -_MAX_DOUBLE
        if v.is_integer() and abs(v) < 1e17:
            return int(v)
        return v
    if isinstance(v, list):
        return [_clean(x) for x in v]
    if isinstance(v, dict):
        return dict((k, _clean(x)) for k, x in v.items())
    return v


def dumps(v, indent=None, sort_keys=False, ascii_only=False):
    seps = (",", ":") if indent is None else (",", ": ")
    s = json.dumps(_clean(v), indent=indent, separators=seps,
                   sort_keys=sort_keys, ensure_ascii=ascii_only)
    return s.replace("\x7f", "\\u007f")


def tostring(v):
    return v if isinstance(v, str) else dumps(v)


def desc(v):
    """'type (value)' the way jq words its errors, long values truncated."""
    s = dumps(v)
    if len(s) > 14:
        s = s[:11] + "..."
    return "%s (%s)" % (jtype(v), s)


def index(t, k):
    """t[k] with jq's rules: missing keys and null containers give null."""
    if isinstance(k, str):
        if isinstance(t, dict):
            return t.get(k)
        if t is None:
            return None
        if len(k.encode("utf-8", "surrogatepass")) < 30:
            raise JQError('Cannot index %s with "%s"' % (jtype(t), k))
        raise JQError("Cannot index %s with string" % jtype(t))
    if is_num(k):
        if isinstance(t, list):
            if k != k:
                return None
            i = int(math.floor(k))
            if i < 0:
                i += len(t)
            return t[i] if 0 <= i < len(t) else None
        if t is None:
            return None
        raise JQError("Cannot index %s with number" % jtype(t))
    if isinstance(k, dict) and (t is None or isinstance(t, (list, str))):
        return slice_value(t, k.get("start"), k.get("end"))
    if isinstance(k, list) and isinstance(t, list):
        return indices_of(t, k)
    raise JQError("Cannot index %s with %s" % (jtype(t), jtype(k)))


def slice_value(t, start, end):
    if t is None:
        return None
    if not isinstance(t, (list, str)):
        raise JQError("Cannot index %s with object" % jtype(t))
    if (start is not None and not is_num(start)) or (end is not None and not is_num(end)):
        raise JQError("Start and end indices of an array slice must be numbers")
    n = len(t)
    s = 0.0 if start is None else float(start)
    e = float(n) if end is None else float(end)
    if s < 0:
        s += n
    if e < 0:
        e += n
    s = min(max(s, 0.0), float(n))
    e = min(max(e, s), float(n))
    return t[int(s):int(math.ceil(e))]


def iterate(t):
    if isinstance(t, list):
        return list(t)
    if isinstance(t, dict):
        return list(t.values())
    raise JQError("Cannot iterate over %s" % ("null" if t is None else desc(t)))


def indices_of(v, i):
    if v is None:
        return None
    if isinstance(v, str) and isinstance(i, str):
        if i == "":
            return None
        out, start = [], 0
        while True:
            p = v.find(i, start)
            if p < 0:
                return out
            out.append(p)
            start = p + 1
    if isinstance(v, list) and isinstance(i, list):
        if not i:
            return None
        n = len(i)
        return [p for p in range(len(v) - n + 1)
                if all(jeq(v[p + q], i[q]) for q in range(n))]
    if isinstance(v, list):
        return [p for p, x in enumerate(v) if jeq(x, i)]
    raise JQError("Cannot determine the indices of %s in %s" % (desc(i), desc(v)))


def op_add(a, b):
    if a is None:
        return b
    if b is None:
        return a
    if is_num(a) and is_num(b):
        return a + b
    if isinstance(a, str) and isinstance(b, str):
        return a + b
    if isinstance(a, list) and isinstance(b, list):
        return a + b
    if isinstance(a, dict) and isinstance(b, dict):
        r = dict(a)
        r.update(b)
        return r
    raise JQError("%s and %s cannot be added" % (desc(a), desc(b)))


def op_sub(a, b):
    if is_num(a) and is_num(b):
        return a - b
    if isinstance(a, list) and isinstance(b, list):
        return [x for x in a if not any(jeq(x, y) for y in b)]
    raise JQError("%s and %s cannot be subtracted" % (desc(a), desc(b)))


def _deep_merge(a, b):
    r = dict(a)
    for k, v in b.items():
        if isinstance(r.get(k), dict) and isinstance(v, dict):
            r[k] = _deep_merge(r[k], v)
        else:
            r[k] = v
    return r


def op_mul(a, b):
    if is_num(a) and is_num(b):
        return a * b
    if (isinstance(a, str) and is_num(b)) or (is_num(a) and isinstance(b, str)):
        s, n = (a, b) if isinstance(a, str) else (b, a)
        if n <= 0:
            return None
        return s * max(1, int(n))
    if isinstance(a, dict) and isinstance(b, dict):
        return _deep_merge(a, b)
    raise JQError("%s and %s cannot be multiplied" % (desc(a), desc(b)))


def _split_str(s, sep):
    if s == "":
        return []
    if sep == "":
        return list(s)
    return s.split(sep)


def op_div(a, b):
    if is_num(a) and is_num(b):
        if b == 0:
            raise JQError("%s and %s cannot be divided because the divisor is zero"
                          % (desc(a), desc(b)))
        return a / b
    if isinstance(a, str) and isinstance(b, str):
        return _split_str(a, b)
    raise JQError("%s and %s cannot be divided" % (desc(a), desc(b)))


def _to_int(x):
    if x != x or x in (float("inf"), float("-inf")):
        raise JQError("%s cannot be converted to an integer" % desc(x))
    return int(x)


def op_mod(a, b):
    if is_num(a) and is_num(b):
        ai, bi = _to_int(a), _to_int(b)
        if bi == 0:
            raise JQError("%s and %s cannot be divided because the divisor is zero"
                          % (desc(a), desc(b)))
        r = abs(ai) % abs(bi)
        return -r if ai < 0 else r
    raise JQError("%s and %s cannot be divided" % (desc(a), desc(b)))


_BINOPS = {
    "+": op_add,
    "-": op_sub,
    "*": op_mul,
    "/": op_div,
    "%": op_mod,
    "==": lambda a, b: jcmp(a, b) == 0,
    "!=": lambda a, b: jcmp(a, b) != 0,
    "<": lambda a, b: jcmp(a, b) < 0,
    "<=": lambda a, b: jcmp(a, b) <= 0,
    ">": lambda a, b: jcmp(a, b) > 0,
    ">=": lambda a, b: jcmp(a, b) >= 0,
}


# The tree. Every node's ev(input, env) returns an iterator of outputs; env maps
# variable names (without '$') to values. Where jq has a defined order for the
# cartesian product of several generators, the loops below follow it.

class Node(object):
    __slots__ = ()


class Identity(Node):
    __slots__ = ()

    def ev(self, inp, env):
        yield inp


class Literal(Node):
    __slots__ = ("value",)

    def __init__(self, value):
        self.value = value

    def ev(self, inp, env):
        yield self.value


class Var(Node):
    __slots__ = ("name",)

    def __init__(self, name):
        self.name = name

    def ev(self, inp, env):
        yield env[self.name]


class Pipe(Node):
    __slots__ = ("a", "b")

    def __init__(self, a, b):
        self.a, self.b = a, b

    def ev(self, inp, env):
        b = self.b
        for x in self.a.ev(inp, env):
            for y in b.ev(x, env):
                yield y


class Comma(Node):
    __slots__ = ("a", "b")

    def __init__(self, a, b):
        self.a, self.b = a, b

    def ev(self, inp, env):
        for x in self.a.ev(inp, env):
            yield x
        for x in self.b.ev(inp, env):
            yield x


class Alt(Node):
    """a // b: a's truthy outputs, or b's if there were none. Errors in a count as none."""
    __slots__ = ("a", "b")

    def __init__(self, a, b):
        self.a, self.b = a, b

    def ev(self, inp, env):
        found = False
        try:
            for v in self.a.ev(inp, env):
                if truthy(v):
                    found = True
                    yield v
        except JQError:
            pass
        if not found:
            for v in self.b.ev(inp, env):
                yield v


class Try(Node):
    """try body catch handler, and the postfix `?` (no handler)."""
    __slots__ = ("body", "handler")

    def __init__(self, body, handler):
        self.body, self.handler = body, handler

    def ev(self, inp, env):
        try:
            for v in self.body.ev(inp, env):
                yield v
        except JQError as e:
            if self.handler is not None:
                for v in self.handler.ev(e.value, env):
                    yield v


class Index(Node):
    """target[key]; the key is evaluated against `.`, not against the target."""
    __slots__ = ("target", "key", "opt")

    def __init__(self, target, key, opt=False):
        self.target, self.key, self.opt = target, key, opt

    def ev(self, inp, env):
        for k in self.key.ev(inp, env):
            for t in self.target.ev(inp, env):
                if self.opt:
                    try:
                        v = index(t, k)
                    except JQError:
                        continue
                else:
                    v = index(t, k)
                yield v


class Slice(Node):
    __slots__ = ("target", "lo", "hi", "opt")

    def __init__(self, target, lo, hi, opt=False):
        self.target, self.lo, self.hi, self.opt = target, lo, hi, opt

    def ev(self, inp, env):
        his = list(self.hi.ev(inp, env)) if self.hi is not None else [None]
        los = list(self.lo.ev(inp, env)) if self.lo is not None else [None]
        for hi in his:
            for lo in los:
                for t in self.target.ev(inp, env):
                    if self.opt:
                        try:
                            v = slice_value(t, lo, hi)
                        except JQError:
                            continue
                    else:
                        v = slice_value(t, lo, hi)
                    yield v


class Iterate(Node):
    __slots__ = ("target", "opt")

    def __init__(self, target, opt=False):
        self.target, self.opt = target, opt

    def ev(self, inp, env):
        for t in self.target.ev(inp, env):
            if self.opt:
                try:
                    items = iterate(t)
                except JQError:
                    continue
            else:
                items = iterate(t)
            for x in items:
                yield x


class RecurseAll(Node):
    """`..`, the same as recurse."""
    __slots__ = ()

    def ev(self, inp, env):
        return _dfs(inp, _recurse_children_step)


class Collect(Node):
    """[ expr ]"""
    __slots__ = ("body",)

    def __init__(self, body):
        self.body = body

    def ev(self, inp, env):
        if self.body is None:
            yield []
        else:
            yield list(self.body.ev(inp, env))


class ObjectCons(Node):
    """{k: v, ...}: one object per combination, the first pair varying slowest."""
    __slots__ = ("pairs",)

    def __init__(self, pairs):
        self.pairs = pairs

    def ev(self, inp, env):
        return self._build(0, inp, env, ())

    def _build(self, i, inp, env, acc):
        if i == len(self.pairs):
            out = {}
            for k, v in acc:
                out[k] = v
            yield out
            return
        knode, vnode = self.pairs[i]
        for k in knode.ev(inp, env):
            if not isinstance(k, str):
                raise JQError("Object keys must be strings")
            for v in vnode.ev(inp, env):
                for o in self._build(i + 1, inp, env, acc + ((k, v),)):
                    yield o


class Neg(Node):
    __slots__ = ("body",)

    def __init__(self, body):
        self.body = body

    def ev(self, inp, env):
        for v in self.body.ev(inp, env):
            if not is_num(v):
                raise JQError("%s cannot be negated" % desc(v))
            yield -v


class Binop(Node):
    """Arithmetic and comparison. jq loops over the right operand outermost."""
    __slots__ = ("fn", "a", "b")

    def __init__(self, op, a, b):
        self.fn, self.a, self.b = _BINOPS[op], a, b

    def ev(self, inp, env):
        fn = self.fn
        for r in self.b.ev(inp, env):
            for l in self.a.ev(inp, env):
                yield fn(l, r)


class And(Node):
    __slots__ = ("a", "b")

    def __init__(self, a, b):
        self.a, self.b = a, b

    def ev(self, inp, env):
        for l in self.a.ev(inp, env):
            if not truthy(l):
                yield False
                continue
            for r in self.b.ev(inp, env):
                yield truthy(r)


class Or(Node):
    __slots__ = ("a", "b")

    def __init__(self, a, b):
        self.a, self.b = a, b

    def ev(self, inp, env):
        for l in self.a.ev(inp, env):
            if truthy(l):
                yield True
                continue
            for r in self.b.ev(inp, env):
                yield truthy(r)


class If(Node):
    """if/elif/else/end; a missing else passes the input through (jq 1.7)."""
    __slots__ = ("cond", "then", "els")

    def __init__(self, cond, then, els):
        self.cond, self.then, self.els = cond, then, els

    def ev(self, inp, env):
        for c in self.cond.ev(inp, env):
            if truthy(c):
                for v in self.then.ev(inp, env):
                    yield v
            elif self.els is None:
                yield inp
            else:
                for v in self.els.ev(inp, env):
                    yield v


class Bind(Node):
    """source as $name | body  (body still sees the original input as `.`)"""
    __slots__ = ("source", "name", "body")

    def __init__(self, source, name, body):
        self.source, self.name, self.body = source, name, body

    def ev(self, inp, env):
        for v in self.source.ev(inp, env):
            env2 = dict(env)
            env2[self.name] = v
            for out in self.body.ev(inp, env2):
                yield out


_NOTHING = object()


class Reduce(Node):
    __slots__ = ("source", "name", "init", "update")

    def __init__(self, source, name, init, update):
        self.source, self.name, self.init, self.update = source, name, init, update

    def ev(self, inp, env):
        for acc in self.init.ev(inp, env):
            for v in self.source.ev(inp, env):
                env2 = dict(env)
                env2[self.name] = v
                last = _NOTHING
                for last in self.update.ev(acc, env2):
                    pass
                acc = None if last is _NOTHING else last
            yield acc


class Foreach(Node):
    __slots__ = ("source", "name", "init", "update", "extract")

    def __init__(self, source, name, init, update, extract):
        self.source, self.name = source, name
        self.init, self.update, self.extract = init, update, extract

    def ev(self, inp, env):
        for state in self.init.ev(inp, env):
            for v in self.source.ev(inp, env):
                env2 = dict(env)
                env2[self.name] = v
                current, state = state, None
                for s in self.update.ev(current, env2):
                    state = s
                    if self.extract is None:
                        yield s
                    else:
                        for out in self.extract.ev(s, env2):
                            yield out


class Interp(Node):
    """A string with \\( ) interpolations, optionally under an @format.

    jq builds it as a left fold of `+`, so the last interpolation varies slowest
    when several produce more than one output; _fold reproduces that order.
    """
    __slots__ = ("parts", "fmt")

    def __init__(self, parts, fmt):
        self.parts, self.fmt = parts, fmt

    def ev(self, inp, env):
        return self._fold(len(self.parts) - 1, inp, env)

    def _fold(self, i, inp, env):
        if i < 0:
            yield ""
            return
        part = self.parts[i]
        if isinstance(part, str):
            for left in self._fold(i - 1, inp, env):
                yield left + part
        else:
            for v in part.ev(inp, env):
                s = apply_format(self.fmt, v)
                for left in self._fold(i - 1, inp, env):
                    yield left + s


class Format(Node):
    """A bare @name, applied to the input."""
    __slots__ = ("fmt",)

    def __init__(self, fmt):
        self.fmt = fmt

    def ev(self, inp, env):
        yield apply_format(self.fmt, inp)


class Call(Node):
    __slots__ = ("impl", "args")

    def __init__(self, impl, args):
        self.impl, self.args = impl, args

    def ev(self, inp, env):
        return self.impl(self.args, inp, env)


def _dfs(start, step):
    """Iterative depth-first expansion for recurse/until/while/repeat.

    step(v) yields ("out", x) to emit x and ("push", y) to expand y next, before
    the rest of step(v). An explicit stack keeps deep or long recursions off
    Python's call stack.
    """
    stack = [step(start)]
    while stack:
        try:
            kind, x = next(stack[-1])
        except StopIteration:
            stack.pop()
            continue
        if kind == "out":
            yield x
        else:
            stack.append(step(x))


def _recurse_children_step(v):
    yield ("out", v)
    if isinstance(v, list):
        for x in v:
            yield ("push", x)
    elif isinstance(v, dict):
        for x in v.values():
            yield ("push", x)


# Formats: @text @json @html @uri @csv @tsv @sh @base64 @base64d @base32 @base32d

_URI_SAFE = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")


def _fmt_row(v, fmt):
    if not isinstance(v, list):
        raise JQError("%s cannot be %s-formatted, only an array can be" % (desc(v), fmt))
    cells = []
    for x in v:
        if is_num(x):
            cells.append(dumps(x))
        elif x is True or x is False:
            cells.append("true" if x else "false")
        elif x is None:
            cells.append("")
        elif isinstance(x, str):
            if fmt == "csv":
                cells.append('"' + x.replace('"', '""') + '"')
            else:
                cells.append(x.replace("\\", "\\\\").replace("\t", "\\t")
                             .replace("\n", "\\n").replace("\r", "\\r"))
        else:
            raise JQError("%s is not valid in a %s row" % (desc(x), fmt))
    return ("," if fmt == "csv" else "\t").join(cells)


def _fmt_sh(v):
    def quote(x):
        if isinstance(x, str):
            return "'" + x.replace("'", "'\\''") + "'"
        if isinstance(x, (list, dict)):
            raise JQError("%s can not be escaped for shell" % desc(x))
        return dumps(x)
    if isinstance(v, list):
        return " ".join(quote(x) for x in v)
    return quote(v)


def _b_decode(s, base32):
    import base64
    import binascii
    data = s.encode("utf-8")
    data = data.rstrip(b"=")
    try:
        if base32:
            raw = base64.b32decode(data + b"=" * (-len(data) % 8))
        else:
            raw = base64.b64decode(data + b"=" * (-len(data) % 4))
    except (binascii.Error, ValueError):
        raise JQError("%s is not valid base%s data" % (desc(s), "32" if base32 else "64"))
    return raw.decode("utf-8", "replace")


def apply_format(fmt, v):
    if fmt is None or fmt == "text":
        return tostring(v)
    if fmt == "json":
        return dumps(v)
    if fmt == "csv" or fmt == "tsv":
        return _fmt_row(v, fmt)
    if fmt == "sh":
        return _fmt_sh(v)
    s = tostring(v)
    if fmt == "html":
        return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("'", "&#39;").replace('"', "&quot;"))
    if fmt == "uri":
        return "".join(c if c in _URI_SAFE else "".join("%%%02X" % b for b in c.encode("utf-8"))
                       for c in s)
    if fmt in ("base64", "base32"):
        import base64
        enc = base64.b64encode if fmt == "base64" else base64.b32encode
        return enc(s.encode("utf-8")).decode("ascii")
    if fmt in ("base64d", "base32d"):
        return _b_decode(s, fmt == "base32d")
    raise JQError("%s is not a valid format" % fmt)


FORMATS = frozenset(["text", "json", "html", "uri", "csv", "tsv", "sh",
                     "base64", "base64d", "base32", "base32d"])


# Builtins, keyed by (name, arity). An implementation takes (args, input, env)
# and returns an iterator; args are unevaluated nodes. The _builtin decorator
# wraps plain value functions: "value" returns one output, "gen" returns an
# iterable, "raw" receives the nodes itself.

BUILTINS = {}


def _cartesian(args, inp, env):
    """Argument value tuples; like jq's C builtins, the first argument varies fastest."""
    if not args:
        yield ()
        return
    for v in args[-1].ev(inp, env):
        for rest in _cartesian(args[:-1], inp, env):
            yield rest + (v,)


def _builtin(name, arity=0, kind="value"):
    def deco(fn):
        if kind == "raw":
            impl = fn
        elif kind == "value":
            def impl(args, inp, env, fn=fn):
                for vals in _cartesian(args, inp, env):
                    yield fn(inp, *vals)
        else:
            def impl(args, inp, env, fn=fn):
                for vals in _cartesian(args, inp, env):
                    for out in fn(inp, *vals):
                        yield out
        BUILTINS[(name, arity)] = impl
        return fn
    return deco


class _Context(object):
    """Run-wide state the input/inputs/input_filename builtins need."""

    def __init__(self):
        self.inputs = iter(())
        self.filename = None
        self.err = None


CTX = _Context()


def _err_write(text):
    stream = CTX.err if CTX.err is not None else getattr(sys.stderr, "buffer", None)
    if stream is None:
        sys.stderr.write(text)
    else:
        stream.write(encode_utf8(text))
        stream.flush()


@_builtin("empty", 0, "raw")
def _empty(args, inp, env):
    return iter(())


@_builtin("not")
def _not(v):
    return not truthy(v)


@_builtin("error")
def _error0(v):
    raise JQError(v)


@_builtin("error", 1)
def _error1(v, msg):
    raise JQError(msg)


@_builtin("length")
def _length(v):
    if v is None:
        return 0
    if v is True or v is False:
        raise JQError("%s has no length" % desc(v))
    if is_num(v):
        return abs(v)
    return len(v)


@_builtin("utf8bytelength")
def _utf8bytelength(v):
    if not isinstance(v, str):
        raise JQError("%s only strings have UTF-8 byte length" % desc(v))
    return len(v.encode("utf-8", "surrogatepass"))


@_builtin("type")
def _type(v):
    return jtype(v)


@_builtin("keys")
def _keys(v):
    if isinstance(v, dict):
        return sorted(v.keys())
    if isinstance(v, list):
        return list(range(len(v)))
    raise JQError("%s has no keys" % desc(v))


@_builtin("keys_unsorted")
def _keys_unsorted(v):
    if isinstance(v, dict):
        return list(v.keys())
    if isinstance(v, list):
        return list(range(len(v)))
    raise JQError("%s has no keys" % desc(v))


def _has(v, k):
    if isinstance(v, dict) and isinstance(k, str):
        return k in v
    if isinstance(v, list) and is_num(k):
        return 0 <= k < len(v)
    raise JQError("Cannot check whether %s has a %s key" % (jtype(v), jtype(k)))


@_builtin("has", 1)
def _has_b(v, k):
    return _has(v, k)


@_builtin("in", 1)
def _in(v, o):
    return _has(o, v)


def _contains(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return all(k in a and _contains(a[k], bv) for k, bv in b.items())
    if isinstance(a, list) and isinstance(b, list):
        return all(any(_contains(x, y) for x in a) for y in b)
    if isinstance(a, str) and isinstance(b, str):
        return b in a
    if jtype(a) == jtype(b):
        return jeq(a, b)
    raise JQError("%s and %s cannot have their containment checked" % (desc(a), desc(b)))


@_builtin("contains", 1)
def _contains_b(v, b):
    return _contains(v, b)


@_builtin("inside", 1)
def _inside(v, b):
    return _contains(b, v)


@_builtin("startswith", 1)
def _startswith(v, s):
    if not (isinstance(v, str) and isinstance(s, str)):
        raise JQError("startswith() requires string inputs")
    return v.startswith(s)


@_builtin("endswith", 1)
def _endswith(v, s):
    if not (isinstance(v, str) and isinstance(s, str)):
        raise JQError("endswith() requires string inputs")
    return v.endswith(s)


@_builtin("ltrimstr", 1)
def _ltrimstr(v, s):
    if isinstance(v, str) and isinstance(s, str) and v.startswith(s):
        return v[len(s):]
    return v


@_builtin("rtrimstr", 1)
def _rtrimstr(v, s):
    if isinstance(v, str) and isinstance(s, str) and s and v.endswith(s):
        return v[:-len(s)]
    return v


_WS_CHARS = " \t\n\r\f\v"


def _need_str(v, what):
    if not isinstance(v, str):
        raise JQError("%s input must be a string" % what)
    return v


@_builtin("trim")
def _trim(v):
    return _need_str(v, "trim").strip(_WS_CHARS)


@_builtin("ltrim")
def _ltrim(v):
    return _need_str(v, "trim").lstrip(_WS_CHARS)


@_builtin("rtrim")
def _rtrim(v):
    return _need_str(v, "trim").rstrip(_WS_CHARS)


@_builtin("split", 1)
def _split1(v, sep):
    if not (isinstance(v, str) and isinstance(sep, str)):
        raise JQError("split input and separator must be strings")
    return _split_str(v, sep)


@_builtin("join", 1)
def _join(v, sep):
    parts = []
    for x in iterate(v):
        if x is None:
            parts.append("")
        elif isinstance(x, str):
            parts.append(x)
        elif is_num(x) or x is True or x is False:
            parts.append(dumps(x))
        else:
            raise JQError("Cannot join with %s" % jtype(x))
    if not parts:
        return ""
    if not isinstance(sep, str):
        if len(parts) == 1:
            return parts[0]
        raise JQError("%s and %s cannot be added" % (desc(parts[0]), desc(sep)))
    return sep.join(parts)


_ASCII_LOWER = dict((c, c + 32) for c in range(65, 91))
_ASCII_UPPER = dict((c + 32, c) for c in range(65, 91))


@_builtin("ascii_downcase")
def _ascii_downcase(v):
    return _need_str(v, "ascii_downcase").translate(_ASCII_LOWER)


@_builtin("ascii_upcase")
def _ascii_upcase(v):
    return _need_str(v, "ascii_upcase").translate(_ASCII_UPPER)


@_builtin("explode")
def _explode(v):
    return [ord(c) for c in _need_str(v, "explode")]


@_builtin("implode")
def _implode(v):
    if not isinstance(v, list) or not all(is_num(c) for c in v):
        raise JQError("Implode input must be an array of codepoints")
    try:
        return "".join(chr(int(c)) for c in v)
    except (ValueError, OverflowError):
        raise JQError("Invalid codepoint literal")


@_builtin("ascii")
def _ascii(v):
    if not is_num(v):
        raise JQError("ascii input must be a number")
    return chr(int(v))


@_builtin("tostring")
def _tostring(v):
    return tostring(v)


_NUM_TEXT = re.compile(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?\Z")


@_builtin("tonumber")
def _tonumber(v):
    if is_num(v):
        return v
    if isinstance(v, str):
        t = v.strip()
        if _NUM_TEXT.match(t):
            return int(t) if re.match(r"-?\d+\Z", t) else float(t)
        raise JQError("Cannot parse '%s' as JSON" % v)
    raise JQError("%s cannot be parsed as a number" % desc(v))


@_builtin("tojson")
def _tojson(v):
    return dumps(v)


@_builtin("fromjson")
def _fromjson(v):
    if not isinstance(v, str):
        raise JQError("%s cannot be parsed as JSON" % desc(v))
    try:
        return json.loads(v, parse_constant=_reject_constant)
    except ValueError as e:
        raise JQError("%s (while parsing '%s')" % (e, v))


@_builtin("add")
def _add(v):
    acc = None
    for x in iterate(v):
        acc = op_add(acc, x)
    return acc


@_builtin("add", 1, "raw")
def _add1(args, inp, env):
    acc = None
    for x in args[0].ev(inp, env):
        acc = op_add(acc, x)
    yield acc


@_builtin("any")
def _any0(v):
    return any(truthy(x) for x in iterate(v))


@_builtin("all")
def _all0(v):
    return all(truthy(x) for x in iterate(v))


def _any_gen(gen, cond, env):
    for x in gen:
        for c in cond.ev(x, env):
            if truthy(c):
                return True
    return False


def _all_gen(gen, cond, env):
    for x in gen:
        for c in cond.ev(x, env):
            if not truthy(c):
                return False
    return True


@_builtin("any", 1, "raw")
def _any1(args, inp, env):
    yield _any_gen(iterate(inp), args[0], env)


@_builtin("all", 1, "raw")
def _all1(args, inp, env):
    yield _all_gen(iterate(inp), args[0], env)


@_builtin("any", 2, "raw")
def _any2(args, inp, env):
    yield _any_gen(args[0].ev(inp, env), args[1], env)


@_builtin("all", 2, "raw")
def _all2(args, inp, env):
    yield _all_gen(args[0].ev(inp, env), args[1], env)


def _range_values(lo, hi, step):
    if not (is_num(lo) and is_num(hi) and is_num(step)):
        raise JQError("Range bounds must be numeric")
    x = lo
    if step > 0:
        while x < hi:
            yield x
            x += step
    elif step < 0:
        while x > hi:
            yield x
            x += step


@_builtin("range", 1, "raw")
def _range1(args, inp, env):
    for hi in args[0].ev(inp, env):
        for x in _range_values(0, hi, 1):
            yield x


@_builtin("range", 2, "raw")
def _range2(args, inp, env):
    for lo in args[0].ev(inp, env):
        for hi in args[1].ev(inp, env):
            for x in _range_values(lo, hi, 1):
                yield x


@_builtin("range", 3, "raw")
def _range3(args, inp, env):
    for lo in args[0].ev(inp, env):
        for hi in args[1].ev(inp, env):
            for step in args[2].ev(inp, env):
                for x in _range_values(lo, hi, step):
                    yield x


def _num_in(v, name):
    if not is_num(v):
        raise JQError("%s number required" % desc(v))
    return v


def _math(name, fn):
    def impl(v):
        try:
            return fn(_num_in(v, name))
        except (ValueError, OverflowError):
            return float("nan")
    _builtin(name)(impl)


_math("floor", lambda x: int(math.floor(x)) if math.isfinite(x) else x)
_math("ceil", lambda x: int(math.ceil(x)) if math.isfinite(x) else x)
_math("round", lambda x: (int(math.floor(abs(x) + 0.5)) * (1 if x >= 0 else -1))
      if math.isfinite(x) else x)
_math("trunc", lambda x: int(x) if math.isfinite(x) else x)
_math("fabs", lambda x: abs(float(x)))
_math("sqrt", lambda x: math.sqrt(x) if x >= 0 else float("nan"))
_math("log", lambda x: math.log(x) if x > 0 else (float("-inf") if x == 0 else float("nan")))
_math("log2", lambda x: math.log(x, 2) if x > 0 else (float("-inf") if x == 0 else float("nan")))
_math("log10", lambda x: math.log10(x) if x > 0 else (float("-inf") if x == 0 else float("nan")))
_math("exp", math.exp)
_math("exp2", lambda x: 2.0 ** x)
_math("exp10", lambda x: 10.0 ** x)


@_builtin("abs")
def _abs(v):
    if not is_num(v):
        raise JQError("%s has no absolute value" % desc(v))
    return abs(v)


@_builtin("pow", 2, "raw")
def _pow(args, inp, env):
    for b in args[0].ev(inp, env):
        for e in args[1].ev(inp, env):
            try:
                yield float(_num_in(b, "pow")) ** _num_in(e, "pow")
            except (ZeroDivisionError, OverflowError, ValueError):
                yield float("nan")


@_builtin("infinite")
def _infinite(v):
    return float("inf")


@_builtin("nan")
def _nan(v):
    return float("nan")


@_builtin("isinfinite")
def _isinfinite(v):
    return math.isinf(_num_in(v, "isinfinite"))


@_builtin("isnan")
def _isnan(v):
    x = _num_in(v, "isnan")
    return x != x


@_builtin("isnormal")
def _isnormal(v):
    x = _num_in(v, "isnormal")
    return bool(x) and math.isfinite(x) and abs(x) >= 2.2250738585072014e-308


def _need_list(v, what):
    if not isinstance(v, list):
        raise JQError("%s cannot be %s, as it is not an array" % (desc(v), what))
    return v


@_builtin("sort")
def _sort(v):
    return sorted(_need_list(v, "sorted"), key=sort_key)


def _keyed(args, v, env):
    return [(list(args[0].ev(x, env)), x) for x in v]


@_builtin("sort_by", 1, "raw")
def _sort_by(args, inp, env):
    keyed = _keyed(args, _need_list(inp, "sorted"), env)
    keyed.sort(key=lambda kx: sort_key(kx[0]))
    yield [x for _, x in keyed]


def _groups(args, inp, env):
    keyed = _keyed(args, _need_list(inp, "grouped"), env)
    keyed.sort(key=lambda kx: sort_key(kx[0]))
    groups = []
    for k, x in keyed:
        if groups and jeq(groups[-1][0], k):
            groups[-1][1].append(x)
        else:
            groups.append((k, [x]))
    return groups


@_builtin("group_by", 1, "raw")
def _group_by(args, inp, env):
    yield [g for _, g in _groups(args, inp, env)]


@_builtin("unique_by", 1, "raw")
def _unique_by(args, inp, env):
    yield [g[0] for _, g in _groups(args, inp, env)]


@_builtin("unique")
def _unique(v):
    out = []
    for x in sorted(_need_list(v, "sorted"), key=sort_key):
        if not out or not jeq(out[-1], x):
            out.append(x)
    return out


def _extreme(pairs, want_max):
    best = None
    for k, x in pairs:
        if best is None:
            best = (k, x)
            continue
        c = jcmp(k, best[0])
        if (want_max and c >= 0) or (not want_max and c < 0):
            best = (k, x)
    return None if best is None else best[1]


@_builtin("min")
def _min(v):
    return _extreme([(x, x) for x in _need_list(v, "compared")], False)


@_builtin("max")
def _max(v):
    return _extreme([(x, x) for x in _need_list(v, "compared")], True)


@_builtin("min_by", 1, "raw")
def _min_by(args, inp, env):
    yield _extreme(_keyed(args, _need_list(inp, "compared"), env), False)


@_builtin("max_by", 1, "raw")
def _max_by(args, inp, env):
    yield _extreme(_keyed(args, _need_list(inp, "compared"), env), True)


@_builtin("reverse")
def _reverse(v):
    if v is None:
        return []
    if isinstance(v, (str, list)):
        return v[::-1]
    raise JQError("Cannot index %s with number" % jtype(v))


def _flatten(v, depth):
    out = []
    for x in v:
        if isinstance(x, list) and depth != 0:
            out.extend(_flatten(x, depth - 1))
        else:
            out.append(x)
    return out


@_builtin("flatten")
def _flatten0(v):
    return _flatten(_need_list(v, "flattened"), -1)


@_builtin("flatten", 1)
def _flatten1(v, depth):
    if not is_num(depth) or depth < 0:
        raise JQError("flatten depth must not be negative")
    return _flatten(_need_list(v, "flattened"), depth)


@_builtin("transpose")
def _transpose(v):
    rows = _need_list(v, "transposed")
    width = max([len(r) for r in rows] or [0])
    return [[r[i] if i < len(r) else None for r in rows] for i in range(width)]


@_builtin("map", 1, "raw")
def _map(args, inp, env):
    out = []
    for x in iterate(inp):
        out.extend(args[0].ev(x, env))
    yield out


@_builtin("map_values", 1, "raw")
def _map_values(args, inp, env):
    f = args[0]
    if isinstance(inp, dict):
        out = {}
        for k, x in inp.items():
            for y in f.ev(x, env):
                out[k] = y
                break
        yield out
    elif isinstance(inp, list):
        lst = []
        for x in inp:
            for y in f.ev(x, env):
                lst.append(y)
                break
        yield lst
    else:
        iterate(inp)


@_builtin("select", 1, "raw")
def _select(args, inp, env):
    for c in args[0].ev(inp, env):
        if truthy(c):
            yield inp


@_builtin("recurse", 0, "raw")
def _recurse0(args, inp, env):
    return _dfs(inp, _recurse_children_step)


@_builtin("recurse", 1, "raw")
def _recurse1(args, inp, env):
    f = args[0]

    def step(v):
        yield ("out", v)
        for x in f.ev(v, env):
            yield ("push", x)
    return _dfs(inp, step)


@_builtin("recurse", 2, "raw")
def _recurse2(args, inp, env):
    f, cond = args

    def step(v):
        yield ("out", v)
        for x in f.ev(v, env):
            for c in cond.ev(x, env):
                if truthy(c):
                    yield ("push", x)
    return _dfs(inp, step)


@_builtin("until", 2, "raw")
def _until(args, inp, env):
    cond, update = args

    def step(v):
        for c in cond.ev(v, env):
            if truthy(c):
                yield ("out", v)
            else:
                for u in update.ev(v, env):
                    yield ("push", u)
    return _dfs(inp, step)


@_builtin("while", 2, "raw")
def _while(args, inp, env):
    cond, update = args

    def step(v):
        for c in cond.ev(v, env):
            if truthy(c):
                yield ("out", v)
                for u in update.ev(v, env):
                    yield ("push", u)
    return _dfs(inp, step)


@_builtin("repeat", 1, "raw")
def _repeat(args, inp, env):
    f = args[0]

    def step(v):
        yield ("out", v)
        for u in f.ev(v, env):
            yield ("push", u)
    return _dfs(inp, step)


@_builtin("to_entries")
def _to_entries(v):
    if isinstance(v, dict):
        return [{"key": k, "value": x} for k, x in v.items()]
    if isinstance(v, list):
        return [{"key": i, "value": x} for i, x in enumerate(v)]
    raise JQError("%s has no keys" % desc(v))


def _from_entries(v):
    out = {}
    for e in iterate(v):
        if not isinstance(e, dict):
            raise JQError('Cannot index %s with "key"' % jtype(e))
        k = e.get("key")
        if k is None:
            k = e.get("Key")
            for name in ("k", "name", "Name", "K"):
                if truthy(e.get(name)):
                    k = e.get(name)
                    break
        if not isinstance(k, str):
            k = dumps(k)
        out[k] = e["value"] if "value" in e else e.get("v")
    return out


@_builtin("from_entries")
def _from_entries_b(v):
    return _from_entries(v)


@_builtin("with_entries", 1, "raw")
def _with_entries(args, inp, env):
    mapped = []
    for e in _to_entries(inp):
        mapped.extend(args[0].ev(e, env))
    yield _from_entries(mapped)


def _walk(f, v, env):
    if isinstance(v, dict):
        nv = {}
        for k, x in v.items():
            for y in _walk(f, x, env):
                nv[k] = y
                break
        v = nv
    elif isinstance(v, list):
        nl = []
        for x in v:
            nl.extend(_walk(f, x, env))
        v = nl
    return list(f.ev(v, env))


@_builtin("walk", 1, "raw")
def _walk_b(args, inp, env):
    return iter(_walk(args[0], inp, env))


@_builtin("first")
def _first0(v):
    return index(v, 0)


@_builtin("last")
def _last0(v):
    return index(v, -1)


@_builtin("nth", 1)
def _nth1(v, n):
    return index(v, n)


@_builtin("first", 1, "raw")
def _first1(args, inp, env):
    for v in args[0].ev(inp, env):
        yield v
        return


@_builtin("last", 1, "raw")
def _last1(args, inp, env):
    last = _NOTHING
    for last in args[0].ev(inp, env):
        pass
    if last is not _NOTHING:
        yield last


def _limited(n, gen):
    if n <= 0:
        return
    count = 0
    for v in gen:
        yield v
        count += 1
        if count >= n:
            return


@_builtin("limit", 2, "raw")
def _limit(args, inp, env):
    for n in args[0].ev(inp, env):
        if not is_num(n):
            raise JQError("Invalid limit: %s" % desc(n))
        if n < 0:
            gen = args[1].ev(inp, env)
        else:
            gen = _limited(n, args[1].ev(inp, env))
        for v in gen:
            yield v


@_builtin("nth", 2, "raw")
def _nth2(args, inp, env):
    for n in args[0].ev(inp, env):
        if not is_num(n) or n < 0:
            raise JQError("Out of bounds negative array index")
        last = _NOTHING
        for last in _limited(int(n) + 1, args[1].ev(inp, env)):
            pass
        if last is not _NOTHING:
            yield last


@_builtin("isempty", 1, "raw")
def _isempty(args, inp, env):
    for _ in args[0].ev(inp, env):
        yield False
        return
    yield True


@_builtin("indices", 1)
def _indices_b(v, i):
    return indices_of(v, i)


@_builtin("index", 1)
def _index_b(v, i):
    r = indices_of(v, i)
    return r[0] if r else None


@_builtin("rindex", 1)
def _rindex_b(v, i):
    r = indices_of(v, i)
    return r[-1] if r else None


@_builtin("getpath", 1)
def _getpath(v, p):
    if not isinstance(p, list):
        raise JQError("Path must be specified as an array")
    for k in p:
        if v is None:
            return None
        v = index(v, k)
    return v


def _all_paths(v, prefix):
    if isinstance(v, list):
        items = list(enumerate(v))
    elif isinstance(v, dict):
        items = list(v.items())
    else:
        return
    for k, x in items:
        p = prefix + [k]
        yield p, x
        for sub in _all_paths(x, p):
            yield sub


@_builtin("paths", 0, "raw")
def _paths0(args, inp, env):
    for p, _ in _all_paths(inp, []):
        yield p


@_builtin("paths", 1, "raw")
def _paths1(args, inp, env):
    for p, x in _all_paths(inp, []):
        for c in args[0].ev(x, env):
            if truthy(c):
                yield p


@_builtin("leaf_paths", 0, "raw")
def _leaf_paths(args, inp, env):
    for p, x in _all_paths(inp, []):
        if not isinstance(x, (list, dict)):
            yield p


def _type_filter(name, pred):
    def impl(args, inp, env):
        if pred(inp):
            yield inp
    _builtin(name, 0, "raw")(impl)


_type_filter("values", lambda v: v is not None)
_type_filter("nulls", lambda v: v is None)
_type_filter("booleans", lambda v: v is True or v is False)
_type_filter("numbers", is_num)
_type_filter("strings", lambda v: isinstance(v, str))
_type_filter("arrays", lambda v: isinstance(v, list))
_type_filter("objects", lambda v: isinstance(v, dict))
_type_filter("iterables", lambda v: isinstance(v, (list, dict)))
_type_filter("scalars", lambda v: not isinstance(v, (list, dict)))


@_builtin("toarray")
def _toarray(v):
    return v if isinstance(v, list) else [v]


def _regex(pattern, flags):
    if not isinstance(pattern, str):
        raise JQError("%s cannot be matched, as it is not a string" % desc(pattern))
    if flags is not None and not isinstance(flags, str):
        raise JQError("%s is not a string" % desc(flags))
    reflags, glob, noempty = 0, False, False
    for ch in flags or "":
        if ch == "g":
            glob = True
        elif ch == "i":
            reflags |= re.IGNORECASE
        elif ch == "x":
            reflags |= re.VERBOSE
        elif ch == "p":
            reflags |= re.DOTALL
        elif ch == "n":
            noempty = True
        elif ch in "sl":
            pass
        else:
            raise JQError("%s is not a valid modifier string" % flags)
    # Oniguruma spells named groups (?<name>...); Python wants (?P<name>...).
    py = re.sub(r"\(\?<([A-Za-z_][A-Za-z0-9_]*)>", r"(?P<\1>", pattern)
    try:
        rx = re.compile(py, reflags)
    except re.error as e:
        raise JQError("%s (at offset %s) is not a valid regex: %s" % (pattern, e.pos, e.msg))
    return rx, glob, noempty


def _matches(subject, pattern, flags, force_global=False):
    if not isinstance(subject, str):
        raise JQError("%s cannot be matched, as it is not a string" % desc(subject))
    rx, glob, noempty = _regex(pattern, flags)
    out = []
    for m in rx.finditer(subject):
        if noempty and m.end() == m.start():
            continue
        out.append(m)
        if not (glob or force_global):
            break
    return rx, out


def _match_obj(m, rx):
    names = dict((i, n) for n, i in rx.groupindex.items())
    caps = []
    for gi in range(1, rx.groups + 1):
        s = m.group(gi)
        if s is None:
            caps.append({"offset": -1, "length": 0, "string": None, "name": names.get(gi)})
        else:
            caps.append({"offset": m.start(gi), "length": len(s), "string": s,
                         "name": names.get(gi)})
    return {"offset": m.start(), "length": m.end() - m.start(), "string": m.group(0),
            "captures": caps}


def _capture_obj(m, rx):
    return dict((name, m.group(name)) for name in rx.groupindex)


def _match_impl(subject, pattern, flags):
    rx, ms = _matches(subject, pattern, flags)
    return [_match_obj(m, rx) for m in ms]


def _register_regex():
    def match1(v, p):
        return _match_impl(v, p, None)

    def match2(v, p, f):
        return _match_impl(v, p, f)

    def test1(v, p):
        return bool(_matches(v, p, None)[1])

    def test2(v, p, f):
        return bool(_matches(v, p, f)[1])

    def capture1(v, p):
        rx, ms = _matches(v, p, None)
        return [_capture_obj(m, rx) for m in ms]

    def capture2(v, p, f):
        rx, ms = _matches(v, p, f)
        return [_capture_obj(m, rx) for m in ms]

    def scan_impl(v, p, f):
        rx, ms = _matches(v, p, f, force_global=True)
        for m in ms:
            if rx.groups:
                yield [m.group(i) for i in range(1, rx.groups + 1)]
            else:
                yield m.group(0)

    def split_re(v, p, f):
        rx, ms = _matches(v, p, f, force_global=True)
        out, pos = [], 0
        for m in ms:
            out.append(v[pos:m.start()])
            pos = m.end()
        out.append(v[pos:])
        return out

    _builtin("match", 1, "gen")(match1)
    _builtin("match", 2, "gen")(match2)
    _builtin("test", 1)(test1)
    _builtin("test", 2)(test2)
    _builtin("capture", 1, "gen")(capture1)
    _builtin("capture", 2, "gen")(capture2)
    _builtin("scan", 1, "gen")(lambda v, p: scan_impl(v, p, None))
    _builtin("scan", 2, "gen")(scan_impl)
    _builtin("split", 2)(split_re)
    _builtin("splits", 1, "gen")(lambda v, p: split_re(v, p, None))
    _builtin("splits", 2, "gen")(split_re)


_register_regex()


def _sub_impl(args, inp, env, force_global):
    repl = args[1]
    flag_nodes = args[2:3]
    for pattern in args[0].ev(inp, env):
        flag_values = list(flag_nodes[0].ev(inp, env)) if flag_nodes else [None]
        for flags in flag_values:
            rx, ms = _matches(inp, pattern, flags, force_global=force_global)
            if not ms:
                yield inp
                continue
            for s in _sub_build(inp, rx, ms, 0, 0, "", repl, env):
                yield s


def _sub_build(subject, rx, ms, i, pos, acc, repl, env):
    if i == len(ms):
        yield acc + subject[pos:]
        return
    m = ms[i]
    for r in repl.ev(_capture_obj(m, rx), env):
        if not isinstance(r, str):
            raise JQError("%s cannot be added to a string" % desc(r))
        for s in _sub_build(subject, rx, ms, i + 1, m.end(),
                            acc + subject[pos:m.start()] + r, repl, env):
            yield s


@_builtin("sub", 2, "raw")
def _sub2(args, inp, env):
    return _sub_impl(args, inp, env, False)


@_builtin("sub", 3, "raw")
def _sub3(args, inp, env):
    return _sub_impl(args, inp, env, False)


@_builtin("gsub", 2, "raw")
def _gsub2(args, inp, env):
    return _sub_impl(args, inp, env, True)


@_builtin("gsub", 3, "raw")
def _gsub3(args, inp, env):
    return _sub_impl(args, inp, env, True)


@_builtin("env")
def _env(v):
    return dict(os.environ)


@_builtin("input", 0, "raw")
def _input(args, inp, env):
    try:
        yield next(CTX.inputs)
    except StopIteration:
        raise JQError("No more inputs")


@_builtin("inputs", 0, "raw")
def _inputs(args, inp, env):
    for v in CTX.inputs:
        yield v


@_builtin("input_filename")
def _input_filename(v):
    return CTX.filename


@_builtin("debug")
def _debug0(v):
    _err_write('["DEBUG:",%s]\n' % dumps(v))
    return v


@_builtin("debug", 1, "raw")
def _debug1(args, inp, env):
    for m in args[0].ev(inp, env):
        _err_write('["DEBUG:",%s]\n' % dumps(m))
    yield inp


@_builtin("stderr")
def _stderr(v):
    _err_write(dumps(v))
    return v


@_builtin("halt")
def _halt(v):
    raise Halt(0)


def _halt_error(v, code):
    if not is_num(code):
        raise JQError("halt_error/1: number required")
    _err_write(v if isinstance(v, str) else dumps(v) + "\n")
    raise Halt(int(code))


@_builtin("halt_error")
def _halt_error0(v):
    _halt_error(v, 5)


@_builtin("halt_error", 1)
def _halt_error1(v, code):
    _halt_error(v, code)


@_builtin("now")
def _now(v):
    import time
    return time.time()


_ISO_FMT = "%Y-%m-%dT%H:%M:%SZ"


def _todate(v):
    import datetime
    if not is_num(v):
        raise JQError("strftime/1 requires parsed datetime inputs")
    epoch = datetime.datetime(1970, 1, 1)
    return (epoch + datetime.timedelta(seconds=math.floor(v))).strftime(_ISO_FMT)


def _fromdate(v):
    import calendar
    import time
    if not isinstance(v, str):
        raise JQError("strptime/1 requires string inputs and arguments")
    try:
        return calendar.timegm(time.strptime(v, _ISO_FMT))
    except ValueError:
        raise JQError('date "%s" does not match format "%s"' % (v, _ISO_FMT))


_builtin("todate")(_todate)
_builtin("todateiso8601")(_todate)
_builtin("fromdate")(_fromdate)
_builtin("fromdateiso8601")(_fromdate)


# Lexer. Strings are lexed into literal chunks plus the raw source of each \( )
# interpolation; the parser compiles those with the variable scope of the spot
# where the string appears.

class Tok(object):
    __slots__ = ("kind", "value", "pos")

    def __init__(self, kind, value, pos):
        self.kind, self.value, self.pos = kind, value, pos


_KEYWORDS = frozenset("__loc__ and as break catch def elif else end foreach if "
                      "import include label or reduce then try".split())
_OPS = ("?//", "//=", "|=", "+=", "-=", "*=", "/=", "%=", "==", "!=", "<=", ">=",
        "//", "..", ".", "[", "]", "{", "}", "(", ")", "|", ",", ":", ";", "?", "=",
        "<", ">", "+", "-", "*", "/", "%")
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUMBER = re.compile(r"(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?")
_HEX4 = re.compile(r"[0-9A-Fa-f]{4}\Z")
_ESCAPES = {'"': '"', "\\": "\\", "/": "/", "b": "\b", "f": "\f", "n": "\n",
            "r": "\r", "t": "\t"}


def _num_value(text):
    return int(text) if text.isdigit() else float(text)


def _find_close(src, j):
    """Index of the ')' that closes an interpolation whose body starts at j."""
    depth, n = 1, len(src)
    while j < n:
        c = src[j]
        if c == '"':
            j = _skip_string(src, j)
            continue
        if c == "#":
            k = src.find("\n", j)
            j = n if k < 0 else k + 1
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return j
        j += 1
    raise CompileError("syntax error: unterminated string interpolation")


def _skip_string(src, j):
    j, n = j + 1, len(src)
    while j < n:
        c = src[j]
        if c == "\\":
            if src.startswith("(", j + 1):
                j = _find_close(src, j + 2) + 1
            else:
                j += 2
            continue
        if c == '"':
            return j + 1
        j += 1
    raise CompileError("syntax error: unterminated string literal")


def _lex_string(src, i):
    parts, buf = [], []
    j, n = i + 1, len(src)
    while True:
        if j >= n:
            raise CompileError("syntax error: unterminated string literal")
        c = src[j]
        if c == '"':
            break
        if c != "\\":
            buf.append(c)
            j += 1
            continue
        e = src[j + 1] if j + 1 < n else ""
        if e in _ESCAPES:
            buf.append(_ESCAPES[e])
            j += 2
        elif e == "u":
            hex1 = src[j + 2:j + 6]
            if not _HEX4.match(hex1):
                raise CompileError("syntax error: invalid \\u escape in string literal")
            cp = int(hex1, 16)
            j += 6
            if 0xD800 <= cp < 0xDC00 and src.startswith("\\u", j) and _HEX4.match(src[j + 2:j + 6]):
                low = int(src[j + 2:j + 6], 16)
                if 0xDC00 <= low < 0xE000:
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                    j += 6
            buf.append(chr(cp))
        elif e == "(":
            end = _find_close(src, j + 2)
            if buf:
                parts.append("".join(buf))
                buf = []
            parts.append(("interp", src[j + 2:end]))
            j = end + 1
        else:
            raise CompileError("syntax error: invalid escape \\%s in string literal" % e)
    if buf or not parts:
        parts.append("".join(buf))
    return parts, j + 1


def tokenize(src):
    toks, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in " \t\r\n":
            i += 1
            continue
        if c == "#":
            k = src.find("\n", i)
            i = n if k < 0 else k + 1
            continue
        if c == '"':
            parts, end = _lex_string(src, i)
            toks.append(Tok("STR", parts, i))
            i = end
            continue
        if c in "@$":
            m = _IDENT.match(src, i + 1)
            if not m:
                raise CompileError("syntax error: unexpected '%s' at position %d" % (c, i))
            toks.append(Tok("FMT" if c == "@" else "VAR", m.group(0), i))
            i = m.end()
            continue
        if c == ".":
            if src.startswith("..", i):
                toks.append(Tok("OP", "..", i))
                i += 2
                continue
            m = _IDENT.match(src, i + 1)
            if m:
                toks.append(Tok("FIELD", m.group(0), i))
                i = m.end()
                continue
            if i + 1 < n and "0" <= src[i + 1] <= "9":
                m = _NUMBER.match(src, i)
                toks.append(Tok("NUM", _num_value(m.group(0)), i))
                i = m.end()
                continue
            toks.append(Tok("OP", ".", i))
            i += 1
            continue
        if "0" <= c <= "9":
            m = _NUMBER.match(src, i)
            toks.append(Tok("NUM", _num_value(m.group(0)), i))
            i = m.end()
            continue
        m = _IDENT.match(src, i)
        if m:
            word = m.group(0)
            if src.startswith("::", m.end()):
                raise Unsupported("modules (%s::)" % word)
            toks.append(Tok("KW" if word in _KEYWORDS else "IDENT", word, i))
            i = m.end()
            continue
        for op in _OPS:
            if src.startswith(op, i):
                toks.append(Tok("OP", op, i))
                i += len(op)
                break
        else:
            raise CompileError("syntax error: unexpected character %r at position %d" % (c, i))
    toks.append(Tok("EOF", None, n))
    return toks


def _tokdesc(t):
    if t.kind == "EOF":
        return "end of filter"
    if t.kind == "STR":
        return "string literal"
    if t.kind == "VAR":
        return "$" + t.value
    if t.kind == "FMT":
        return "@" + t.value
    if t.kind == "FIELD":
        return "." + t.value
    return repr(t.value)


_CONSTANTS = {"true": True, "false": False, "null": None}
_CMP = frozenset(["==", "!=", "<", "<=", ">", ">="])
_ASSIGN = frozenset(["=", "|=", "+=", "-=", "*=", "/=", "%=", "//="])
_UNSUPPORTED_KW = {
    "def": "function definitions (def)",
    "label": "label/break",
    "break": "label/break",
    "import": "modules (import)",
    "include": "modules (include)",
    "__loc__": "$__loc__",
}


class Parser(object):
    """Recursive descent over jq's grammar, loosest binding first:
    pipe, comma, //, (assignment: unsupported), or, and, comparison, + -, * / %,
    unary minus, postfix (.a  [i]  [a:b]  []  ?  as $x | body), primary."""

    def __init__(self, src, scope, global_names):
        self.toks = tokenize(src)
        self.i = 0
        self.scope = scope
        self.global_names = global_names

    def peek(self, k=0):
        return self.toks[min(self.i + k, len(self.toks) - 1)]

    def next(self):
        t = self.toks[self.i]
        if t.kind != "EOF":
            self.i += 1
        return t

    def at(self, kind, value=None):
        t = self.toks[self.i]
        return t.kind == kind and (value is None or t.value == value)

    def accept(self, kind, value=None):
        if self.at(kind, value):
            return self.next()
        return None

    def expect(self, kind, value=None):
        if self.at(kind, value):
            return self.next()
        want = value if value is not None else kind.lower()
        raise CompileError("syntax error: expected %s but found %s"
                           % (want, _tokdesc(self.peek())))

    def parse_program(self):
        if self.at("EOF"):
            return Identity()
        node = self.parse_pipe()
        if not self.at("EOF"):
            raise CompileError("syntax error: unexpected %s" % _tokdesc(self.peek()))
        return node

    def parse_pipe(self):
        if self.at("KW", "def"):
            raise Unsupported(_UNSUPPORTED_KW["def"])
        left = self.parse_comma()
        if self.accept("OP", "|"):
            return Pipe(left, self.parse_pipe())
        return left

    def parse_comma(self):
        left = self.parse_alt()
        while self.accept("OP", ","):
            left = Comma(left, self.parse_alt())
        return left

    def parse_alt(self):
        left = self.parse_or()
        t = self.peek()
        if t.kind == "OP" and t.value in _ASSIGN:
            raise Unsupported("assignment operator %s" % t.value)
        if self.accept("OP", "//"):
            return Alt(left, self.parse_alt())
        return left

    def parse_or(self):
        left = self.parse_and()
        while self.accept("KW", "or"):
            left = Or(left, self.parse_and())
        return left

    def parse_and(self):
        left = self.parse_cmp()
        while self.accept("KW", "and"):
            left = And(left, self.parse_cmp())
        return left

    def parse_cmp(self):
        left = self.parse_add()
        t = self.peek()
        if t.kind == "OP" and t.value in _CMP:
            self.next()
            left = Binop(t.value, left, self.parse_add())
            t2 = self.peek()
            if t2.kind == "OP" and t2.value in _CMP:
                raise CompileError("syntax error: comparisons cannot be chained (%s)" % t2.value)
        return left

    def parse_add(self):
        left = self.parse_mul()
        while True:
            t = self.peek()
            if t.kind == "OP" and t.value in ("+", "-"):
                self.next()
                left = Binop(t.value, left, self.parse_mul())
            else:
                return left

    def parse_mul(self):
        left = self.parse_unary()
        while True:
            t = self.peek()
            if t.kind == "OP" and t.value in ("*", "/", "%"):
                self.next()
                left = Binop(t.value, left, self.parse_unary())
            else:
                return left

    def parse_unary(self):
        if self.accept("OP", "-"):
            return Neg(self.parse_unary())
        return self.parse_postfix()

    def _opt(self):
        return self.accept("OP", "?") is not None

    def parse_postfix(self, allow_as=True):
        node = self.parse_primary()
        while True:
            t = self.peek()
            if t.kind == "FIELD":
                self.next()
                node = Index(node, Literal(t.value), self._opt())
                continue
            if t.kind == "OP" and t.value == "." and self.peek(1).kind == "STR":
                self.next()
                node = Index(node, self.string_node(self.next(), None), self._opt())
                continue
            if t.kind == "OP" and t.value == "." and self.peek(1).kind == "OP" \
                    and self.peek(1).value == "[":
                self.next()
                continue
            if t.kind == "OP" and t.value == "[":
                self.next()
                node = self.parse_bracket(node)
                continue
            if t.kind == "OP" and t.value == "?":
                self.next()
                node = Try(node, None)
                continue
            if t.kind == "OP" and t.value == "?//":
                raise Unsupported("?// destructuring alternatives")
            if t.kind == "KW" and t.value == "as" and allow_as:
                self.next()
                name = self.parse_pattern()
                self.expect("OP", "|")
                self.scope.append(name)
                try:
                    body = self.parse_pipe()
                finally:
                    self.scope.pop()
                return Bind(node, name, body)
            return node

    def parse_pattern(self):
        if self.at("OP", "[") or self.at("OP", "{"):
            raise Unsupported("destructuring patterns in 'as'")
        name = self.expect("VAR").value
        if self.at("OP", "?//"):
            raise Unsupported("?// destructuring alternatives")
        return name

    def parse_bracket(self, target):
        if self.accept("OP", "]"):
            return Iterate(target, self._opt())
        if self.accept("OP", ":"):
            hi = self.parse_pipe()
            self.expect("OP", "]")
            return Slice(target, None, hi, self._opt())
        e = self.parse_pipe()
        if self.accept("OP", ":"):
            hi = None
            if not self.at("OP", "]"):
                hi = self.parse_pipe()
            self.expect("OP", "]")
            return Slice(target, e, hi, self._opt())
        self.expect("OP", "]")
        return Index(target, e, self._opt())

    def check_var(self, name):
        if name == "__loc__":
            raise Unsupported(_UNSUPPORTED_KW["__loc__"])
        if name not in self.scope and name not in self.global_names:
            raise CompileError("$%s is not defined" % name)

    def string_node(self, tok, fmt):
        parts = []
        for p in tok.value:
            if isinstance(p, str):
                parts.append(p)
            else:
                parts.append(Parser(p[1], self.scope, self.global_names).parse_program())
        if all(isinstance(p, str) for p in parts):
            return Literal("".join(parts))
        return Interp(parts, fmt)

    def parse_primary(self):
        t = self.next()
        k, v = t.kind, t.value
        if k == "NUM":
            return Literal(v)
        if k == "STR":
            return self.string_node(t, None)
        if k == "FMT":
            if v not in FORMATS:
                raise CompileError("%s is not a valid format" % v)
            if self.at("STR"):
                return self.string_node(self.next(), v)
            return Format(v)
        if k == "FIELD":
            return Index(Identity(), Literal(v), self._opt())
        if k == "VAR":
            self.check_var(v)
            return Var(v)
        if k == "OP":
            if v == ".":
                if self.at("STR"):
                    return Index(Identity(), self.string_node(self.next(), None), self._opt())
                return Identity()
            if v == "..":
                return RecurseAll()
            if v == "(":
                e = self.parse_pipe()
                self.expect("OP", ")")
                return e
            if v == "[":
                if self.accept("OP", "]"):
                    return Collect(None)
                e = self.parse_pipe()
                self.expect("OP", "]")
                return Collect(e)
            if v == "{":
                return self.parse_object()
            if v == "-":
                return Neg(self.parse_postfix())
            raise CompileError("syntax error: unexpected %s" % _tokdesc(t))
        if k == "KW":
            if v == "if":
                return self.parse_if()
            if v == "try":
                body = self.parse_postfix()
                handler = None
                if self.accept("KW", "catch"):
                    handler = self.parse_postfix()
                return Try(body, handler)
            if v in ("reduce", "foreach"):
                return self.parse_fold(v)
            if v in _UNSUPPORTED_KW:
                raise Unsupported(_UNSUPPORTED_KW[v])
            raise CompileError("syntax error: unexpected %s" % _tokdesc(t))
        if k == "IDENT":
            if v in _CONSTANTS and not self.at("OP", "("):
                return Literal(_CONSTANTS[v])
            args = []
            if self.accept("OP", "("):
                args.append(self.parse_pipe())
                while self.accept("OP", ";"):
                    args.append(self.parse_pipe())
                self.expect("OP", ")")
            impl = BUILTINS.get((v, len(args)))
            if impl is None:
                raise Unsupported("%s/%d" % (v, len(args)))
            return Call(impl, args)
        raise CompileError("syntax error: unexpected %s" % _tokdesc(t))

    def parse_if(self):
        cond = self.parse_pipe()
        self.expect("KW", "then")
        then = self.parse_pipe()
        branches = []
        while self.accept("KW", "elif"):
            c = self.parse_pipe()
            self.expect("KW", "then")
            branches.append((c, self.parse_pipe()))
        els = None
        if self.accept("KW", "else"):
            els = self.parse_pipe()
        self.expect("KW", "end")
        for c, b in reversed(branches):
            els = If(c, b, els)
        return If(cond, then, els)

    def parse_fold(self, kind):
        source = self.parse_postfix(allow_as=False)
        self.expect("KW", "as")
        name = self.parse_pattern()
        self.expect("OP", "(")
        init = self.parse_pipe()
        self.expect("OP", ";")
        self.scope.append(name)
        try:
            update = self.parse_pipe()
            extract = None
            if kind == "foreach" and self.accept("OP", ";"):
                extract = self.parse_pipe()
        finally:
            self.scope.pop()
        self.expect("OP", ")")
        if kind == "reduce":
            return Reduce(source, name, init, update)
        return Foreach(source, name, init, update, extract)

    def parse_objval(self):
        # jq allows only pipes of terms here ({a: 1 + 2} is a syntax error there);
        # accepting a full expression without commas is a harmless superset.
        node = self.parse_alt()
        while self.accept("OP", "|"):
            node = Pipe(node, self.parse_alt())
        return node

    def parse_object(self):
        pairs = []
        while not self.accept("OP", "}"):
            t = self.next()
            if t.kind == "VAR":
                self.check_var(t.value)
                if self.at("OP", ":"):
                    raise Unsupported("$variable object keys with a value ({$x: ...})")
                pairs.append((Literal(t.value), Var(t.value)))
            elif t.kind in ("IDENT", "KW"):
                key = Literal(t.value)
                if self.accept("OP", ":"):
                    pairs.append((key, self.parse_objval()))
                else:
                    pairs.append((key, Index(Identity(), key)))
            elif t.kind == "STR":
                key = self.string_node(t, None)
                if self.accept("OP", ":"):
                    pairs.append((key, self.parse_objval()))
                else:
                    pairs.append((key, Index(Identity(), key)))
            elif t.kind == "FMT":
                raise Unsupported("@format object keys")
            elif t.kind == "OP" and t.value == "(":
                key = self.parse_pipe()
                self.expect("OP", ")")
                self.expect("OP", ":")
                pairs.append((key, self.parse_objval()))
            else:
                raise CompileError("syntax error: unexpected %s in object construction"
                                   % _tokdesc(t))
            if not self.accept("OP", ","):
                self.expect("OP", "}")
                break
        return ObjectCons(pairs)


def compile_filter(src, global_names=()):
    return Parser(src, [], frozenset(global_names)).parse_program()


# Input. jq reads a stream of whitespace-separated JSON texts (one document,
# NDJSON, or several on a line) and stops with exit 2 at the first that does
# not parse, after processing the ones before it.

_JSON_WS = re.compile(r"[ \t\r\n]*")


def _reject_constant(name):
    raise ValueError("Invalid literal %s" % name)


def _decode_text(data):
    text = data.decode("utf-8", "replace")
    return text[1:] if text.startswith("\ufeff") else text


def iter_json(text, name):
    dec = json.JSONDecoder(strict=False, parse_constant=_reject_constant)
    i, n = _JSON_WS.match(text, 0).end(), len(text)
    while i < n:
        try:
            v, j = dec.raw_decode(text, i)
        except ValueError as e:
            at = getattr(e, "pos", None)
            at = i if at is None else at
            line = text.count("\n", 0, at) + 1
            col = at - (text.rfind("\n", 0, at) + 1) + 1
            msg = getattr(e, "msg", None) or str(e)
            raise InputError("%s at line %d, column %d (%s)" % (msg, line, col, name))
        yield v
        i = _JSON_WS.match(text, j).end()


def encode_utf8(s):
    try:
        return s.encode("utf-8")
    except UnicodeEncodeError:
        # Lone surrogates from "\ud800"-style escapes: jq prints U+FFFD.
        return s.encode("utf-16", "surrogatepass").decode("utf-16", "replace").encode("utf-8")


class UsageError(Exception):
    """Bad command line (exit 2)."""


class Options(object):
    def __init__(self):
        self.raw = self.join = self.ascii = self.compact = False
        self.null_input = self.slurp = self.exit_status = False
        self.sort_keys = self.raw_input = self.tab = False
        self.indent = 2
        self.named = {}
        self.positional = []
        self.program = None
        self.files = []


_SHORT = {"r": "raw", "j": "join", "a": "ascii", "c": "compact", "n": "null_input",
          "s": "slurp", "e": "exit_status", "S": "sort_keys", "R": "raw_input"}
_LONG = {"raw-output": "raw", "join-output": "join", "ascii-output": "ascii",
         "compact-output": "compact", "null-input": "null_input", "slurp": "slurp",
         "exit-status": "exit_status", "sort-keys": "sort_keys", "raw-input": "raw_input",
         "tab": "tab"}

USAGE = """Usage: jqlite [OPTIONS] FILTER [FILES...]
A jq subset for the ClautoHotkey hooks. Options: -r -j -c -n -s -e -a -S -R -M
--tab --indent n --arg name value --argjson name json --slurpfile name file
--rawfile name file --args --jsonargs -f file
"""


_POSIX_DRIVE = re.compile(r"/(?:mnt/|cygdrive/)?([A-Za-z])(?=/|\Z)")


def native_path(path):
    """Map a Git Bash / Cygwin / WSL spelling to one native Windows Python can open.

    The hooks export MSYS2_ARG_CONV_EXCL='*' so MSYS stops rewriting arguments,
    which means file arguments reach us as /c/Users/..., /tmp/... or /dev/null.
    Those spellings are mapped even when Windows would resolve them as written
    (/dev/null as C:\\dev\\null, a real file on some machines): the caller meant
    the drive and the null device. Elsewhere (Linux, WSL with a Linux python)
    paths are already native.
    """
    if os.name != "nt" or not path.startswith("/") or path.startswith("//"):
        return path
    if path == "/dev/null":
        return os.devnull
    m = _POSIX_DRIVE.match(path)
    if m:
        return m.group(1).upper() + ":" + (path[m.end():] or "/")
    try:
        import subprocess
        out = subprocess.run(["cygpath", "-w", path], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, timeout=5)
        mapped = out.stdout.decode("utf-8", "replace").strip()
        if out.returncode == 0 and mapped:
            return mapped
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return path


def _read_file(path):
    try:
        with open(native_path(path), "rb") as fh:
            return fh.read()
    except (IOError, OSError) as e:
        raise UsageError("Could not open %s: %s" % (path, e.strerror or e))


def parse_args(argv):
    o = Options()
    program_file = None
    pos_mode = None
    loose = []
    i, n = 0, len(argv)
    end_of_options = False

    def take(count, opt):
        if i + count > n:
            raise UsageError("%s takes %d parameter(s)" % (opt, count))
        return argv[i:i + count]

    while i < n:
        a = argv[i]
        i += 1
        if end_of_options or a == "-" or not a.startswith("-"):
            loose.append((a, pos_mode))
            continue
        if a == "--":
            end_of_options = True
            continue
        if a.startswith("--"):
            name = a[2:]
            if name in _LONG:
                setattr(o, _LONG[name], True)
            elif name == "monochrome-output":
                pass
            elif name == "indent":
                (val,) = take(1, a)
                i += 1
                if not val.isdigit() or int(val) > 7:
                    raise UsageError("--indent takes a number between 0 and 7")
                o.indent = int(val)
            elif name in ("arg", "argjson", "slurpfile", "rawfile"):
                var, val = take(2, a)
                i += 2
                if name == "arg":
                    o.named[var] = val
                elif name == "argjson":
                    try:
                        o.named[var] = json.loads(val, parse_constant=_reject_constant)
                    except ValueError:
                        raise UsageError("Invalid JSON text passed to --argjson")
                elif name == "slurpfile":
                    text = _decode_text(_read_file(val))
                    try:
                        o.named[var] = list(iter_json(text, val))
                    except InputError as e:
                        raise UsageError("Bad JSON in --slurpfile %s %s: %s" % (var, val, e))
                else:
                    o.named[var] = _decode_text(_read_file(val))
            elif name == "args":
                pos_mode = "args"
            elif name == "jsonargs":
                pos_mode = "jsonargs"
            elif name == "from-file":
                (program_file,) = take(1, a)
                i += 1
            elif name == "help":
                raise SystemExit(("help", USAGE))
            elif name == "version":
                raise SystemExit(("version", VERSION + "\n"))
            else:
                raise UsageError("unsupported option: %s" % a)
            continue
        letters = a[1:]
        for pos, ch in enumerate(letters):
            if ch in _SHORT:
                setattr(o, _SHORT[ch], True)
            elif ch == "M":
                pass
            elif ch == "f" and pos == len(letters) - 1:
                (program_file,) = take(1, a)
                i += 1
            elif ch == "h":
                raise SystemExit(("help", USAGE))
            elif ch == "V":
                raise SystemExit(("version", VERSION + "\n"))
            else:
                raise UsageError("unsupported option: -%s" % ch)

    if program_file is not None:
        o.program = _decode_text(_read_file(program_file))
    elif loose:
        o.program = loose.pop(0)[0]
    else:
        o.program = "."
    for a, mode in loose:
        if mode == "args":
            o.positional.append(a)
        elif mode == "jsonargs":
            try:
                o.positional.append(json.loads(a, parse_constant=_reject_constant))
            except ValueError:
                raise UsageError("Invalid JSON text passed to --jsonargs")
        else:
            o.files.append(a)
    if o.join:
        o.raw = True
    return o


def _input_values(o, stdin, problems):
    """Yield the input stream. Unopenable files are recorded and skipped (jq
    carries on and exits 2 at the end); unparsable JSON raises InputError."""
    sources = o.files or ["-"]
    for path in sources:
        if path == "-":
            name, data = "<stdin>", stdin.read()
        else:
            name = path
            try:
                data = _read_file(path)
            except UsageError as e:
                problems.append(str(e))
                continue
        CTX.filename = None if path == "-" else path
        text = _decode_text(data)
        if o.raw_input:
            if o.slurp:
                yield text
                continue
            lines = text.split("\n")
            if lines and lines[-1] == "":
                lines.pop()
            for line in lines:
                yield line
        else:
            for v in iter_json(text, name):
                yield v


def main(argv=None, stdin=None, stdout=None, stderr=None):
    argv = sys.argv[1:] if argv is None else list(argv)
    stdin = stdin if stdin is not None else sys.stdin.buffer
    stdout = stdout if stdout is not None else sys.stdout.buffer
    stderr = stderr if stderr is not None else sys.stderr.buffer
    CTX.err = stderr
    CTX.filename = None

    def say(text):
        stderr.write(encode_utf8(text + "\n"))
        stderr.flush()

    try:
        o = parse_args(argv)
    except UsageError as e:
        say("jqlite: " + str(e))
        say("Use jqlite --help for help with command-line options.")
        return 2
    except SystemExit as e:
        stdout.write(encode_utf8(e.code[1]))
        stdout.flush()
        return 0

    env = dict(o.named)
    env["ENV"] = dict(os.environ)
    env["ARGS"] = {"positional": list(o.positional), "named": dict(o.named)}
    try:
        prog = compile_filter(o.program, env.keys())
    except Unsupported as e:
        say("jqlite: unsupported filter: %s (in: %s)" % (e, o.program.strip()))
        say("jqlite: install jq for this filter")
        return 3
    except CompileError as e:
        say("jqlite: error: %s (in: %s)" % (e, o.program.strip()))
        say("jqlite: 1 compile error")
        return 3

    if o.compact or (o.indent == 0 and not o.tab):
        indent = None
    else:
        indent = "\t" if o.tab else o.indent
    state = {"last": _NOTHING, "error": False}

    def emit(v):
        if o.raw and isinstance(v, str) and not o.ascii:
            s = v
        else:
            s = dumps(v, indent, o.sort_keys, o.ascii)
        stdout.write(encode_utf8(s))
        if not o.join:
            stdout.write(b"\n")

    def run(value):
        try:
            for out in prog.ev(value, env):
                emit(out)
                state["last"] = out
        except JQError as e:
            say("jqlite: error (at %s): %s" % (CTX.filename or "<stdin>", e.text()))
            state["error"] = True
        except RecursionError:
            say("jqlite: error: input or filter nested too deeply")
            state["error"] = True

    problems = []
    CTX.inputs = _input_values(o, stdin, problems)
    rc = 0
    try:
        if o.null_input:
            run(None)
        elif o.slurp:
            if o.raw_input:
                run("".join(CTX.inputs))
            else:
                run(list(CTX.inputs))
        else:
            for value in CTX.inputs:
                run(value)
    except InputError as e:
        say("jqlite: parse error: %s" % e)
        rc = 2
    except Unsupported as e:
        say("jqlite: unsupported filter: %s (in: %s)" % (e, o.program.strip()))
        rc = 3
    except Halt as h:
        stdout.flush()
        return h.code
    try:
        stdout.flush()
    except (BrokenPipeError, OSError):
        pass
    for p in problems:
        say("jqlite: error: " + p)
    if rc:
        return rc
    if problems:
        return 2
    if state["error"]:
        return 5
    if o.exit_status:
        last = state["last"]
        if last is _NOTHING:
            return 4
        if last is None or last is False:
            return 1
    return 0


def _cli():
    sys.setrecursionlimit(max(sys.getrecursionlimit(), 6000))
    try:
        code = main()
    except KeyboardInterrupt:
        code = 130
    except BrokenPipeError:
        code = 0
    try:
        sys.stdout.flush()
    except (BrokenPipeError, OSError):
        # The reader went away (jq ... | head -1); silence the shutdown flush.
        try:
            devnull = os.open(os.devnull, os.O_WRONLY)
            os.dup2(devnull, sys.stdout.fileno())
        except OSError:
            pass
    return code


if __name__ == "__main__":
    sys.exit(_cli())
