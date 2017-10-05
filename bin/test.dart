// Copyright (c) 2017, pixel. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'package:lambdafuck/llama.dart';
import 'package:worker/worker.dart';

const Map<String, String> tests = const {
  'while 0 (\\i iIsNEQ (iMul i 2) 8) (\\i iSucc i)': '4',
  
  '[(true 1 2) (false 1 2)]': '[1 2]',
  '[(bNot false) (bNot true)]': '[true false]',
  '[(bAnd false false) (bAnd false true) (bAnd true false) (bAnd true true)]': '[false false false true]',
  '[(bOr false false) (bOr false true) (bOr true false) (bOr true true)]': '[false true true true]',
  '[(bXor false false) (bXor false true) (bXor true false) (bXor true true)]': '[false true true false]',
  
  '[(iSucc 0) (iSucc 7)]': '[1 8]',
  '[(iPred 0) (iPred 1) (iPred 8)]': '[0 0 7]',
  '[(iAdd 0 0) (iAdd 0 5) (iAdd 6 9)]': '[0 5 15]',
  '[(iSub 0 0) (iSub 0 5) (iSub 13 6)]': '[0 0 7]',
  '[(iMul 0 0) (iMul 1 7) (iMul 20 21)]': '[0 7 420]',
  //'[(iDiv 0 0) (iDiv 1 7) (iDiv 10 2)]': '[0 0 5]',
  '[(iPow 0 0) (iPow 2 8) (iPow 10 3)]': '[1 256 1000]',
  '[(iIsZero 0) (iIsZero 1) (iIsZero 2)]': '[true false false]',
  '[(iIsEQ 0 0) (iIsEQ 1 2) (iIsEQ 3 3)]': '[true false true]',
  '[(iIsNEQ 0 0) (iIsNEQ 1 2) (iIsNEQ 3 3)]': '[false true false]',
  '[(iIsGT 0 0) (iIsGT 6 9) (iIsGT 9 6)]': '[false false true]',
  '[(iIsLT 0 0) (iIsLT 6 9) (iIsLT 9 6)]': '[false true false]',
  '[(iIsGE 0 0) (iIsGE 6 9) (iIsGE 9 6)]': '[true false true]',
  '[(iIsLE 0 0) (iIsLE 6 9) (iIsLE 9 6)]': '[true true false]',
  
  '[(tTuple 4 a b c d) (tTuple 2 a b) (tTuple 0)]': '[<a b c d> <a b> <>]',
  '[(tVector 0 <>) (tVector 1 <a>) (tVector 3 <a b c>)]': '[[] [a] [a b c]]',
  '[\n'
    '(tGet 4 0 a b c d)\n'
    '(tGet 3 2 a b c)\n'
    '(tGet 1 0 a)\n'
    ']' : '[a c a]',
  '[\n'
    '(tVararg 4 (\\v v) a b c d)\n'
    '(tVararg 0 (\\v v))\n'
    '(tVararg 3 (\\v vMap v iSucc) 2 3 4)\n'
    ']' : '[[a b c d] [] [3 4 5]]',
  '[\n'
    '(tSet 3 <0 1 2> 0 1)\n'
    '(tSet 4 <0 1 2 3> 4 1)\n'
    '(tSet 5 <0 1 2 3 4> 4 5)\n'
    ']' : '[<1 1 2> <0 1 2 3> <0 1 2 3 5>]',
  
  '[\n'
    '(vFold [] 0 iAdd)\n'
    '(vFold [1 2 3] 0 iAdd)\n'
    '(vFold [1 2 3] 2 iMul)\n'
    ']' : '[0 6 12]',
  '[\n'
    '(vConcat [] [])\n'
    '(vConcat [0 1 2] [3 4 5])\n'
    '(vConcat [] [4 2 0])\n'
    ']' : '[[] [0 1 2 3 4 5] [4 2 0]]',
  '[\n'
    '(vExpand [] (\\e []))\n'
    '(vExpand [0 1 2 3 4 5] (\\e iIsGT e 3 [e] []))\n'
    '(vExpand [1 5 9] (\\e [e (iSucc e)]))\n'
    ']' : '[[] [4 5] [1 2 5 6 9 10]]',
  '[\n'
    '(vInsertStart [] 0)\n'
    '(vInsertStart [1 2] 0)\n'
    '(vInsertStart [2 4 0] 0)\n'
    ']' : '[[0] [0 1 2] [0 2 4 0]]',
  '[\n'
    '(vInsertEnd [] 0)\n'
    '(vInsertEnd [1 2] 0)\n'
    '(vInsertEnd [2 4 0] 0)\n'
    ']' : '[[0] [1 2 0] [2 4 0 0]]',
  '[\n'
    '(vLength [])\n'
    '(vLength [1 2])\n'
    '(vLength [2 4 0 3 1])\n'
    ']' : '[0 2 5]',
  '[\n'
    '(vFirstWhere [] (\\e true) 0)\n'
    '(vFirstWhere [1 2 3] (\\e true) 0)\n'
    '(vFirstWhere [1 2 3 4 5] (\\e iIsGT e 3) 0)\n'
    ']' : '[0 1 4]',
  '[\n'
    '(vTake [] 1)\n'
    '(vTake [1 2 3] 6)\n'
    '(vTake [1 2 3 4 5] 4)\n'
    ']' : '[[] [1 2 3] [1 2 3 4]]',
  '[\n'
    '(vSkip [] 1)\n'
    '(vSkip [1 2 3] 6)\n'
    '(vSkip [1 2 3 4 5] 2)\n'
    ']' : '[[] [] [3 4 5]]',
  '[\n'
    '(vGet [] 1 0)\n'
    '(vGet [1 2 3] 0 0)\n'
    '(vGet [1 2 3 4 5] 4 0)\n'
    ']' : '[0 1 5]',
  '[\n'
    '(vWhere [0 1 2] (\\e false))\n'
    '(vWhere [1 2 3 4 5 6] (\\e iIsGT e 3))\n'
    '(vWhere [0 1 0 3 5 0] iIsZero)\n'
    ']' : '[[] [4 5 6] [0 0 0]]',
  '[\n'
    '(vFoldMap [2 1 2 1] 0 \\st\\e <(iSucc st) (iAdd st e)>)\n'
    '(vFoldMap [4 5 6 7] 1 \\st\\e <e (iAdd st e)>)\n'
    '(vFoldMap [4 5 6 7] 1 \\st\\e <e (iMul st e)>)\n'
    ']' : '[[2 2 4 4] [5 9 11 13] [4 20 30 42]]',
  '[\n'
    '(vIndexify [])\n'
    '(vIndexify [0 1 2])\n'
    '(vIndexify [4 1 2 0])\n'
    ']' : '[[] [<0 0> <1 1> <2 2>] [<0 4> <1 1> <2 2> <3 0>]]',
  '[\n'
    '(vSet [0 1 2] 0 1)\n'
    '(vSet [0 1 2 3] 4 1)\n'
    '(vSet [0 1 2 3 4] 4 5)\n'
    ']' : '[[1 1 2] [0 1 2 3] [0 1 2 3 5]]',
  '[\n'
    '(vReverse [])\n'
    '(vReverse [0 1 2])\n'
    '(vReverse [6 9 6 9])\n'
    ']' : '[[] [2 1 0] [9 6 9 6]]',
  '[\n'
    '(vGenerate 0 1)\n'
    '(vGenerate 1 2)\n'
    '(vGenerate 3 3)\n'
    ']' : '[[] [2] [3 3 3]]',
  '[\n'
    '(vIsEmpty [])\n'
    '(vIsEmpty [1])\n'
    '(vIsEmpty [1 2 3])\n'
    ']' : '[true false false]',
  '[\n'
    '(vRemoveLast [])\n'
    '(vRemoveLast [1])\n'
    '(vRemoveLast [1 2 3])\n'
    ']' : '[[] [] [1 2]]',
  '[\n'
    '(vRemoveFirst [])\n'
    '(vRemoveFirst [1])\n'
    '(vRemoveFirst [1 2 3])\n'
    ']' : '[[] [] [2 3]]',
  '[\n'
    '(vSlice [] 0 1)\n'
    '(vSlice [1 2 3] 0 2)\n'
    '(vSlice [1 2 3 4 5] 1 4)\n'
    ']' : '[[] [1 2] [2 3 4]]',
  '[\n'
    '(vLast [] 6)\n'
    '(vLast [1] 9)\n'
    '(vLast [1 2 3] 4)\n'
    ']' : '[6 1 3]',
  '[\n'
    '(vFirst [] 6)\n'
    '(vFirst [1] 9)\n'
    '(vFirst [1 2 3] 4)\n'
    ']' : '[6 1 1]',
  '[\n'
    '(vIsEQ iIsEQ [] [])\n'
    '(vIsEQ iIsEQ [1 2] [3 4])\n'
    '(vIsEQ iIsEQ [1 2 3] [1 2])\n'
    '(vIsEQ iIsEQ [1 2 3 4] [1 2 3 4])\n'
    ']' : '[true false false true]',
  '[\n'
    '(vTakeWhile [0 1 2] (\\e false))\n'
    '(vTakeWhile [0 1 2] (\\e true))\n'
    '(vTakeWhile [1 2 3 4 5 6] (\\e iIsLT e 4))\n'
    '(vTakeWhile [0 0 0 3 5 0] iIsZero)\n'
    ']' : '[[] [0 1 2] [1 2 3] [0 0 0]]',
  '[\n'
    '(vSkipWhile [0 1 2] (\\e true))\n'
    '(vSkipWhile [0 1 2] (\\e false))\n'
    '(vSkipWhile [1 2 3 4 5 6] (\\e iIsLT e 4))\n'
    '(vSkipWhile [0 0 0 3 5 0] (\\e iIsZero e))\n'
    ']' : '[[] [0 1 2] [4 5 6] [3 5 0]]',
  '[\n'
    '(vInsertAt [] 0 1)\n'
    '(vInsertAt [] 1 1)\n'
    '(vInsertAt [1] 0 2)\n'
    '(vInsertAt [1] 1 2)\n'
    '(vInsertAt [1 2 3 4] 2 9)\n'
    ']' : '[[1] [1] [2 1] [1 2] [1 2 9 3 4]]',
  '[\n'
    '(vReduce [] iAdd 0)\n'
    '(vReduce [0 1 2 3] iAdd 0)\n'
    '(vReduce [2 1 2 3] iMul 0)\n'
    ']' : '[0 6 12]',
  '[\n'
    '(vRemoveAt [] 0)\n'
    '(vRemoveAt [] 1)\n'
    '(vRemoveAt [1] 0)\n'
    '(vRemoveAt [1] 1)\n'
    '(vRemoveAt [1 2 3 4] 2)\n'
    ']' : '[[] [] [] [1] [1 2 4]]',
};

class MyTask implements Task {
  final String code;

  MyTask(this.code);
  
  String execute () {
    return (new TrashSolver(
      new Parser().parse("test", "~\\\"stdlib.lf\"\n${code}")
        ..bind())
      ..solve()).expr.toString();
  }
}

main() async {
  var t = new DateTime.now();
  var worker = new Worker(poolSize: 4, spawnLazily: false);
  await Future.wait(tests.keys.map((code) async {
    var f = worker.handle(new MyTask(code));
    String res = await f;
    if (res != tests[code]) {
      print("Mismatch!");
      print("code:\n$code");
      print("expected:\n${tests[code]}");
    }
  }));
  print("done");
  print("took ${(new DateTime.now().millisecondsSinceEpoch - t.millisecondsSinceEpoch) / 1000}");
  worker.close();
}
