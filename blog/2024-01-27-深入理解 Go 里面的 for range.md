---
authors: Zzhiter
tags: [Go]
---

# 深入理解 Go 里面的 for range

# 高能点

- for i，v := range x 遍历会创建 被遍历对象 x 的副本，同时取出来的值也会存到一个临时变量里面，这个临时变量就是我们见到的 v，它会被重复使用。
- 如果 x 是切片类型，并且 x 再遍历的时候还会发生变化，那么更需要额外注意，因为可能会遇到因为切片重新赋值，旧切片再扩容 引发的新旧切片 底层数组 不一致的问题。

# **For statements with ****range**** clause (带 ****range**** 子句的 ****For**** 语句)**

看下 Go 语言官方定义的规约。

## 可迭代的类型

A "for" statement with a "range" clause iterates through all entries of an array, slice, string or map, or values received on a channel. For each entry it assigns _iteration values_ to corresponding _iteration variables_ if present and then executes the block.

带有 range 的 for 语句，可以迭代数组，切片，string 或者 map，或者从 channel 里接收到的值。对于每个条目，它会将迭代值分配给相应的**迭代变量**（如果存在），然后执行该块。

```go
RangeClause = [ [ExpressionList](https://go.dev/ref/spec#ExpressionList) "=" | [IdentifierList](https://go.dev/ref/spec#IdentifierList) ":=" ] "range" [Expression](https://go.dev/ref/spec#Expression) .
```

The expression on the right in the "range" clause is called the _range expression_, its [core type](https://go.dev/ref/spec#Core_types) must be an array, pointer to an array, slice, string, map, or channel permitting [receive operations](https://go.dev/ref/spec#Receive_operator). As with an assignment, if present the operands on the left must be [addressable](https://go.dev/ref/spec#Address_operators) or map index expressions; they denote the iteration variables. If the range expression is a channel, at most one iteration variable is permitted, otherwise there may be up to two. If the last iteration variable is the [blank identifier](https://go.dev/ref/spec#Blank_identifier), the range clause is equivalent to the same clause without that identifier.

“range”子句右侧的表达式称为范围表达式，其核心类型必须是数组、指向数组的指针、切片、字符串、映射或允许接收操作的通道。

与赋值一样，如果存在，左侧的操作数必须是**可寻址的**或 map index 表达式；它们表示迭代变量。

**如果范围表达式是通道，则最多允许一个迭代变量，否则最多允许有两个。**

如果最后一个迭代变量是空白标识符，则范围子句相当于没有该标识符的同一子句。

> 我们知道 for range 一般有三种使用形式：
>
> 1. 分析使用 `for range a {}`
> 2. 分析使用 `for i := range a {}`
> 3. 分析使用 `for i, elem := range a {}` ，其中 i 和 elem 可以为_。

## 不同类型的迭代方式和注意点

The range expression `x` is evaluated once before beginning the loop, with one exception: if at most one iteration variable is present and `len(x)` is [constant](https://go.dev/ref/spec#Length_and_capacity), the range expression is not evaluated.

**The range expression ****x**** 在开始循环之前计算一次**，但有一个例外：如果最多存在一个迭代变量并且 len(x) 为常量，则不计算范围表达式。

下面的需要注意的地方，我都加粗表示了，其他地方和平常大家理解的差不多，不再详细说明。

Function calls on the left are evaluated once per iteration. For each iteration, iteration values are produced as follows if the respective iteration variables are present:

```go
Range expression                          1st value          2nd value

array or slice  a  [n]E, *[n]E, or []E    index    i  int    a[i]       E
string          s  string type            index    i  int    see below  rune
map             m  map[K]V                key      k  K      m[k]       V
channel         c  chan E, <-chan E       element  e  E
```

1. For an **array**, **pointer to array**, or **slice value** `a`, the index iteration values are produced in increasing order, starting at element index 0. If at most one iteration variable is present, the range loop produces iteration values from 0 up to `len(a)-1` and does not index into the array or slice itself. For a `nil` slice, the number of iterations is 0.
2. For a string value, the "range" clause iterates over the Unicode code points in the string starting at byte index 0. On successive iterations, the index value will be the index of the first byte of successive UTF-8-encoded code points in the string, and the second value, of type `rune`, will be the value of the corresponding code point. If the iteration encounters an invalid UTF-8 sequence, the second value will be `0xFFFD`, the Unicode replacement character, and the next iteration will advance a single byte in the string.
3. **The iteration order over maps is not specified and is not guaranteed to be the same from one iteration to the next**. If a map entry that has not yet been reached is removed during iteration, the corresponding iteration value will not be produced. If a map entry is created during iteration, that entry may be produced during the iteration or may be skipped. The choice may vary for each entry created and from one iteration to the next. If the map is `nil`, the number of iterations is 0.
4. For channels, the iteration values produced are the successive values sent on the channel until the channel is [closed](https://go.dev/ref/spec#Close). If the channel is `nil`, **the range expression blocks forever**.

The iteration values are assigned to the **respective iteration variables** as in an [assignment statement](https://go.dev/ref/spec#Assignment_statements).

The iteration variables may be declared by the "range" clause using a form of [short variable declaration](https://go.dev/ref/spec#Short_variable_declarations) (`:=`). In this case their types are set to the types of the respective iteration values and their [scope](https://go.dev/ref/spec#Declarations_and_scope) is the block of the "for" statement; **they are re-used in each iteration（会被重用）.** **If the iteration variables are declared outside the "for" statement, after execution their values will be those of the last iteration.**

用法如下：

```go
var testdata *struct {
        a *[7]int
}
for i, _ := range testdata.a {
        // testdata.a is never evaluated; len(testdata.a) is constant
        // i ranges from 0 to 6
        f(i)
}

var a [10]string
for i, s := range a {
        // type of i is int
        // type of s is string
        // s == a[i]
        g(i, s)
}

var key string
var val interface{}  // element type of m is assignable to val
m := map[string]int{"mon":0, "tue":1, "wed":2, "thu":3, "fri":4, "sat":5, "sun":6}
for key, val = range m {
        h(key, val)
}
// key == last map key encountered in iteration
// val == map[key]

var ch chan Work = producer()
for w := range ch {
        doWork(w)
}

// empty a channel
for range ch {}
```

# range 到底是什么

我们平常使用的都是如下的经典循环：

1. 初始化循环的 `Ninit`；
2. 循环的继续条件 `Left`；
3. 循环体结束时执行的 `Right`；
4. 循环体 `NBody`：

```go
for Ninit; Left; Right {
    NBody
}
```

但是 Go 语言编译器帮我们包装了一个语法糖。range 最后经过 Go 编译器处理完之后，本质上还是通过上述形式执行。

与简单的经典循环相比，范围循环在 Go 语言中更常见、实现也更复杂。这种循环同时使用 `for` 和 `range` 两个关键字，编译器会在编译期间将所有 for-range 循环变成经典循环。从编译器的视角来看，就是将 `ORANGE` 类型的节点转换成 `OFOR` 节点:

![](static/E3wtbmRomoDf1zxHIQYcY7Y8nFd.png)

**图 5-2 范围循环、普通循环和 SSA**

节点类型的转换过程都发生在中间代码生成阶段，所有的 for-range 循环都会被 `cmd/compile/internal/gc.walkrange` 转换成不包含复杂结构、只包含基本表达式的语句。接下来，我们按照循环遍历的元素类型依次介绍遍历数组和切片、哈希表、字符串以及管道时的过程。

## 数组和切片

对于数组和切片来说，Go 语言有三种不同的遍历方式，这三种不同的遍历方式分别对应着代码中的不同条件，它们会在 `cmd/compile/internal/gc.walkrange` 函数中转换成不同的控制逻辑，我们会分成几种情况分析该函数的逻辑：

1. 分析遍历数组和切片清空元素的情况；
2. 分析使用 `for range a {}` 遍历数组和切片，不关心索引和数据的情况；
3. 分析使用 `for i := range a {}` 遍历数组和切片，只关心索引的情况；
4. 分析使用 `for i, elem := range a {}` 遍历数组和切片，关心索引和数据的情况；

`cmd/compile/internal/gc.arrayClear` 是一个非常有趣的优化，它会优化 Go 语言遍历数组或者切片并删除全部元素的逻辑：

```go
// 原代码
for i := range a {
        a[i] = zero
}
// 优化后
if len(a) != 0 {
        hp = &a[0]
        hn = len(a) * sizeof(elem(a))
        memclrNoHeapPointers(hp, hn)
        i = len(a) - 1
}
```

相比于依次清除数组或者切片中的数据，Go 语言会直接使用 `runtime.memclrNoHeapPointers` 或者 `runtime.memclrHasPointers` 清除目标数组内存空间中的全部数据，并在执行完成后更新遍历数组的索引，这也印证了我们在遍历清空数组一节中观察到的现象。

处理了这种特殊的情况之后，我们可以回到 `ORANGE` 节点的处理过程了。这里会设置 for 循环的 `Left` 和 `Right` 字段，也就是终止条件和循环体每次执行结束后运行的代码：

```go
ha := a
hv1 := temp(types.Types[TINT])
hn := temp(types.Types[TINT])
init = append(init, nod(OAS, hv1, nil))
init = append(init, nod(OAS, hn, nod(OLEN, ha, nil)))
n.Left = nod(OLT, hv1, hn)
n.Right = nod(OAS, hv1, nod(OADD, hv1, nodintconst(1)))if v1 == nil {break}
```

### `for range a {}`

如果循环是 `for range a {}`，那么就满足了上述代码中的条件 `v1 == nil`，即循环不关心数组的索引和数据，这种循环会被编译器转换成如下形式：

```go
ha := a
hv1 := 0
hn := len(ha)
v1 := hv1
for ; hv1 < hn; hv1++ {
    ...
}
```

### `for i := range a {}`

调用方不关心数组的元素，只关心遍历数组使用的索引。

它会将 `for i := range a {}` 转换成下面的逻辑，与第一种循环相比，这种循环在循环体中添加了 `v1 := hv1` 语句，传递遍历数组时的索引：

```go
ha := a
hv1 := 0
hn := len(ha)
**v1 := hv1**
for ; hv1 < hn; hv1++ {
    v1 = hv1
    ...
}
```

### `for i, elem := range a {}`

这段代码处理的使用者同时关心索引和切片的情况。它不仅会在循环体中插入更新索引的语句，还会插入赋值操作让循环体内部的代码能够访问数组中的元素：

```go
ha := a
hv1 := 0
hn := len(ha)
v1 := hv1
**v2 := nil**
for ; hv1 < hn; hv1++ {
    tmp := ha[hv1]
    v1, v2 = hv1, tmp
    ...
}
```

对于所有的 range 循环，Go 语言都会在编译期将原切片或者数组赋值给一个新变量 `ha`，在赋值的过程中就发生了拷贝，而我们又通过 `len` 关键字预先获取了切片的长度，所以在循环中追加新的元素也不会改变循环执行的次数。

而遇到这种同时遍历索引和元素的 range 循环时，Go 语言会额外创建一个新的 `v2` 变量存储切片中的元素，**循环中使用的这个变量 v2 会在每一次迭代被重新赋值而覆盖，赋值时也会触发拷贝**。

## 对 map，string，channel 进行遍历

> [https://draveness.me/golang/docs/part2-foundation/ch05-keyword/golang-for-range/#%e5%93%88%e5%b8%8c%e8%a1%a8](https://draveness.me/golang/docs/part2-foundation/ch05-keyword/golang-for-range/#%E5%93%88%E5%B8%8C%E8%A1%A8)

遍历 map 的顺序顺序是随机的，想搞明白原理的可以看引用文章。

遍历字符串的过程与数组、切片和哈希表非常相似，只是在遍历时会获取字符串中索引对应的字节并将字节转换成 `rune`。我们在遍历字符串时拿到的值都是 `rune` 类型的变量，`for i, r := range s {}` 的结构都会被转换成如下所示的形式：

```go
ha := s
for hv1 := 0; hv1 < len(ha); {
    hv1t := hv1
    hv2 := rune(ha[hv1])
    if hv2 < utf8.RuneSelf {
        hv1++
    } else {
        hv2, hv1 = decoderune(ha, hv1)
    }
    v1, v2 = hv1t, hv2
}
```

在前面的字符串一节中我们曾经介绍过字符串是一个只读的字节数组切片，所以范围循环在编译期间生成的框架与切片非常类似，只是细节有一些不同。

使用下标访问字符串中的元素时得到的就是字节，但是这段代码会将当前的字节转换成 `rune` 类型。如果当前的 `rune` 是 ASCII 的，那么只会占用一个字节长度，每次循环体运行之后只需要将索引加一，但是如果当前 `rune` 占用了多个字节就会使用 `runtime.decoderune` 函数解码，具体的过程就不在这里详细介绍了。

使用 range 遍历 Channel 也是比较常见的做法，一个形如 `for v := range ch {}` 的语句最终会被转换成如下的格式：

```go
ha := a
hv1, hb := <-ha
for ; hb != false; hv1, hb = <-ha {
    v1 := hv1
    hv1 = nil
    ...
}
```

这里的代码可能与编译器生成的稍微有一些出入，但是结构和效果是完全相同的。该循环会使用 `<-ch` 从管道中取出等待处理的值，这个操作会调用 `runtime.chanrecv2` 并阻塞当前的协程，当 `runtime.chanrecv2` 返回时会根据布尔值 `hb` 判断当前的值是否存在：

- 如果不存在当前值，意味着当前的管道已经被关闭；
- 如果存在当前值，会为 `v1` 赋值并清除 `hv1` 变量中的数据，然后重新陷入阻塞等待新数据；

# 常见错误

## 尝试对临时变量取地址

如下代码想从数组遍历获取一个指针元素切片集合

```go
arr := [2]int{1, 2}
res := []*int{}
for _, v := range arr {
    res = append(res, &v)
}
//expect: 1 2
fmt.Println(*res[0],*res[1]) 
//but output: 2 2
```

答案是【取不到】 同样代码对切片 `[]int{1, 2}` 或 `map[int]int{1:1, 2:2}` 遍历也不符合预期。 问题出在哪里？

因为 v 是上述创建的 v2，它是一个临时变量，并且值在最后一轮循环执行完之后固定了。

那么怎么改？ 有两种

- 使用局部变量拷贝 `v`

```go
for _, v := range arr {
    //局部变量v替换了v，也可用别的局部变量名
    v := v 
    res = append(res, &v)
}
```

- 直接索引获取原来的元素

```go
//这种其实退化为for循环的简写
for k := range arr {
    res = append(res, &arr[k])
}
```

## 遍历的长度是固定的

遍历会停止么？

```go
v := []int{1, 2, 3}
for i := range v {
    v = append(v, i)
}
```

答案是【会】，因为**遍历前循环多少次就已经确定了。**

## 对大数组这样遍历造成内存浪费

```go
//假设值都为1，这里只赋值3个
var arr = [102400]int{1, 1, 1} 
for i, n := range arr {
    //just ignore i and n for simplify the example
    _ = i 
    _ = n 
}
```

答案是【有问题】！**遍历前的拷贝对内存是极大浪费啊** 怎么优化？有两种

- **对数组取地址遍历** `for i, n := range &arr`
- 对数组做切片引用 `for i, n := range arr[:]`

反思题：对大量元素的 slice 和 map 遍历为啥不会有内存浪费问题？ （提示，底层数据结构是否被拷贝）

因为 slice 和 map 本来就是引用啊。

## 对大数组这样重置效率也很高

```go
//假设值都为1，这里只赋值3个
var arr = [102400]int{1, 1, 1} 
for i, _ := range &arr {
    arr[i] = 0
}
```

答案是【高】，这个要理解得知道 go 对这种重置元素值为默认值的遍历是有优化的, 详见 [go 源码：memclrrange](https://link.zhihu.com/?target=https%3A//github.com/golang/go/blob/ea020ff3de9482726ce7019ac43c1d301ce5e3de/src/cmd/compile/internal/gc/range.go%23L363)。相比于依次清除数组或者切片中的数据，Go 语言会直接使用 `runtime.memclrNoHeapPointers` 或者 `runtime.memclrHasPointers` 清除目标数组内存空间中的全部数据，并在执行完成后更新遍历数组的索引，这也印证了我们在遍历清空数组一节中观察到的现象。

```go
// Lower n into runtime·memclr if possible, for
// fast zeroing of slices and arrays (issue 5373).
// Look for instances of
//
// for i := range a {
//  a[i] = zero
// }
//
// in which the evaluation of a is side-effect-free.
```

## 这样遍历中起 goroutine 可以么？

```go
var m = []int{1, 2, 3}
for i := range m {
    go func() {
        fmt.Print(i)
    }()
}
//block main 1ms to wait goroutine finished
time.Sleep(time.Millisecond)
```

答案是【不可以】。预期输出 0,1,2 的某个组合，如 012，210.. 结果是 222。

因为闭包里面只想的是同一个临时变量 v2。

> When iterating in Go, one might attempt to use goroutines to process data in parallel. For example, you might write something like this, using a closure:
>
> ```go
> ```

for _, val := range values {
go func() {
fmt.Println(val)
}()
}

```
> The above for loops might not do what you expect because their `val` variable is actually a single variable that takes on the value of each slice element. **Because the closures are all only bound to that one variable**, there is a very good chance that when you run this code you will see the last element printed for every iteration instead of each value in sequence, because the goroutines will probably not begin executing until after the loop.

同样是拷贝的问题 怎么解决 

- 以参数方式传入

```go
for i := range m {
    go func(i int) {
        fmt.Print(i)
    }(i)
}
```

- 使用局部变量拷贝

```go
for i := range m {
    i := i
    go func() {
        fmt.Print(i)
    }()
}
```

## 一个切片赋值，旧切片再扩容 引发的新旧切片 底层数组 不一致的问题

只要我们不超过切片的容量，或者执行任何其他操作导致底层数组指针发生更改，由 range 关键字读取的切片和我们在 for 循环内引用的切片都将指向同一个底层数组，因此这些更改可能会在 for 循环中读取。

但是如果发生了底层数组扩容，可能就会造成不一致问题。这是一段有点令人困惑的代码，可以帮助进一步说明这一点。它利用 Go 的 make 关键字来创建具有特定初始容量的切片。

```go
package main

import "fmt"

func main() {
        sLen, sCap := 0, 5
        slice := make([]int, sLen, sCap)
        slice = append(slice, 12, 1, 4)

        for i, num := range slice {
                fmt.Println("Current Number:", num)
                if num%2 == 0 {
                        slice = append(slice, num/2)
                        swap(i+1, len(slice)-1, slice)
                }
                fmt.Println(slice)
        }
        fmt.Println(slice)
}

func swap(i, j int, slice []int) {
        slice[i], slice[j] = slice[j], slice[i]
}
```

输出：

```go
Current Number: 12
[12 6 4 1]
Current Number: 6
[12 6 3 1 4]
Current Number: 3
[12 6 3 1 4]
[12 6 3 1 4]
```

当 sCap 为 0 时，输出：

```go
Current Number: 12
[12 6 4 1]
Current Number: 1
[12 6 4 1]
Current Number: 4
[12 6 4 2 1]
[12 6 4 2 1]
```

因为当 sCap 为 0 时，slice = append(slice, 12, 1, 4)执行完之后，slice 的长度和容量都是 3

当 sCap 为 3 时，输出：

```go
Current Number: 12
[12 6 4 1]
Current Number: 1
[12 6 4 1]
Current Number: 4
[12 6 4 2 1]
[12 6 4 2 1]
```

当 sCap 为 4 时，输出：

```go
Current Number: 12
[12 6 4 1]
Current Number: 6
[12 6 3 1 4]
Current Number: 4
[12 6 3 2 4 1]
[12 6 3 2 4 1]
```

range 把 slice 赋值给了一个新的变量 slice_temp，然后遍历 slice_temp，并遇到偶数，就把偶数的一半添加到原始的 slice 的中，并与下一位元素交换。循环 3 次不会变的，因为刚开始的时候 len(slice) = 3 已经确定了。

- sCap 为 5 的时候，切片没有发生扩容，因此 slice_temp 和 slice 共用一个底层数组的，所以输出：
  遍历 slice 中实时的元素。
  ```go
  ```

Current Number: 12
[12 6 4 1]
Current Number: 6
[12 6 3 1 4]
Current Number: 3
[12 6 3 1 4]
[12 6 3 1 4]

```

- sCap为4的时候，切片在最后会发生一次扩容，因此在前四个元素是共用一个底层数组的，加入3之后，变成了[12 6 3 1 4]，发生扩容，下次遍历slice_temp，还是[12 6 4 1]，所以输出4，但是这个时候把4/2=2加入到原来的slice，[12 6 3 1 4]变成[12 6 3 2 4 1]
	```go
Current Number: 12
[12 6 4 1]
Current Number: 6
[12 6 3 1 4]
Current Number: 4
[12 6 3 2 4 1]
[12 6 3 2 4 1]
```

- sCap 为 0 和 3 的时候，切片在刚开始就发生扩容，slice_temp 一直是[12, 1, 4]，但是 slice 一直在发生变化，加入了 12/2=6 和 4/2=2。所以最后 slice 为[12 6 4 2 1]。
  ```go
  ```

Current Number: 12
[12 6 4 1]
Current Number: 1
[12 6 4 1]
Current Number: 4
[12 6 4 2 1]
[12 6 4 2 1]

```



使用 `append` 关键字向切片中追加元素也是常见的切片操作，选择进入两种流程。

- 切片容量足的时候，会在原来的数组上追加。

- 当切片的容量不足时，我们会调用 `runtime.growslice` 函数为切片扩容，扩容是为切片分配新的内存空间并拷贝原切片中元素的过程。

所以这个核心在于，在for range中对切片创建的副本，在原来的slice的底层数组发生扩容的时候，还是会指向原来的底层数组，不过如果不发生扩容，那么副本和原来slice的底层数组还是一样的。

# 参考

https://zhuanlan.zhihu.com/p/105435646 

https://draveness.me/golang/docs/part2-foundation/ch03-datastructure/golang-array-and-slice/

https://draveness.me/golang/docs/part2-foundation/ch05-keyword/golang-for-range/

```
