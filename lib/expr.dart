import 'dart:math';

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

class SrcRef {
  SrcRef(this.chunkname, this.pos);
  String chunkname;
  int pos;

  toString() => "$chunkname:$pos";
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
      Expr ob = this;
      String o = "";
      while (ob is Lambda) {
        Lambda obl = ob;
        o = "$o${o.length == 0 ? "" : " "}${obl.param}";
        ob = obl.body;
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

    // Just in case someone does like `\tpl tpl (foo tpl)` prevent that from turning into `<(foo tpl)>`, which is invalid
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

typedef T LazyCallback<T>();

class Deferred extends Expr {
  Deferred(this._cb);
  Expr value;
  LazyCallback<Expr> _cb;
  Expr get re {
    var o = value ?? (value = _cb());
    _cb = null;
    return o;
  }

  List<Expr> get children => re.children;
  set children(List<Expr> n) => re.children = n;
  Expr copy() => re.copy();
  toString([Expr parent, bool first = false]) => re.toString(parent, first);
}

abstract class Solver {
  Solver(this.expr);
  Expr expr;
  Future solve();

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