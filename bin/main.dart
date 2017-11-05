// Copyright (c) 2017, Andre Lipke. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:lambdafuck/llama.dart';

main(List<String> arguments) async {
  try {
    var t1 = new DateTime.now();
    var parser = new Parser();
    var expr = parser.parseFile(new File("examples/test.lf"));
    expr.bind();
    var solver = new TrashSolver(expr);
    solver.solve();
    print(solver.expr);
    print((new DateTime.now().millisecondsSinceEpoch - t1.millisecondsSinceEpoch) / 1000.0);
  } on ParserError catch (e) {
    print("${e.where.chunkname}:${e.where.pos} : ${e.error}");
    return null;
  }
}
