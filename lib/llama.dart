import 'dart:developer';
import 'dart:math';
import 'dart:io';

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

class SrcRef {
  SrcRef(this.chunkname, this.pos);
  String chunkname;
  int pos;
}

abstract class Expr {
  String toString([Expr parent, bool first]);
  SrcRef src;
  
  void bind([List<Lambda> stack]) {
    stack ??= [];
    var t = this;
    if (t is Lambda) {
      stack.add(t);
      t.body.bind(stack);
      stack.removeLast();
    } else if (t is Application) {
      t.lambda.bind(stack);
      t.param.bind(stack);
    } else if (t is Variable) {
      var lb = stack.lastWhere((l) => l.param == t.name, orElse: () => null);
      if (lb != null) {
        t.bound = (stack.length - 1) - stack.indexOf(lb);
      }
    } else throw "Unknown type";
  }
  
  bool containsVar(String name) {
    var t = this;
    if (t is Lambda) {
      return t.param != name && t.body.containsVar(name);
    } else if (t is Application) {
      return t.param.containsVar(name) || t.lambda.containsVar(name);
    } else if (t is Variable) {
      return t.name == name;
    } else throw "Unknown type";
  }
  
  Expr copy();
  
  List<Expr> get children;
  set children(List<Expr> c);
}

class Lambda extends Expr {
  copy() => new Lambda(param, body.copy());
  get children => [body];
  set children(List<Expr> c) => body = c[0];
  
  factory Lambda.fromInt(int i, [bool signed = false]) {
    if (signed) {
      return new Lambda("sgn", new Application(
        new Application(new Variable("sgn"), new Lambda.fromInt(max(0, i))),
      new Lambda.fromInt(max(0, -i))));
    }
    Expr o = new Variable("x");
    for (int j = 0; j < i; j++) {
      o = new Application(new Variable("f"), o);
    }
    return new Lambda("f", new Lambda("x", o));
  }
  Lambda(this.param, this.body);
  String param;
  Expr body;
  
  String toString([Expr parent, bool first]) {
    int n;
    String str;
    List<Expr> vt;
    bool b;

    if ((n = toNumber()) != null) {
      return n.toString();
    } else if ((n = toSigned()) != null) {
      return "${n >= 0 ? "+" : ""}$n";
    } else if ((str = toRawString()) != null) {
      return "\"${str.split("").map((c) {
        if (revEscapeChars.containsKey(c)) {
          return revEscapeChars[c];
        } else if (new RegExp(r"[ -~]").matchAsPrefix(c) == null) {
          return "\\${c.codeUnitAt(0)}";
        } else {
          return c;
        }
      }).join()}\"";
    } else if ((vt = toVector()) != null) {
      return "[${vt.map((e) => e.toString(new Application(e, null))).join(" ")}]";
    } else if ((b = toBool()) != null) {
      return b.toString();
    } else if ((vt = toTuple()) != null) {
      return "<${vt.map((e) => e.toString(new Application(e, null))).join(" ")}>";
    }
    
    if (parent == null || parent is Lambda) {
      var ob = this;
      String o = "";
      while (ob is Lambda) {
        o = "$o${o.length == 0 ? "" : " "}${ob.param}";
        ob = ob.body;
      }
      return "λ$o.${ob.toString(this)}";
    }
    return "($this)";
  }
  
  int toNumber() {
    if (param != "f") return null;
    if (body is! Lambda || (body as Lambda).param != "x") return null;
    if ((body as Lambda).body is Variable && ((body as Lambda).body as Variable).bound == 0) return 0;
    if ((body as Lambda).body is! Application) return null;
    int i = 1;
    Application ca = (body as Lambda).body;
    while (true) {
      if (ca.lambda is! Variable || (ca.lambda as Variable).bound != 1) return null;
      if (ca.param is Variable && (ca.param as Variable).bound == 0) break;
      if (ca.param is! Application) return null;
      i++;
      ca = ca.param;
    }
    return i;
  }
  
  int toSigned() {
    var elm = toTuple("sgn");
    if (elm == null) return null;
    if (elm.length != 2 || elm[0] is! Lambda || elm[1] is! Lambda) return null;
    var a = (elm[0] as Lambda).toNumber();
    if (a == null) return null;
    var b = (elm[1] as Lambda).toNumber();
    if (b == null) return null;
    return a - b;
  }

  String toRawString() {
    if (param != "f") return null;
    if (body is! Lambda || (body as Lambda).param != "e") return null;
    var vn = (body as Lambda).param;
    if ((body as Lambda).body is Variable && ((body as Lambda).body as Variable).bound == 0) return "";
    if ((body as Lambda).body is! Application) return null;
    String o = "";
    Application ca = (body as Lambda).body;
    while (true) {
      if (ca.lambda is! Application) return null;
      var f = (ca.lambda as Application).lambda;
      if (f is! Variable || (f as Variable).bound != 1) return null;
      if ((ca.lambda as Application).param is! Lambda) return null;
    
      var num = ((ca.lambda as Application).param as Lambda).toNumber();
      if (num == null) return null;
      o += new String.fromCharCode(num);
    
      if (ca.param is Variable && (ca.param as Variable).bound == 0) break;
      if (ca.param is! Application) return null;
      ca = ca.param;
    }
    return o;
  }
  
  List<Expr> toVector() {
    if (param != "f") return null;
    if (body is! Lambda || (body as Lambda).param != "l") return null;
    var vn = (body as Lambda).param;
    if ((body as Lambda).body is Variable &&
      ((body as Lambda).body as Variable).bound == 0) return [];
    if ((body as Lambda).body is! Application) return null;
    List<Expr> o = [];
    Application ca = (body as Lambda).body;
    while (true) {
      if (ca.lambda is! Application) return null;
      var f = (ca.lambda as Application).lambda;
      if (f is! Variable || (f as Variable).bound != 1) return null;
    
      if (num == null) return null;
      o.add((ca.lambda as Application).param);
    
      if (ca.param is Variable && (ca.param as Variable).bound == 0) break;
      if (ca.param is! Application) return null;
      ca = ca.param;
    }
    return o;
  }
  
  List<Expr> toTuple([String tpnm = "tpl"]) {
    if (param != tpnm) return null;
    if (body is Variable && (body as Variable).bound == 0) return [];
    if (body is! Application) return null;
    List<Expr> o = [];
    var ap = body as Application;
    while (true) {
      o.insert(0, ap.param);
      if (ap.lambda is Variable) {
        if ((ap.lambda as Variable).name == tpnm) break; else return null;
      }
      if (ap.lambda is! Application) return null;
      ap = ap.lambda as Application;
    }
    
    // Just incase someone does something stupid like `\tpl tpl (foo tpl)` prevent that from turning into `<(foo tpl)>`, which is invalid
    List<Expr> stack = [];
    bool search(Expr e) {
      if (e is Lambda) {
        stack.add(e);
        var res = search(e.body);
        stack.removeLast();
        return res;
      } else if (e is Application) {
        return search(e.lambda) || search(e.param);
      } else if (e is Variable) {
        return e.bound == stack.length;
      } else throw "Unknown type";
    }
    if (o.any((e) => search(e))) return null;
    
    return o;
  }
  
  // \tpl (((tpl a) b) c) d
  
  bool toBool() {
    if (param != "t") return null;
    if (body is! Lambda || (body as Lambda).param != "f") return null;
    var bd = body as Lambda;
    if (bd.body is! Variable) return null;
    var vr = bd.body as Variable;
    if (vr.bound == 0) return false;
    if (vr.bound == 1) return true;
    return null;
  }
}

class Application extends Expr {
  Application(this.lambda, this.param);
  
  copy() => new Application(lambda.copy(), param.copy());
  get children => [lambda, param];
  set children(List<Expr> c) {
    lambda = c[0];
    param = c[1];
  }
  
  Expr lambda;
  Expr param;
  
  String toString([Expr parent, bool first = false]) {
    if (parent == null || parent is Lambda || first) {
      return "${lambda.toString(this, true)} ${param is Lambda && parent is! Application ? param : param.toString(this)}";
    }
    return "(${lambda.toString(this, true)} ${parent is Lambda ? param : param.toString(this)})";
  }
}

class Variable extends Expr {
  Variable(this.name);
  
  copy() => new Variable(name)..bound = bound;
  get children => [];
  set children(List<Expr> ch) {}
  
  String name;
  int bound;
  int level;
  toString([Expr parent, bool first = false]) => name;
}

class Deferred extends Expr {
  Deferred(this._cb);
  Expr _e;
  LazyCallback<Expr> _cb;
  Expr get re {
    var o = _e ?? (_e = _cb());
    _cb = null;
    return o;
  }
  
  List<Expr> get children => re.children;
  set children(List<Expr> n) => re.children = n;
  Expr copy() => re.copy();
  toString([Expr parent, bool first = false]) => re.toString(parent, first);
}

class ParserError {
  ParserError(this.error, this.where);
  String error;
  SrcRef where;
}

const Map<String, String> escapeChars = const {
  "a": "\x07",
  "b": "\b",
  "f": "\f",
  "n": "\n",
  "r": "\r",
  "t": "\t",
  "v": "\v",
  "\\": "\\",
  "\"": "\"",
};

const Map<String, String> revEscapeChars = const {
  "\x07": "\\a",
  "\b": "\\b",
  "\f": "\\f",
  "\n": "\\n",
  "\r": "\\r",
  "\t": "\\t",
  "\v": "\\v",
  "\"": "\\\"",
};

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
  
  File findSourceFile(String name) {
    for (var tr in tryDirs) {
      var f = new File(tr + "/" + name);
      if (f.existsSync()) return f;
    }
    return null;
  }
  
  Expr readExpr() {
    b.skipWhitespace();
    if (b.checkRead("\\")) {
      var imf = readStringLiteral();
      if (imf != null) {
      } else {
        String name = b.readWord();
        if (name == null) throw new ParserError(
          "Name expected", srcRef);
        b.skipWhitespace();
        return new Lambda(name, readBody());
      }
    } else if (b.checkRead("(")) {
      var expr = readBody();
      if (expr == null) throw new ParserError(
        "Expression expected", srcRef);
      b.skipWhitespace();
      if (!b.checkRead(")")) throw new ParserError(
        "')' expected", srcRef);
      return expr;
    } else if (b.checkRead("~")) {
      var expr = readBody();
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
        var exp = readExpr();
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
        var exp = readExpr();
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

  var tryDirs = [Directory.current.path + "/stl"];
  
  DefList readDefs() {
    b.skipWhitespace();
    Expr out;
    Lambda wrap;
    List<String> names = [];
    while (true) {
      if (b.checkRead("~\\\"")) {
        b.offset--;
        var imf = readStringLiteral();
        var f = findSourceFile(imf);
        if (f == null) throw new ParserError("Could not find $imf", srcRef);
        var ndefs = new Parser().importFile(f);
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
        var e = readExpr();
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
  
  Expr readBody() {
    var defs = readDefs();
    
    List<Expr> exprs = [];
    while (true) {
      var e = readExpr();
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
  
  DefList importFile(File f) {
    sourceFile = f;
    tryDirs = (sourceFile.uri.pathSegments.toList()..removeLast());
    name = f.uri.toString();
    b = new LineBuffer(f.readAsStringSync());
    var d = readDefs();
    if (b.data.length != 0) throw new ParserError("EOF expected near ${b.data}", srcRef);
    return d;
  }
  
  File sourceFile;
  
  Expr parseFile(File f) {
    sourceFile = f;
    name = f.uri.toString();
    return parse(name, f.readAsStringSync());
  }
  
  Expr parse(String cname, String str) {
    name = cname;
    b = new LineBuffer(str);
    var body = readBody();
    b.skipWhitespace();
    if (b.data.length != 0) throw new ParserError("EOF expected", srcRef);
    return body;
  }
}

typedef T LazyCallback<T>();

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

abstract class Solver {
  Solver(this.expr);
  Expr expr;
  void solve();
  
  Expr copyShift(Expr e, int shift) {
    var c = e.copy();
    List<Lambda> stack = [];
    void step(Expr e) {
      if (e is Lambda) {
        stack.add(e);
        step(e.body);
        stack.removeLast();
      } else if (e is Application) {
        step(e.lambda);
        step(e.param);
      } else if (e is Variable) {
        if (e.bound != null && e.bound >= stack.length) {
          e.bound += shift;
          if (e.bound < stack.length) throw "Invalid rebind";
        }
      } else throw "Unknown type";
    }
    step(c);
    return c;
  }
}

class VarUse {
  VarUse(this.parent, this.v);
  Expr parent;
  Variable v;
}

typedef Expr ExprGenerator();

class TrashSolver extends Solver {
  TrashSolver(Expr expr) : super(expr);
  
  void solve() {
    bool contStep = true;
    Lambda forceDown = null;
    var complexity = 0;
    var ops = 0;
    Set<Lambda> required = new Set<Lambda>();
    List<Lambda> stack = [];
    List<Application> aplStack = [];
    Expr step(Expr e) {
      complexity++;
      if (e is Lambda) {
        if (forceDown != null) return e;
        stack.add(e);
        e.body = step(e.body);
        stack.removeLast();
        return e;
      } else if (e is Application) {
        if (forceDown == null) {
          var oc = contStep;
          var ac = false;
          aplStack.add(e);
          while (true) {
            contStep = false;
            e.lambda = step(e.lambda);
            ac = contStep;
            if (!contStep) break;
          }
          aplStack.removeLast();
          contStep = oc || ac;
          
          if (e.lambda is Variable && (e.lambda as Variable).bound != null) {
            var vr = e.lambda as Variable;
            var down = stack[stack.length - (1 + vr.bound)];
            if (aplStack.any((apl) => apl.lambda == down)) {
              contStep = true;
              forceDown = down;
              return e;
            }
          }
        }
        
        if (forceDown != null && forceDown != e.lambda) {
          return e;
        } else if (e.lambda is Lambda) {
          forceDown = null;
          var param = new Deferred(() {
            aplStack.add(e);
            var o = e.param = step(e.param);
            aplStack.removeLast();
            return o;
          });//e.param;
          contStep = true;
          List<Lambda> stack = [];
          Expr rcrCopy(Expr te) {
            if (te is Lambda) {
              stack.add(te);
              te.body = rcrCopy(te.body);
              stack.removeLast();
            } else if (te is Application) {
              te.param = rcrCopy(te.param);
              te.lambda = rcrCopy(te.lambda);
            } else if (te is Variable) {
              if (te.bound == stack.length) {
                ops++;
                return copyShift(param, stack.length);
              } else if (te.bound != null && te.bound > stack.length) {
                te.bound--;
              }
            }
            return te;
          }
          return rcrCopy((e.lambda as Lambda).body);
        } else if (!contStep) {
          //print("stepping param");
          aplStack.add(e);
          e.param = step(e.param);
          aplStack.removeLast();
        }
        
        return e;
      } else if (e is Variable) {
        //if (e.bound == null) throw "k ${e.name}";
        return e;
      } else if (e is Deferred) {
        return e.re;
      } else throw "Unknown type";
    }
    
    while (contStep) {
      contStep = false;
      ops = 0;
      forceDown = null;
      required = new Set<Lambda>();
      //print("step ${complexity}");
      //print(expr);
      complexity = 0;
      try {
        expr = step(expr);
      } on StackOverflowError catch(e) {
        print("Stack overflow!");
        contStep = false;
      }
    }
  }
}

class TraceSolver extends Solver {
  TraceSolver(Expr expr) : super(expr);
  
  void solve() {
    bool contStep = true;
    bool forceDown = false;
    var complexity = 0;
    var ops = 0;
    Expr step(Expr e) {
      complexity++;
      if (e is Lambda) {
        if (forceDown) return e;
        e.body = step(e.body);
        return e;
      } else if (e is Application) {
        return e;
      } else if (e is Variable) {
        if (e.bound == null) {
          throw "die";
        }
        return e;
      } else if (e is Deferred) {
        return e.re;
      } else throw "Unknown type";
    }
    
    while (contStep && !forceDown) {
      contStep = false;
      complexity = 0;
      ops = 0;
      try {
        expr = step(expr);
      } on StackOverflowError catch(e) {
        print("Stack overflow!");
        contStep = true;
      }
    }
  }
}
