import 'dart:async';
import 'dart:developer';
import 'dart:math';
import 'dart:io';

import 'package:resource/src/resolve.dart';
import 'package:llama/expr.dart';
import 'package:path/path.dart' as p;

class LineBuffer { // TODO: make this much faster
  LineBuffer(this.raw);
  String raw;
  int offset = 0;
  String get data => raw.substring(offset);
  String read(int len) {
    var o = data.substring(0, len);
    offset += len;
    return o;
  }
  
  Match readPattern(String pattern) {
    var m = new RegExp(pattern).matchAsPrefix(data);
    if (m == null) return null;
    offset += m.group(0).length;
    return m;
  }
  
  String readWord() => readPattern(r"[A-Za-z_]\w*")?.group(0);
  
  void skipWhitespace() {
    while (true) {
      while (data.length != 0 && new RegExp(r"\s").matchAsPrefix(data.substring(0, 1)) != null) offset++;
      if (data.length >= 2 && data.substring(0, 2) == "//") { // comments
        while (data.length > 0 && "\n".matchAsPrefix(data.substring(0, 1)) == null) offset++;
      }
      if (data.length == 0 || new RegExp(r"\s").matchAsPrefix(data.substring(0, 1)) == null) break;
    }
  }
  
  bool checkRead(String x) {
    if (x.length <= data.length && data.substring(0, x.length) == x) {
      offset += x.length;
      return true;
    }
    return false;
  }
}

class ParserError {
  ParserError(this.error, this.where);
  String error;
  SrcRef where;

  toString() => "$error at $where";
}

class DefList {
  DefList(this.out, this.wrap, this.names);
  Expr out;
  Lambda wrap;
  List<String> names = [];
}

class Parser {
  String name;
  LineBuffer b;
  
  SrcRef get srcRef => new SrcRef(name, b.offset);
  
  String readStringLiteral() {
    if (!b.checkRead("\"")) return null;
    var o = "";
    while (!b.checkRead("\"")) {
      if (b.data.length == 0) throw new ParserError("'\"' expected", srcRef);
      var c = b.read(1);
      if (c == "\\") {
        var np = b.readPattern(r"(o[0-7]+|b[0-1]+|x[0-9A-Fa-f]+|[0-9]+)");
        if (np != null) {
          var pf = np.group(0).substring(0, 1);
          var str = pf == "x" || pf == "b" || pf == "o" ? np.group(0).substring(1) : np.group(0);
          o += new String.fromCharCode(int.parse(str, radix: pf == "x" ? 16 : pf == "b" ? 2 : pf == "o" ? 8 : 10));
        } else {
          var e = b.read(1);
          if (!escapeChars.containsKey(e)) throw new ParserError("Unexpected escape symbol", srcRef);
          o += escapeChars[e];
        }
      } else {
        o += c;
      }
    }
    return o;
  }
  
  int readInt() {
    var np = b.readPattern(r"(0o[0-7]+|0b[0-1]+|0x[0-9A-Fa-f]+|[0-9]+)");
    if (np == null) return null;
    var pf = np.group(0).length > 2 ? np.group(0).substring(1, 2) : "";
    var str = pf == "x" || pf == "b" || pf == "o" ? np.group(0).substring(2) : np.group(0);
    return int.parse(str, radix: pf == "x" ? 16 : pf == "b" ? 2 : pf == "o" ? 8 : 10);
  }
  
  Lambda readCharLiteral(bool signed, bool neg) {
    if (b.checkRead("\\")) {
      var i = readInt();
      if (i == null) {
        var e = b.read(1);
        if (!escapeChars.containsKey(e)) throw new ParserError("Unknown escape", srcRef);
        if (!b.checkRead("'")) throw new ParserError("\"'\" expected", srcRef);
        return new Lambda.fromInt(escapeChars[e].codeUnitAt(0) * (neg ? -1 : 1), signed);
      }
      var o = new Lambda.fromInt(readInt() * (neg ? -1 : 1), signed);
      if (!b.checkRead("'")) throw new ParserError("\"'\" expected", srcRef);
      return o;
    } else {
      var e = b.read(1);
      if (!b.checkRead("'")) throw new ParserError("\"'\" expected", srcRef);
      return new Lambda.fromInt(e.codeUnitAt(0) * (neg ? -1 : 1), signed);
    }
  }
  
  Future<File> findSourceFile(String name) async {
    var tryDirs = [
      (await resolveUri(Uri.parse("package:llama/stl"))).path,
    ];

    for (var tr in tryDirs) {
      var ps = p.normalize(tr + "/" + name);
      if (!p.isWithin(tr, ps)) continue;
      var f = new File(ps);
      if (await f.exists()) return f;
    }
    return null;
  }
  
  Future<Expr> readExpr() async {
    b.skipWhitespace();
    if (b.checkRead("\\")) {
      var imf = readStringLiteral();
      if (imf != null) {
      } else {
        String name = b.readWord();
        if (name == null) throw new ParserError(
          "Name expected", srcRef);
        b.skipWhitespace();
        return new Lambda(name, await readBody());
      }
    } else if (b.checkRead("(")) {
      var expr = await readBody();
      if (expr == null) throw new ParserError(
        "Expression expected", srcRef);
      b.skipWhitespace();
      if (!b.checkRead(")")) throw new ParserError(
        "')' expected", srcRef);
      return expr;
    } else if (b.checkRead("~")) {
      var expr = await readBody();
      if (expr == null) throw new ParserError(
        "Expression expected", srcRef);
      return expr;
    } else if (b.data.length > 0 && b.data.substring(0, 1) == "\"") {
      var o = readStringLiteral();
      if (o.length == 0) return new Lambda("f", new Lambda("e", new Variable("e")));
      var rv = o.codeUnits.reversed.toList();
      return new Lambda("f", new Lambda("e",
        rv.skip(1).fold(
          new Application(
            new Application(new Variable("f"), new Lambda.fromInt(rv[0])),
            new Variable("e")
          ),
          (prev, e) => new Application(
              new Application(new Variable("f"), new Lambda.fromInt(e)), prev)
        )
      ));
    } else if (b.checkRead("[")) {
      List<Expr> e = [];
      b.skipWhitespace();
      while (!b.checkRead("]")) {
        if (b.data.length == 0) throw new ParserError("']' expected", srcRef);
        var exp = await readExpr();
        if (exp == null) throw new ParserError("Expression expected", srcRef);
        e.add(exp);
        if (!b.checkRead(",") && (b.data.length == 0 && b.data[b.data.length - 1] != ",")) throw new ParserError("',' expected", srcRef);
        b.skipWhitespace();
      }
      var lname = "l";
      while (e.any((exp) => exp.containsVar(lname))) lname += "_";
      var fname = "f";
      while (e.any((exp) => exp.containsVar(fname))) fname += "_";
      Expr o = new Variable(lname);
      e.reversed.forEach((exp) {
        o = new Application(new Application(new Variable(fname), exp), o);
      });
      if (fname != "f" || lname != "l") {
        return new Application(
          new Lambda("x", new Lambda("f", new Lambda("l", new Application(new Application(new Variable("x"), new Variable("f")), new Variable("l"))))),
          new Lambda(fname, new Lambda(lname, o))
        );
      }
      return new Lambda("f", new Lambda("l", o));
    } else if (b.checkRead("<")) {
      List<Expr> e = [];
      b.skipWhitespace();
      while (!b.checkRead(">")) {
        if (b.data.length == 0) throw new ParserError("'>' expected", srcRef);
        var exp = await readExpr();
        if (exp == null) throw new ParserError("Expression expected", srcRef);
        e.add(exp);
        if (!b.checkRead(",") && (b.data.length == 0 && b.data[b.data.length - 1] != ",")) throw new ParserError("',' expected", srcRef);
        b.skipWhitespace();
      }
      var tname = "tpl";
      while (e.any((exp) => exp.containsVar(tname))) tname += "_";
      Expr o = new Variable(tname);
      e.forEach((exp) {
        o = new Application(o, exp);
      });
      if (tname != "tpl") {
        return new Application(new Lambda("x", new Lambda("tpl", new Application(new Variable("x"), new Variable("tpl")))), new Lambda(tname, o));
      }
      return new Lambda("tpl", o);
    } else if (b.checkRead("+") || b.checkRead("-")) {
      var sign = b.raw.substring(b.offset - 1, b.offset);
      if (b.checkRead("'")) return readCharLiteral(true, sign == "-");
      int n = readInt();
      if (n == null) throw new ParserError("Number expected", srcRef);
      return new Lambda.fromInt(n * (sign == "-" ? -1 : 1), true);
    } else if (b.checkRead("'")) {
      return readCharLiteral(false, false);
    } else {
      int n;
      String v;
      if ((n = readInt()) != null) {
        return new Lambda.fromInt(n);
      } else if ((v = b.readWord()) != null) {
        return new Variable(v);
      } else {
        return null;
      }
    }
  }
  
  Future<DefList> readDefs() async {
    b.skipWhitespace();
    Expr out;
    Lambda wrap;
    List<String> names = [];
    while (true) {
      if (b.checkRead("~\\\"")) {
        b.offset--;
        var imf = readStringLiteral();
        var f = await findSourceFile(imf);
        if (f == null) throw new ParserError("Could not find $imf", srcRef);
        var ndefs = await new Parser().importFile(f);
        if (ndefs.out != null) {
          if (out == null) {
            wrap = ndefs.wrap;
            out = ndefs.out;
          } else {
            wrap.body = ndefs.out;
            wrap = ndefs.wrap;
          }
        }
        names.addAll(ndefs.names);
      } else if (b.checkRead("~\\")) {
        String name = b.readWord();
        names.add(name);
        if (name == null) throw new ParserError("Name expected", srcRef);
        b.skipWhitespace();
        var e = await readExpr();
        if (e == null) throw new ParserError("Expression expected", srcRef);
        if (out == null) {
          wrap = new Lambda(name, null);
          out = new Application(wrap, e);
        } else {
          var w = new Lambda(name, null);
          wrap.body = new Application(w, e);
          wrap = w;
        }
      } else {
        break;
      }
      b.skipWhitespace();
    }
    return new DefList(out, wrap, names);
  }
  
  Future<Expr> readBody() async {
    var defs = await readDefs();
    
    List<Expr> exprs = [];
    while (true) {
      var e = await readExpr();
      if (e == null) break;
      exprs.add(e);
    }
    if (exprs.length == 0) throw new ParserError("Expression expected", srcRef);
    
    Expr expr;
    if (exprs.length == 1) {
      expr = exprs[0];
    } else {
      expr = exprs.skip(1).fold(exprs[0], (prev, c) => new Application(prev, c));
    }
    
    if (defs.out == null) {
      return expr;
    } else {
      defs.wrap.body = expr;
      return defs.out;
    }
  }
  
  Future<DefList> importFile(File f) async {
    sourceFile = f;
    name = f.uri.toString();
    b = new LineBuffer(await f.readAsString());
    var d = await readDefs();
    if (b.data.length != 0) throw new ParserError("EOF expected near ${b.data}", srcRef);
    return d;
  }
  
  File sourceFile;
  
  Future<Expr> parseFile(File f) async {
    sourceFile = f;
    name = f.uri.toString();
    return parse(name, await f.readAsString());
  }
  
  Future<Expr> parse(String cname, String str) async {
    name = cname;
    b = new LineBuffer(str);
    var body = await readBody();
    b.skipWhitespace();
    if (b.data.length != 0) throw new ParserError("EOF expected", srcRef);
    return body;
  }
}

class Lazy<T> {
  Lazy(this._cb);
  T _val;
  LazyCallback _cb;
  bool _complete = false;
  T get val {
    if (!_complete) {
      _val = _cb();
      _cb = null;
      _complete = true;
    }
    return _val;
  }
}

class VarUse {
  VarUse(this.parent, this.v);
  Expr parent;
  Variable v;
}

typedef Expr ExprGenerator();