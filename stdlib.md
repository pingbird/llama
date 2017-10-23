#Standard Library

###Util
```
null // the identity function \null null
return // is \x x
if b t f // is \b\t\f b t f
for start end iv l // equivalent to fold (vGenerateRange start end) iv l
while st lb l
    // st = l(st) while lb(st) is true
until st lb l
    // st = l(st) until lb(st) is true
    // equivalent to while (l st) (\b bNot (lb b)) l
```

###Tuple
```
tPair a b // makes a pair with a and b
(t) tFirst // gets the first value of a pair
tSetFirst t v // sets the first value of a pair to v
(t) tSecond // gets the second value of a pair
tSetSecond t v // sets the second value of a pair to v
tVararg i f ... // reads a variable number of arguments to a vector and return f(v)
tTuple i ... // makes a tuple with i length
(t) (tGet i p) // gets the value at p from a tuple with i length
tSet t i n v // sets t[n] of tuple length i to v 
tVector i t // turns a tuple into a vector
```

###Bool
```
true // is \t\f t
false // is \t\f f
bNot x // returns !x
bOr x y // returns x || y
bAnd x y // returns x && y
bXor x y // returns x ^ y
```

###Int
```
uSucc x // returns x + 1
uPred x // returns x - 1
uAdd x y // returns x + y
uSub x y // returns x - y
uMul x y // returns x * y
uDiv x y // returns x / y
uExp x y // returns exp(x, y)
uIsZero x // returns x == 0
uIsGT x y // return x > y
uIsLT x y // return x < y
uIsGE x y // return x >= y
uIsLE x y // return x <= y
uIsEQ x y // return x == y
uSigned x // converts x to signed
```

###Signed Int
```
sSucc x // returns x + 1
sPred x // returns x - 1
sNeg x // returns -x
sAdd x y // returns x + y
sSub x y // returns x - y
sMul x y // returns x * y
sDiv x y // returns x / y
sIsZero x // returns x == 0
sIsGT x y // return x > y
sIsLT x y // return x < y
sIsGE x y // return x >= y
sIsLE x y // return x <= y
sIsEQ x y // return x == y
sIsNEQ x y // return x != y
sIsNeg x // returns true if x is less than 0
sIsPos x // returns true if x is greater than 0
sNormalize x // normalizes x so that at least one side is zero
sUnsigned x // converts x to unsigned number
```

###Vector

```
vGet v i d // returns v[i] or d if out of bounds (zero indexed)
vSet v i e // returns v where v[i] = e
vLast v d // returns the last value in v or d if empty
vFirst v d // returns the first value in v or d if empty
vLength v // returns v.length
vReverse v // returns the reverse of v
vTake v i // returns the first i values of the vector
vTakeWhile v l // returns the values of v until l(v[i]) is false
vSkip v i // returns the vector but skips the first i elements
vSkipWhile v l // returns the values of v starting when l(v[i]) is truevFirstWhere v l d // returns the first element where l(e) returns true, d if none are found
vMap v l
    // returns v.map(l) where l is a llama that takes an element and returns the replacement
    // so that out[n] = l(v[n])
vFoldMap v iv lf
    // same as map but keeps a state so that out[n], st = l(st, v[n])
vWhere v l
    // returns v.where(l) where l is a llama that takes an element and returns a boolean
    // the output is an array where l returned true
vReduce v l d
    // reduces v to a single value by combining them with l(e1, e2) or d if v is empty
vFold v iv l
    // reduces a vector to a single value where iv is the initial value
    // l is a lambda that takes the previous value (iv if first element) and the current element
    // and returns the next value to pass to the callback or return value if its the last element
vExpand v l
    // expand function like dart's Iterable.expand
vIndexify v // returns an array where out[i] = mkTuple(i, out[i])
vGenerate j e // generates a Vector with j elements and filling it with e
vGenerateRange i j // generates a Vector of integers starting at i and ending before j
vIsEmpty v // returns true if v is empty, else returns false
vRemoveLast v // removes the last element
vRemoveFirst v // removes the first element
vRemoveAt v i // removes element at i
vRemoveRange v start end // removes range of elements
vRemoveWhere v l // removes elements where l(e) is true
vInsertEnd v e // inserts e at the end of v
vInsertStart v e // inserts e at the start of v
vInsertAt v i e // inserts e into v at i
vConcat va vb // appends vb to va
vSlice v start end // returns a slice of v from start to before end
vAny v l // returns true if any l(e) returns true
vFirstWhere v l d // returns first element where l(e) is true else returns d
vEQ cmp a b // returns true if both vectors have the same contents using cmp
```

###Map
```
mFromVec cmp vec k v // gets a map where m[k(e)] = v(e)
mKeys m // gets a vector of all the keys
mValues m // gets a vector of all the values
mGet cmp m k d // returns m[k] or d if absent where cmp is the comparison function to use on keys, for example uEQ
mSet cmp m k e // sets m[k] to e
mExists cmp m k // returns true if m contains the key k
mContains cmp m v // returns true of m contains the value v
mAddAll cmp ma mb // adds all of the contents of mb to ma
mAddFromVec cmp ma vec k v // same as mAddAll cmp ma~mFromVec cmp vec k v
mRemove cmp m k // removes key if it exists
mPutIfAbsent cmp m k e // sets m[k] to e only if it doesnt exist already
```