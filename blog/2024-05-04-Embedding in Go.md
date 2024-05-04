# Embedding in Go
---
authors: Zzhiter
tags: [Go]
---

Go doesn't support inheritance in the classical sense; instead, in encourages _composition_ as a way to extend the functionality of types. This is not a notion peculiar to Go. [Composition over inheritance](https://en.wikipedia.org/wiki/Composition_over_inheritance) is a known principle of OOP and is featured in the very first chapter of the _Design Patterns_ book.

_Embedding_ is an important Go feature making composition more convenient and useful. While Go strives to be simple, embedding is one place where the essential complexity of the problem leaks somewhat. In this series of short posts, I want to cover the different kinds of embedding Go supports, and provide examples from real code (mostly the Go standard library).

There are three kinds of embedding in Go:

1. Structs in structs (this part)
2. Interfaces in interfaces ([part 2](https://eli.thegreenplace.net/2020/embedding-in-go-part-2-interfaces-in-interfaces/))
3. Interfaces in structs ([part 3](https://eli.thegreenplace.net/2020/embedding-in-go-part-3-interfaces-in-structs/))

两个东西，笛卡尔积一下，struct 在 interface 中有点不合理，其他都合理

# Embedding structs in structs

我们将从一个简单的示例开始，演示将一个结构体嵌入到另一个结构体中：

```go
type Base struct {
  b int
}

type Container struct { // Container 是嵌入的结构体
  Base                     // Base 是被嵌入的结构体
  c string
}
```

现在 `Container` 的实例也将拥有字段 `b`。在规范中，它被称为_提升_（promoted）字段。我们可以像访问 `c` 一样访问它：

```go
co := Container{}
co.b = 1
co.c = "string"
fmt.Printf("co -> {b: %v, c: %v}\n", co.b, co.c)
```

然而，在使用结构体字面量时，我们必须将嵌入的结构体作为一个整体初始化，而不是它的字段。提升的字段不能用作结构体字面量中的字段名：

```go
co := Container{Base: Base{b: 10}, c: "foo"}
fmt.Printf("co -> {b: %v, c: %v}\n", co.b, co.c)
```

注意，访问 `co.b` 是一种语法便利；我们也可以使用 `co.Base.b` 更显式地进行访问。

## 方法

嵌入结构体也适用于方法。假设我们为 `Base` 提供了这个方法：

```go
func (base Base) Describe() string {
  return fmt.Sprintf("base %d belongs to us", base.b)
}
```

我们现在可以在 `Container` 的实例上调用它，就好像它也有这个方法一样：

```go
fmt.Println(cc.Describe())
```

为了更好地理解这个调用的机制，有助于将 `Container` 可视化为具有显式类型字段 `Base` 和一个显式 `Describe` 方法，该方法转发调用：

```go
type Container struct {
  base Base
  c string
}

func (cont Container) Describe() string {
  return cont.base.Describe()
}
```

在这个替代的 `Container` 上调用 `Describe` 的效果与我们使用嵌入的原始版本类似。

这个示例还展示了嵌入字段上的方法行为的一个重要微妙之处；当调用 `Base` 的 `Describe` 时，它传递了一个 `Base` 接收器（方法定义中左边的 `(...)`），而不管它是通过哪个嵌入结构体调用的。这与 Python 和 C++ 等其他语言中的继承不同，在这些语言中，继承的方法会获得对它们被调用的子类的引用。这是 Go 中嵌入与传统继承不同的一个关键方式。

## 嵌入字段的遮蔽

如果嵌入的结构体有一个字段 `x`，并且嵌入了一个也有字段 `x` 的结构体，会发生什么？在这种情况下，通过嵌入的结构体访问 `x` 时，我们得到的是嵌入结构体的字段；嵌入结构体的 `x` 被_遮蔽_（shadowed）了。

以下是演示这一点的示例：

```go
type Base struct {
  b   int
  tag string
}

func (base Base) DescribeTag() string {
  return fmt.Sprintf("Base tag is %s", base.tag)
}

type Container struct {
  Base
  c   string
  tag string
}

func (co Container) DescribeTag() string {
  return fmt.Sprintf("Container tag is %s", co.tag)
}
```

当这样使用时：

```go
b := Base{b: 10, tag: "b's tag"}
co := Container{Base: b, c: "foo", tag: "co's tag"}

fmt.Println(b.DescribeTag())
fmt.Println(co.DescribeTag())
```

这将打印：

```go
Base tag is b's tag
Container tag is co's tag
```

注意，当访问 `co.tag` 时，我们得到的是 `Container` 的 `tag` 字段，而不是通过 `Base` 的遮蔽进来的那个。不过，我们可以通过 `co.Base.tag` 显式访问另一个。

## 示例：sync.Mutex

以下是所有来自 Go 标准库的示例。

在 Go 中，结构体到结构体嵌入的一个经典例子是 `sync.Mutex`。以下是 `crypto/tls/common.go` 中的 `lruSessionCache`：

```go
type lruSessionCache struct {
  sync.Mutex
  m        map[string]*list.Element
  q        *list.List
  capacity int
}
```

注意 `sync.Mutex` 的嵌入；现在如果 `cache` 是类型 `lruSessionCache` 的对象，我们可以简单地调用 `cache.Lock()` 和 `cache.Unlock()`。这在某些场景下很有用，但并不总是这样。如果锁定是结构体的公共 API 的一部分，嵌入互斥体是方便的，并且消除了显式转发方法的需要。

然而，可能是锁定只由结构体的方法内部使用，并且没有暴露给它的用户。在这种情况下，我不会嵌入 `sync.Mutex`，而是会将其作为一个未导出的字段（如 `mu sync.Mutex`）。

我在这里写了更多关于嵌入互斥体和要注意的陷阱。

## 示例：bufio.ReadWriter

由于嵌入的结构体“继承”（但不是传统意义上的，如上所述）嵌入结构体的方法，嵌入可以是实现接口的有用工具。

考虑 `bufio` 包，它有类型 `bufio.Reader`。这个类型的指针实现了 `io.Reader` 接口。同样适用于 `*bufio.Writer`，它实现了 `io.Writer`。我们如何创建一个实现 `io.ReadWriter` 接口的 `bufio` 类型？

使用嵌入非常容易：

```go
type ReadWriter struct {
  *Reader
  *Writer
}
```

这个类型继承了 `*bufio.Reader` 和 `*bufio.Writer` 的方法，因此实现了 `io.ReadWriter`。这是在没有给字段显式命名（它们不需要）的情况下完成的，并且没有编写显式的转发方法。

一个稍微复杂一点的例子是 `context` 包中的 `timerCtx`：

```go
type timerCtx struct {
  cancelCtx
  timer *time.Timer

  deadline time.Time
}
```

为了实现 `Context` 接口，`timerCtx` 嵌入了 `cancelCtx`，它实现了所需的 4 个方法中的 3 个（`Done`、`Err` 和 `Value`）。然后它自己实现了第四个方法——`Deadline`。

## 通过结构体嵌入实现继承

我们用很容易理解的动物-猫来举例子。

```javascript
type Animal struct {
        Name string
}

func (a *Animal) Eat() {
        fmt.Printf("%v is eating", a.Name)
        fmt.Println()
}

type Cat struct {
        Animal
}

cat := &Cat{
        Animal: Animal{
                Name: "cat",
        },
}
cat.Eat() // cat is eating
```

首先，我们实现了一个 Animal 的结构体，代表动物类。并声明了 Name 字段，用于描述动物的名字。

然后，实现了一个以 Animal 为 receiver 的 Eat 方法，来描述动物进食的行为。

最后，声明了一个 Cat 结构体，组合了 Cat 字段。再实例化一个猫，调用 Eat 方法，可以看到会正常的输出。

可以看到，Cat 结构体本身没有 Name 字段，也没有去实现 Eat() 方法。唯一有的就是匿名嵌套的方式继承了 Animal 父类，至此，我们证明了 Go 通过匿名嵌套的方式实现了继承。

上面是嵌入类型实例，同样地也可以嵌入类型指针。

```javascript
type Cat struct {
        *Animal
}

cat := &Cat{
        Animal: &Animal{
                Name: "cat",
        },
}
```

## 嵌入式继承机制的的局限

相比于 C++ 和 Java， Go 的继承机制的作用是非常有限的，因为没有抽象方法，有很多的设计方案可以在 C++ 和 Java 中轻松实现，但是 Go 的继承却不能完成同样的工作。

```javascript
package main

import "fmt"

// Animal 动物基类
type Animal struct {
        name string
}

func (a *Animal) Play() {
        fmt.Println(a.Speak())
}

func (a *Animal) Speak() string {
        return fmt.Sprintf("my name is %v", a.name)
}

func (a *Animal) Name() string {
        return a.name
}

// Dog 子类狗
type Dog struct {
        Animal
        Gender string
}

func (d *Dog) Speak() string {
        return fmt.Sprintf("%v and my gender is %v", d.Animal.Speak(), d.Gender)
}

func main() {
        d := Dog{
                Animal: Animal{name: "Hachiko"},
                Gender:  "male",
        }
        fmt.Println(d.Name())
        fmt.Println(d.Speak())
        d.Play() // Play() 中调用的是基类 Animal.Speak() 方法，而不是 Dog.Speak()
}
```

运行输出：

```javascript
Hachiko
my name is Hachiko and my gender is male
my name is Hachiko
```

上面的例子中，Dog 类型重写了 Speak() 方法。然而如果父类型 Animal 有另外一个方法 Play() 调用 Speak() 方法，但是 Dog 没有重写 Play() 的时候，Dog 类型的 Speak() 方法则不会被调用，因为 Speak() 方法不是抽象方法，此时继承无法实现多态。

---

# Embedding interfaces in interfaces

> 这个就是为了实现 interface 中方法的的并集
>
> 1. **避免重复**：不需要在多个接口中重复相同的方法声明，这使得代码更加简洁和易于维护。
> 2. **清晰表达意图**：接口嵌入清晰地表达了一个接口实现所需的所有其他接口。例如，如果一个接口嵌入了 `io.Reader` 和 `io.Writer`，那么实现这个接口的类型必须同时具备读取和写入的能力。
> 3. **提高可读性**：接口嵌入使得代码阅读者可以立即理解一个接口与其他接口的关系，而不必查看每个方法的单独声明。
> 4. **Go 1.14 中的改进**：在 Go 1.14 之前，如果一个接口通过嵌入两个接口而隐式地声明了同一个方法，会导致编译错误。Go 1.14 引入了方法集的并集概念，解决了这个问题，允许接口嵌入更加灵活和强大。

嵌入一个接口到另一个接口是 Go 中最简单的嵌入类型，因为接口只声明了能力；它们并不实际为类型定义任何新数据或行为。

让我们从 Effective Go 中列出的示例开始，因为它展示了 Go 标准库中一个众所周知的接口嵌入案例。给定 `io.Reader` 和 `io.Writer` 接口：

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}
```

我们如何为既作为读取器又作为写入器的类型定义一个接口？一个明确的方法是：

```go
type ReadWriter interface {
    Read(p []byte) (n int, err error)
    Write(p []byte) (n int, err error)
}
```

除了在多个地方重复相同的方法声明这一明显问题外，这也妨碍了 `ReadWriter` 的可读性，因为它并不立即清楚它如何与另外两个接口组合。你要么必须记住每种方法的确切声明，要么不断回头看其他接口。

**请注意，标准库中有_许多_这样的组合接口；有****io.ReadCloser****、****io.WriteCloser****、****io.ReadWriteCloser****、****io.ReadSeeker****、****io.WriteSeeker****、****io.ReadWriteSeeker****等等。在标准库中，仅****Read****方法的声明可能需要重复 10 次以上。这将是一个遗憾，但幸运的是，接口嵌入提供了完美的解决方案：**

```go
type ReadWriter interface {
  Reader
  Writer
}
```

除了防止重复，这种声明以最清晰的方式_表达意图_：为了实现 `ReadWriter`，你必须实现 `Reader` 和 `Writer`。

## 在 Go 1.14 中修复重叠方法

接口嵌入是可组合的，并且按照你的预期工作。例如，给定接口 `A`、`B`、`C` 和 `D`，假设：

```go
type A interface {
  Amethod()
}

type B interface {
  A
  Bmethod()
}

type C interface {
  Cmethod()
}

type D interface {
  B
  C
  Dmethod()
}
```

`D` 的方法集将由 `Amethod()`、`Bmethod()`、`Cmethod()` 和 `Dmethod()` 组成。

然而，假设 `C` 被定义为：

```go
type C interface {
  A
  Cmethod()
}
```

一般来说，这不应当改变 `D` 的方法集。然而，在 Go 1.14 之前，这将导致 `D` 出现错误 `"Duplicate method Amethod"`，因为 `Amethod()` 将被声明两次——一次通过 `B` 的嵌入，一次通过 `C` 的嵌入。

Go 1.14 修复了这个问题，现在新的例子可以正常工作，正如我们所期望的那样。`D` 的方法集是它嵌入的接口的方法集和它自己的方法的_并集_。

一个更实际的示例来自标准库。类型 `io.ReadWriteCloser` 定义为：

```go
type ReadWriteCloser interface {
  Reader
  Writer
  Closer
}
```

但由于来自 `io.ReadCloser` 和 `io.WriteCloser` 的 `Close()` 方法的重复，这在 Go 1.14 之前是不可能的。

## 示例：net.Error

`net` 包有它自己的错误接口，声明如下：、

```go
// 一个Error代表一个网络错误。
type Error interface {
  error
  Timeout() bool   // 错误是超时吗？
  Temporary() bool // 错误是暂时的？
}
```

注意内置的 `error` 接口的嵌入。这种嵌入非常清晰地声明了意图：一个 `net.Error` 也是一个 `error`。代码的读者想知道他们是否可以将其视为这样，可以立即得到答案，而不是必须寻找一个 `Error()` 方法的声明，并在心理上将其与 `error` 中的规范版本进行比较。

## 示例：heap.Interface

`heap` 包为客户端类型实现了以下接口声明：

```go
type Interface interface {
  sort.Interface
  Push(x interface{}) // 将x作为元素Len()添加
  Pop() interface{}   // 移除并返回元素Len() - 1。
}
```

所有实现 `heap.Interface` 的类型也必须实现 `sort.Interface`；后者需要 3 个方法，所以如果不使用嵌入来写 `heap.Interface`，看起来就像：

```go
type Interface interface {
  Len() int
  Less(i, j int) bool
  Swap(i, j int)
  Push(x interface{}) // 将x作为元素Len()添加
  Pop() interface{}   // 移除并返回元素Len() - 1。
}
```

带有嵌入的版本在许多层面上都是优越的。最重要的是，它立即清楚地表明一个类型必须首先实现 `sort.Interface`；从更长的版本中模式匹配出这一信息要困难得多。

---

这篇文章是 Go 语言嵌入特性系列的第三部分，专注于接口在结构体中的嵌入。以下是文章的中文翻译，我尽量保持了原文的专业性：

---

# Embedding interfaces in structs

> 1. **方法集的扩展**
>    当结构体嵌入一个接口时，它“继承”了该接口的所有方法。这意味着结构体可以像调用自己的方法一样调用这些方法。这是因为嵌入的接口方法被提升为结构体的方法。例如，如果有一个 `Fooer` 接口和一个嵌入了 `Fooer` 的 `Container` 结构体，`Container` 可以直接调用 `Foo()` 方法，就像它自己实现了这个方法一样。
> 2. **实现接口**
>    如果嵌入的接口中的方法没有在结构体中被覆盖（即没有重新定义），那么结构体将自动实现接口的所有方法。这意味着结构体可以作为一个实现了该接口的实例被使用，而不需要显式地声明接口中的每一个方法。这允许结构体以接口类型传递给期望该接口的任何函数或方法。
> 3. **选择性覆盖**
>    结构体可以选择性地覆盖嵌入接口的方法。这意味着结构体可以实现接口的一部分方法，而保留其他方法的默认行为。这在扩展现有接口的行为时非常有用，因为它允许你添加新的行为而不必重新实现整个接口。
> 4. **接口的多态性**
>    由于结构体实现了接口，它可以被传递到任何期望该接口类型的函数中。这是多态性的一个例子，其中接口作为桥梁，允许不同类型的结构体（只要它们实现了相同的接口）被以相同的方式使用。这提高了代码的灵活性和重用性。
> 5. **接口的封装**
>    嵌入的接口可以用于封装和隐藏内部实现的细节。通过嵌入接口，结构体可以提供一个简化的接口视图，同时隐藏内部的复杂性。这有助于创建更清晰、更易于维护的 API。
> 6. **高级用法：限制行为**
>    在某些情况下，嵌入接口可以用于限制结构体的某些行为。例如，通过嵌入一个只包含部分方法的接口，可以创建一个具有更少能力的类型。这在限制对象行为时非常有用，比如当你想要提供一个简化的接口以避免某些操作或简化客户端代码时。

乍一看，这似乎是 Go 中支持的最让人困惑的嵌入类型。将接口嵌入到结构体中意味着什么，并不是立即清晰的。在这篇文章中，我们将慢慢探讨这项技术，并展示几个现实世界的例子。最后，您将看到背后的机制非常简单，并且这项技术在各种场景中都很有用。

让我们从一个简单的合成示例开始：

```go
type Fooer interface {
  Foo() string
}

type Container struct {
  Fooer
}
```

`Fooer` 是一个接口，而 `Container` 嵌入了它。回想一下第一部分，结构体中的嵌入会_提升_嵌入结构体的方法到嵌入它的结构体中。对于嵌入的接口，工作原理类似；我们可以将其可视化，好像 `Container` 有一个转发方法，如下所示：

```go
func (cont Container) Foo() string {
  return cont.Fooer.Foo()
}
```

但是 `cont.Fooer` 指的是什么？嗯，它只是实现了 `Fooer` 接口的任何对象。这个对象从哪里来？当初始化容器时，或者之后，将其分配给 `Container` 的 `Fooer` 字段。下面是一个例子：

```go
// sink接受一个实现了Fooer接口的值。
func sink(f Fooer) {
  fmt.Println("sink:", f.Foo())
}

// TheRealFoo是实现了Fooer接口的类型。
type TheRealFoo struct {
}

func (trf TheRealFoo) Foo() string {
  return "TheRealFoo Foo"
}
```

现在我们可以这样做：

```go
co := Container{Fooer: TheRealFoo{}}
sink(co)
```

这将打印 `sink: TheRealFoo Foo`。

发生了什么？**注意****Container****是如何初始化的；嵌入的****Fooer****字段被赋予了一个****TheRealFoo****类型的值。**我们只能将实现了 `Fooer` 接口的值分配给这个字段——任何其他值都将被编译器拒绝。由于 `Fooer` 接口嵌入在 `Container` 中，其方法被提升为 `Container` 的方法，这使得 `Container` 也实现了 `Fooer` 接口！这就是我们能够将 `Container` 传递给 `sink` 的原因；如果没有嵌入，`sink(co)` 将无法编译，因为 `co` 不会实现 `Fooer`。

您可能会想知道，如果嵌入在 `Container` 中的 `Fooer` 字段没有初始化，会发生什么；这是一个很棒的问题！发生的事情非常符合您的预期——该字段保留其默认值，对于接口来说就是 `nil`。所以这段代码：

```go
co := Container{}
sink(co)
```

将导致 `runtime error: invalid memory address or nil pointer dereference`。

这基本上涵盖了在结构体中嵌入接口的_方式_。剩下的一个更加重要的问题是——我们为什么需要这个？以下示例将展示标准库中的几个用例，但我想从一个来自其他地方的例子开始，它展示了我认为的这项技术在客户端代码中的最重要用途。

## 示例：接口包装器

这个示例归功于 GitHub 用户 valyala，摘自这条评论。

> This example is courtesy of GitHub user [valyala](https://github.com/valyala), taken from [this comment](https://github.com/golang/go/issues/22013#issuecomment-331886875).

假设我们想要一个带有一些额外功能的套接字连接，比如计算从中读取的总字节数。我们可以定义以下结构体：

```go
type StatsConn struct {
  net.Conn
  BytesRead uint64
}
```

`StatsConn` 现在实现了 `net.Conn` 接口，并且可以在任何期望 `net.Conn` 的地方使用。当使用适当的值初始化 `StatsConn` 的嵌入字段时，它“继承”了该值的所有方法；但是，关键的洞察是，我们可以拦截我们希望的任何方法，而保留其他所有方法不变。对于本示例中的我们的目的，我们想要拦截 `Read` 方法并记录读取的字节数：

```go
func (sc *StatsConn) Read(p []byte) (int, error) {
  n, err := sc.Conn.Read(p)
  sc.BytesRead += uint64(n)
  return n, err
}
```

对于 `StatsConn` 的用户来说，这个变化是透明的；我们仍然可以调用它的 `Read`，并且它会做我们期望的事情（由于委托给 `sc.Conn.Read`），但它还会进行额外的记账。

如前一节所示，正确初始化一个 `StatsConn` 至关重要；例如：

```go
conn, err := net.Dial("tcp", u.Host+":80")
if err != nil {
  log.Fatal(err)
}
sconn := &StatsConn{conn, 0}
```

这里 `net.Dial` 返回了一个实现 `net.Conn` 的值，所以我们可以使用它来初始化 `StatsConn` 的嵌入字段。

现在，我们可以将我们的 `sconn` 传递给任何期望 `net.Conn` 参数的函数，例如：

```go
resp, err := ioutil.ReadAll(sconn)
if err != nil {
  log.Fatal(err)
}
```

稍后，我们可以访问它的 `BytesRead` 字段来获取总数。

这是_包装_接口的一个示例。我们创建了一个实现现有接口的新类型，但重用了嵌入的值来实现大部分功能。我们可以通过在结构体中拥有一个显式的 `conn` 字段来实现这一点，而不是通过嵌入：

```go
type StatsConn struct {
  conn net.Conn
  BytesRead uint64
}
```

然后为 `net.Conn` 接口中的每个方法编写转发方法，例如：

```go
func (sc *StatsConn) Close() error {
  return sc.conn.Close()
}
```

但是，`net.Conn` 接口有 8 个方法。为它们全部编写转发方法既乏味又不必要。嵌入接口为我们免费提供了所有这些转发方法，我们只需要覆盖我们需要的那些。

为了更清楚地说明这一点，让我们考虑一个实际的例子：

```go
type ReadWriter interface {
  Read(p []byte) (n int, err error)
  Write(p []byte) (n int, err error)
}
type LimitedReadWriter struct {
  ReadWriter
  maxBytes int _// 限制可以读写的字节数_
}
func (lw *LimitedReadWriter) Read(p []byte) (n int, err error) {
  if len(p)  lw.maxBytes {
    p = p[:lw.maxBytes] _// 限制读取的字节数_
  }
  return lw.ReadWriter.Read(p) _// 调用嵌入接口的Read方法_
}
func (lw *LimitedReadWriter) Write(p []byte) (n int, err error) {
  if len(p)  lw.maxBytes {
    p = p[:lw.maxBytes] _// 限制写入的字节数_
  }
  return lw.ReadWriter.Write(p) _// 调用嵌入接口的Write方法_
}
```

在这个例子中，`LimitedReadWriter` 结构体嵌入了一个 `ReadWriter` 接口。它通过选择性地覆盖 `Read` 和 `Write` 方法，限制了可以读取和写入的字节数。同时，任何 `ReadWriter` 接口的其他方法都将保持不变，由嵌入的接口自动提供实现。

通过这种方式，`LimitedReadWriter` 能够限制对象的行为，同时复用 `ReadWriter` 接口的实现，而无需重写所有方法。这种技术在需要对现有接口进行扩展或限制时非常有用。

## 示例：sort.Reverse

> 1. **限制行为**：`reverse` 结构体通过覆盖 `Less` 方法来改变排序行为。原始的 `Less` 方法比较两个元素是否按顺序排列，而 `reverse` 的 `Less` 方法通过交换参数的顺序来实现逆序比较。
> 2. **高阶函数**：`sort.Reverse` 本身不执行排序，而是一个高阶函数，它返回一个新的 `reverse` 类型实例，这个实例包装了传入的 `sort.Interface`。这意味着原始的排序逻辑保持不变，只是比较逻辑被调整了。

Go 标准库中嵌入接口到结构体的经典示例是 `sort.Reverse`。这个函数的使用常常让 Go 新手感到困惑，因为根本不清楚它应该如何工作。

让我们从 Go 中排序的一个更简单的示例开始，通过排序一个整数切片。

```go
lst := []int{4, 5, 2, 8, 1, 9, 3}
sort.Sort(sort.IntSlice(lst))
fmt.Println(lst)
```

这将打印 `[1 2 3 4 5 8 9]`。它是如何工作的？`sort.Sort` 函数接受一个实现了 `sort.Interface` 接口的参数，该接口定义如下：

```go
type Interface interface {
  // Len是集合中的元素数量。
  Len() int
  // Less报告索引为i的元素是否应该在索引为j的元素之前排序。
  Less(i, j int) bool
  // Swap交换索引为i和j的元素。
  Swap(i, j int)
}
```

如果我们想要用 `sort.Sort` 对一个类型进行排序，我们将不得不实现这个接口；对于像 `int` 切片这样的简单类型，标准库提供了像 `sort.IntSlice` 这样的便利类型，它们接受我们的值并在其上实现 `sort.Interface` 方法。到目前为止都很好。

那么 `sort.Reverse` 是如何工作的呢？通过巧妙地使用嵌入在结构体中的接口。`sort` 包有这个（未导出的）类型来帮助完成这个任务：

```go
type reverse struct {
  sort.Interface
}

func (r reverse) Less(i, j int) bool {
  **return r.Interface.Less(j, i)**
}
```

到这个时候，应该很清楚这个做什么了；`reverse` 通过嵌入实现了 `sort.Interface`（只要它用实现了该接口的值初始化），并且它拦截了该接口的单个方法——`Less`。然后它将委托给嵌入值的 `Less`，但反转了参数的顺序。这个 `Less` 实际上是反向比较元素的，这将使排序工作反向进行。

为了完成解决方案，`sort.Reverse` 函数实际上是：

```go
func Reverse(data sort.Interface) sort.Interface {
  return &reverse{data}
}
```

现在我们可以这样做：

```go
sort.Sort(sort.Reverse(sort.IntSlice(lst)))
fmt.Println(lst)
```

这将打印 `[9 8 5 4 3 2 1]`。理解这里的关键是，调用 `sort.Reverse` 本身并不排序或反转任何东西。它可以被看作是一个高阶函数：它产生一个包装了传给它的接口并调整其功能的值。`sort.Sort` 的调用是发生排序的地方。

## 示例：context.WithValue

> **选择性覆盖**：尽管 `valueCtx` 实现了 `Context` 接口的所有方法，但它只覆盖了 `Value` 这一个方法来改变行为。对于其他方法，`valueCtx` 保持了 `Context` 的默认实现，即什么也不做。

`context` 包有一个叫做 `WithValue` 的函数：

```go
func WithValue(parent Context, key, val interface{}) Context
```

它“返回 `parent` 的一个副本，在其中与 `key` 关联的值是 `val`。”让我们看看它在内部是如何工作的。

忽略错误检查，`WithValue` 基本上可以归结为：

```go
func WithValue(parent Context, key, val interface{}) Context {
  return &valueCtx{parent, key, val}
}
```

`valueCtx` 是：

```go
type valueCtx struct {
  **Context**
  key, val interface{}
}

func (c *valueCtx) Value(key interface{}) interface{} {
  if c.key == key {
    return c.val
  }
  return c.Context.Value(key)
}
```

在这里，它再次使用了——**现在应该是熟悉的了**——嵌入接口到结构体的技巧。`valueCtx` 现在实现了 `Context` 接口，并且可以拦截 `Context` 的任何 4 个方法。它拦截了 `Value`：

```go
func (c *valueCtx) Value(key interface{}) interface{} {
  if c.key == key {
    return c.val
  }
  return c.Context.Value(key)
}
```

并且其余的方法保持不变。

## 示例：具有更受限接口的能力降级

这种技术相当高级，但它在标准库的许多地方都有使用。话虽如此，我不期望它在客户端代码中经常需要，所以如果你是 Go 新手，并且第一次阅读时没有理解，不要太担心。在获得更多 Go 经验后，再回来看看。

让我们从讨论 `io.ReaderFrom` 接口开始：

```go
type ReaderFrom interface {
    ReadFrom(r Reader) (n int64, err error)
}
```

实现了这个接口的类型可以从 `io.Reader` 中有意义地读取数据。例如，`os.File` 类型实现了这个接口，并将数据从它（`os.File`）所代表的读取器读入文件中。让我们看看它是如何做到的：

```go
func (f *File) ReadFrom(r io.Reader) (n int64, err error) {
  if err := f.checkValid("write"); err != nil {
    return 0, err
  }
  n, handled, e := f.readFrom(r)
  if !handled {
    return genericReadFrom(f, r)
  }
  return n, f.wrapErr("write", e)
}
```

它首先尝试使用 OS 特定的 `readFrom` 方法从 `r` 读取，例如，在 Linux 上，它使用 copy_file_range 系统调用在内核中直接进行两个文件之间的非常快速的复制。

`readFrom` 返回一个布尔值，表示它是否成功（`handled`）。如果没有，`ReadFrom` 尝试使用 `genericReadFrom` 进行“通用”操作，它被实现为：

```go
func genericReadFrom(f *File, r io.Reader) (int64, error) {
  return io.Copy(onlyWriter{f}, r)
}
```

它使用 `io.Copy` 将数据从 `r` 复制到 `f`，到目前为止还好。但是这个 `onlyWriter` 包装器是什么？

```go
type onlyWriter struct {
  io.Writer
}
```

有趣的是。所以这是我们熟悉的——通过在结构体中嵌入接口的技巧。但是，如果我们在文件中搜索，我们不会找到任何定义在 `onlyWriter` 上的方法，所以它没有拦截任何东西。那么为什么需要它呢？

为了理解为什么需要 `onlyWriter`，我们应该看看 `io.Copy` 做了什么。它的代码很长，所以我这里不会完全复制；但关键是要注意的是，如果它的目标实现了 `io.ReaderFrom`，它将调用 `ReadFrom`。但这使我们回到了一个循环中，因为我们在调用 `File.ReadFrom` 时最终进入了 `io.Copy`。这会导致无限递归！

现在开始变得清晰，为什么需要 `onlyWriter`。通过在调用 `io.Copy` 时包装 `f`，`io.Copy` 得到的不是一个实现 `io.ReaderFrom` 的类型，而只有一个实现 `io.Writer` 的类型。然后它将调用我们的 `File` 的 `Write` 方法，并避免 `ReadFrom` 的无限递归陷阱。

正如我之前提到的，这种技术是高级的。我认为重要的是要突出它，因为它代表了“在结构体中嵌入接口”工具的一个明显不同的使用方式，而且它在标准库中得到了广泛的使用。

在 `File` 中的使用是一个好的示例，因为它给 `onlyWriter` 一个明确命名的类型，这有助于理解它的作用。标准库中的一些代码避免了这种自文档化的模式，并使用匿名结构体。例如，在 `tar` 包中，它是这样做的：

```go
io.Copy(struct{ io.Writer }{sw}, r)
```

# 参考

[https://cloud.tencent.com/developer/article/1836620](https://cloud.tencent.com/developer/article/1836620)

[https://eli.thegreenplace.net/2020/embedding-in-go-part-1-structs-in-structs/](https://eli.thegreenplace.net/2020/embedding-in-go-part-1-structs-in-structs/)
