---
authors: Zzhiter
tags: [HTTP]
---

# 一文彻底搞懂 Cookie、Session、Token

**HTTP 是无状态的协议（对于事务处理没有记忆能力，每次客户端和服务端会话完成时，服务端不会保存任何会话信息）**：每个请求都是完全独立的，服务端无法确认当前访问者的身份信息，无法分辨上一次的请求发送者和这一次的发送者是不是同一个人。所以服务器与浏览器为了进行会话跟踪（知道是谁在访问我），就必须主动的去维护一个状态，这个状态用于告知服务端前后两个请求是否来自同一浏览器。

## Cookie

**HTTP cookie**，简称 **cookie**，又称“**网站／浏览 ＋ 魔饼／魔片**”等，是浏览[网站](https://zh.wikipedia.org/wiki/%E7%BD%91%E7%AB%99)时由[网络服务器](https://zh.wikipedia.org/wiki/%E7%BD%91%E7%BB%9C%E6%9C%8D%E5%8A%A1%E5%99%A8)创建并由[网页浏览器](https://zh.wikipedia.org/wiki/%E7%BD%91%E9%A1%B5%E6%B5%8F%E8%A7%88%E5%99%A8)存放在用户计算机或其他设备的小文本文件。

Cookie 使 Web 服务器能在用户的设备存储状态信息（如添加到在线商店购物车中的商品）或跟踪用户的浏览活动（如点击特定按钮、登录或记录历史）

1. 浏览器第一次访问服务端时，服务器此时肯定不知道他的身份，所以创建一个独特的身份标识数据，格式为 `key=value`，放入到 `Set-Cookie` 字段里，随着响应报文发给浏览器。
2. 浏览器看到有 `Set-Cookie` 字段以后就知道这是服务器给的身份标识，于是就保存起来，下次请求时会自动将此 `key=value` 值放入到 `Cookie` 字段中发给服务端。
3. 服务端收到请求报文后，发现 `Cookie` 字段中有值，就能根据此值识别用户的身份然后提供个性化的服务。

![](static/Tr80bj7BBoEV1vxhjZ5cQ7xQnYc.png)

### cookie 设置演示

接下来我们用代码演示一下服务器是如何生成，我们自己搭建一个后台服务器，这里我用的是 SpringBoot 搭建的，并且写入 SpringMVC 的代码如下。

```
@RequestMapping("/testCookies")
public String cookies(HttpServletResponse response){
    response.addCookie(new Cookie("testUser","xxxx"));
    return "cookies";
}
```

项目启动以后我们输入路径 `http://localhost:8005/testCookies`，然后查看发的请求。可以看到下面那张图使我们首次访问服务器时发送的请求，可以看到服务器返回的响应中有 `Set-Cookie` 字段。而里面的 `key=value` 值正是我们服务器中设置的值。

![](static/FJynbDd6ioEN2GxlOficENKWndd.jpg)

接下来我们再次刷新这个页面可以看到在请求体中已经设置了 `Cookie` 字段，并且将我们的值也带过去了。这样服务器就能够根据 `Cookie` 中的值记住我们的信息了。

![](static/FJu9bP6Ofo5h1XxLhZucbfHgnDd.jpg)

接下来我们换一个请求呢？是不是 `Cookie` 也会带过去呢？接下来我们输入路径 `http://localhost:8005` 请求。我们可以看到 `Cookie` 字段还是被带过去了。

![](static/HAspbmYjpo1dMXxnMxvcu4QTn4f.jpeg)

那么浏览器的 `Cookie` 是存放在哪呢？如果是使用的是 `Chrome` 浏览器的话，那么可以按照下面步骤。

1. 在计算机打开 `Chrome`
2. 在右上角，一次点击 `更多` 图标->`设置`
3. 在底部，点击 `高级`
4. 在 `隐私设置和安全性` 下方，点击网站设置
5. 依次点击 `Cookie`-> 查看所有 `Cookie和网站数据`

然后可以根据域名进行搜索所管理的 `Cookie` 数据。所以是浏览器替你管理了 `Cookie` 的数据，如果此时你换成了 `Firefox` 等其他的浏览器，因为 `Cookie` 刚才是存储在 `Chrome` 里面的，所以服务器又蒙圈了，不知道你是谁，就会给 `Firefox` 再次贴上小纸条。

其实就是很多 KV 对。

![](static/Larub3arFoLwbNxspw1crzc5neb.png)

### **Cookie 中的参数设置**

说到这里，应该知道了 `Cookie` 就是服务器委托浏览器存储在客户端里的一些数据，而这些数据通常都会记录用户的关键识别信息。所以 `Cookie` 需要用一些其他的手段用来保护，防止外泄或者窃取，这些手段就是 `Cookie` 的属性。

下面我就简单演示一下这几个参数的用法及现象。

#### **Path**

设置为 `cookie.setPath("/testCookies")`，接下来我们访问 `http://localhost:8005/testCookies`，我们可以看到在左边和我们指定的路径是一样的，所以 `Cookie` 才在请求头中出现，接下来我们访问 `http://localhost:8005`，我们发现没有 `Cookie` 字段了，这就是 `Path` 控制的路径。

![](static/SqZobVbU3oxSqXxeu53c0CmbnLf.jpeg)

#### **Domain**

设置为 `cookie.setDomain("``localhost``")`，接下来我们访问 `http://localhost:8005/testCookies` 我们发现下图中左边的是有 `Cookie` 的字段的，但是我们访问 `http://172.16.42.81:8005/testCookies`，看下图的右边可以看到没有 `Cookie` 的字段了。这就是 `Domain` 控制的域名发送 `Cookie`。

![](static/U5iXbIlVroEsIZxkgIPc9vaZnn5.jpeg)

接下来的几个参数就不一一演示了，相信到这里大家应该对 `Cookie` 有一些了解了。

### 小总结

Cookie 就是鉴权的基石。Cookie 作为前端存储数据的一种方式，相比于 localStroage 等存储方式，最方便的就在于它可以借助浏览器的能力，在前端无感知的情况下种下数据。

所以，一般网页鉴权的过程是：

- 在登录接口登陆成功后，通过 HTTP 返回头 Response 里的 Set-Cookie 字段，直接种到浏览器的当前域名下
- 之后浏览器发起的一系列请求，HTTP 请求头 Request 里的 Cookie 字段会带上 sessionId，后端去校验 sessionId

**Cookie 的优势在于不用前端主动去存储标记，也不用去关心这个标记会存在多久，因为 Cookie 支持配置****Expires / Max-Age****字段，浏览器可以根据本地时间，决定 Cookie 是否过期**。**相当于管理权交给浏览器了**。值得注意的是本地时间可能会存在不准，会导致 Cookie 无法在服务端规定时间后过期。

## **Session**

> Cookie 是存储在客户端方，Session 是存储在服务端方，客户端只存储 `SessionId`

在上面我们了解了什么是 `Cookie`，既然浏览器已经通过 `Cookie` 实现了有状态这一需求，那么为什么又来了一个 `Session` 呢？这里我们想象一下，如果将账户的一些信息都存入 `Cookie` 中的话，一旦信息被拦截，那么我们所有的账户信息都会丢失掉。所以就出现了 `Session`，在一次会话中将重要信息保存在 `Session` 中，浏览器只记录 `SessionId` 一个 `SessionId` 对应一次会话请求。

```
@RequestMapping("/testSession")
@ResponseBody
public String testSession(HttpSession session){
    session.setAttribute("testSession","this is my session");
    return "testSession";
}

@RequestMapping("/testGetSession")
@ResponseBody
public String testGetSession(HttpSession session){
    Object testSession = session.getAttribute("testSession");
    return String.valueOf(testSession);
}
```

这里我们写一个新的方法来测试 `Session` 是如何产生的，我们在请求参数中加上 `HttpSession session`，然后再浏览器中输入 `http://localhost:8005/testSession` 进行访问可以看到在服务器的**返回头中在****Cookie****中生成了一个****SessionId**。然后浏览器记住此 `SessionId` 下次访问时可以带着此 Id，然后就能根据此 Id 找到存储在服务端的信息了。

![](static/EfuIb2o5YomuY8x7pQEcSDFTnPh.jpeg)

所以可以看到，我们设置的 sessionID，是存放到 cookie 里面了。

### 示例

可以看下面的飞书的一个请求里面的 Cookie，**session=XN0YXJ0-4b6j8f94-352a-4f9f-af6a-afe28ec5309e-WVuZA; 应该就是 sessionId。**

```go
curl 'https://ifs1y70.feishu.cn/space/api/user/?synced_block_host_token=BPoedGChEoeot1xZ7CccENujnFh&synced_block_host_type=22' \
  -H 'authority: ifs.feishu.cn' \
  -H 'accept: application/json, text/plain, */*' \
  -H 'accept-language: zh-CN,zh;q=0.9' \
  -H 'ccm-scene: web' \
  -H 'context: request_id=NGDOVWeFqdB7-e81e1dada5583a2dc7997c4daead30899;os=windows;app_version=1.0.13.6840;os_version=10;platform=web' \
  -H 'cookie: __tea__ug__uid=5820261692934508518; passport_web_did=7271098387364052994; QXV0aHpDb250ZXh0=b5fb847906ca42fca4942f1167b4b8ca; trust_browser_id=571f0da9-d5ad-410e-8e8a-1a9abe2cadec; **session=XN0YXJ0-4b6j8f942a-4f9f-af6a-afe28ec5309e-WVuZA; **session_list=XN0YXJ0-4b6j8f94-352a-4f9f-af6a-afe28ec5309e-WVuZA; is_anonymous_session=; lang=zh; et=3f3a19f239485d61fa6103a628816bc4; ccm_cdn_host=//lf-scm-cn.feishucdn.com; vt=1; ot=3f3a19f239485d61fa6103a628816bc4; bitable_tableId_viewId_history=%7B%22Zm3Db2viewId%22%3A%22vewBruPCr8%22%7D%7D; me820e6cbd8dac9935df88bce4c9c0f23be1847b4a={%22filterOption%22:{%22rankType%22:1%2C%22order%22:%22desc%22}%2C%22objectOwnerType%22:1%2C%22recentOpenTab%22:1%2C%22timeColumnKey%22:%22createTime%22}; Hm_lvt_e78c0cb1b97ef970304b53d2097845fd=1702989009; _gcl_au=1.1.934695900.1702989102; _ga=GA1.2.205832138.1692934509; _ga_VPYRHN104D=GS1.1.170393.1703934058.60.0.0; locale=zh-CN; lgw_csrf_token=b36189c6fac5d8c08286f0760aef15ecd0049dc8-1705500756; _csrf_token=94913f3267acf247bba465ae570654134b9502ff-1705929039; js_version=1; site_env=pre=0; _uuid_hera_ab_path_1=7327544452044668930; swp_csrf_token=172c8d03-7060-48d8-92d8-f9bd4b9f43cb; t_beda37=7f583524d42f3aa3ccaa1d64b2acf4dd3eb23909648631cde7e439bff7675d43; passport_app_access_token=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MDYxNDE1NDcsInVuaXQiOiJldV9uYyIsInJhdyI6eyJtX2FjY2Vzc19pbmZvIjp7IjE0MyI6eyJpYXQiOjE3MDYwOTQ4MjYsImFjY2VzcyI6dHJ1ZX0sIjI5Ijp7ImlhdCI6MTcwNjA5NTQ4NCwiMDZkY2YzY2EyOWI5NTQ1MjNiYzNlNzk0MGYxMmZkMmYyMSJ9fQ.tIJ3HsRj077RxxsnSdE3isZVz1xOYnS8J2GmLrUy5aw8rTCZc2ovGf_2LDMNdqNJsKrLWSjoG-YHhcoX4DfKZA; sl_session=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MDYxNDE5NTAsInVuaXQiOiJldV9uYyIsInJhdyI6eyJtZXRhIjoiQVdKVkFRSGFnSUFCWWxVQkFabkNBQUZrNkNGMW1jQUFBbVRvSVhXWndBQUNaT2doNEtSQUFBSUNLZ0VBUVVGQlFVRkJRVUZCUVVKck5rTklaM1puVTBGQlVUMDkiLCJzdW0iOiI3MDI5ZWU2NTRlMzYwYmExNjQ4MGQ0MmVmOWU1MzYwNmRjZjIiwiaWF0IjoxNzA2MDk4NzUwLCJzYWMiOnsiVXNlclN0YWZmU3RhdHVzIjoiMSJ9LCJsb2QiOm51bGwsIm5zIjoibGFyayIsIm5zX3VpZCI6IiIsIm5zX3RpZCI6IiIsIm90IjoxfX0._iUpeoP9V0CqK7HUi_GpTJbvyl_3LiXLF9YafFD-y8ANMib6V-c1PUdicbvCAP37yTwVeu0n5mVvUangX2av3g' \
  -H 'doc-biz: Lark' \
  -H 'doc-os: windows' \
  -H 'doc-platform: web' \
  -H 'f-version: docs-1-19-1705665647996' \
  -H 'referer: https://ifs1y70.feishu.cn/wiki/wikcnDpmD2L2Hon4fQ6JTrSWRVa' \
  -H 'request-id: NGDOVWeFqdB7-e81e1dada5583a2dc7997c6a0ce094daead30899' \
  -H 'rpc-persist-lane-c-lark-uid: 0' \
  -H 'sec-ch-ua: "Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Windows"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-origin' \
  -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' \
  -H 'x-csrftoken: 94913f3267acf247bba465ae570654134b9502ff-1705929039' \
  -H 'x-request-id: NGDOVWeFqdB7-e81e1dada5583a2dc7997c6a0ce094daead30899' \
  -H 'x-tt-logid: 02170609875241700000000000000000000ffff602a8b510fa232' \
  -H 'x-tt-trace-id: NGDOVWeFqdB7-e81e1dada5583a2dc7997c6a0ce094daead30899' \
  --compressed
```

对应的 Cookie 列表

![](static/AYhwbEj8pogY9GxprJJc71QWn1d.png)

Set-Cookie 之后，每次请求都会带上 Cookie。这叫基于 Cookie 的 Session，因为 SessionId 是存在 Cookie 里面的。

![](static/CHDJbyB1XoJ3nIxuDLycT2FSnsf.png)

继续上个请求，此时我们访问路径 `http://localhost:8005/testGetSession`，发现得到了我们上面存储在 `Session` 中的信息。那么 `Session` 什么时候过期呢？

- 客户端：和 `Cookie` 过期一致，如果没设置，默认是关了浏览器就没了，即再打开浏览器的时候初次请求头中是没有 `SessionId` 了。
- 服务端：服务端的过期是真的过期，即服务器端的 `Session` 存储的数据结构多久不可用了，默认是 30 分钟。

![](static/LIdobuKPeokVQNxWxP5cGetJnPf.jpeg)

既然我们知道了 `Session` 是在服务端进行管理的，那么或许你们看到这有几个疑问，`Session` 是在在哪创建的？`Session` 是存储在什么数据结构中？接下来带领大家一起看一下 `Session` 是如何被管理的。

`Session` 的管理是在容器中被管理的，什么是容器呢？`Tomcat`、`Jetty` 等都是容器。接下来我们拿最常用的 `Tomcat` 为例来看下 `Tomcat` 是如何管理 `Session` 的。在 `ManageBase` 的 `createSession` 是用来创建 `Session` 的。

```
@Override
public Session createSession(String sessionId) {
    //首先判断Session数量是不是到了最大值，最大Session数可以通过参数设置
    if ((maxActiveSessions >= 0) &&
            (getActiveSessions() >= maxActiveSessions)) {
        rejectedSessions++;
        throw new TooManyActiveSessionsException(
                sm.getString("managerBase.createSession.ise"),
                maxActiveSessions);
    }

    // 重用或者创建一个新的Session对象，请注意在Tomcat中就是StandardSession
    // 它是HttpSession的具体实现类，而HttpSession是Servlet规范中定义的接口
    Session session = createEmptySession();

    // 初始化新Session的值
    session.setNew(true);
    session.setValid(true);
    session.setCreationTime(System.currentTimeMillis());
    // 设置Session过期时间是30分钟
    session.setMaxInactiveInterval(getContext().getSessionTimeout() * 60);
    String id = sessionId;
    if (id == null) {
        id = generateSessionId();
    }
    session.setId(id);// 这里会将Session添加到ConcurrentHashMap中
    sessionCounter++;

    //将创建时间添加到LinkedList中，并且把最先添加的时间移除
    //主要还是方便清理过期Session
    SessionTiming timing = new SessionTiming(session.getCreationTime(), 0);
    synchronized (sessionCreationTiming) {
        sessionCreationTiming.add(timing);
        sessionCreationTiming.poll();
    }
    return session
}
```

到此我们明白了 `Session` 是如何创建出来的，创建出来后 `Session` 会被保存到一个 `ConcurrentHashMap` 中。可以看 `StandardSession` 类。

```
protected Map<string, session> sessions = new ConcurrentHashMap<>();
```

到这里大家应该对 `Session` 有简单的了解了。

> Session 是存储在 Tomcat 的容器中，所以如果后端机器是多台的话，因此多个机器间是无法共享 Session 的，此时可以使用 Spring 提供的分布式 Session 的解决方案，是将 Session 放在了 Redis 中。

### 问题

对于前端来说，Cookie 种 sessionId 这个方案看起来还是挺理想的，解决了头疼的 HTTP 无状态问题；但对于服务端而言，可就不太友好了，每个人只需要保存自己的 sessionId，而服务器要保存所有人的 sessionId ！如果访问服务器多了， 就得有成千上万，甚至几十万个。

这对服务器说是一个巨大的开销 ， 严重的限制了服务器扩展能力， 比如说我用两个机器组成了一个集群， 一个人通过机器 A 登录了系统， 那 sessionId 会保存在机器 A 上， 假设那个人的下一次请求被转发到机器 B 怎么办？机器 B 可没有这个人的 sessionId 啊。这时会有两种方案来解决：

1. 将机器 A 上的 sessionId 复制到机器 B 上

![](static/VOSvbhlrNoghh5xAUPHcxiIwnNh.png)

1. 将所有的 sessionId 存在单独一个机器上

![](static/RygUb9Xr8otb2Kxc8SocFnhMnoc.png)

可以看到方案 1 的花销过于大。尤其对于千万级别用户的应用来说，将每个机器之间的 sessionId 同步，耗时耗力还不能保证准确性；方案 2 看似解决了方案 1 同步问题，但新的问题又随之而来，如果机器 C 宕机了，我岂不是拿不到数据，所有用户都要重新登录。

所以这个 sessionId 看似不是一个好的鉴权方案，虽然方便了前端，但对于服务端的压力过于庞大。那有没有一种前后端都比较方便的鉴权方式呢？答案是肯定的。

在使用 Session 中，一般在服务端的技术实现方式是用分布式存储，比如 redis 或者 memcache ，以 key-value 的形式存储 SessionId 和 Session，其中每个 SessionId 对应的是某个用户的会话信息。如果客户端 Cookie 失效，或者服务端的 Session 过期，那么就会提醒客户端用户重新登录获取新的 SessionId。在 Cookie 和 SessionId 均有效的情况下，服务端获取到 SessionId，通过匹配系统中是否存在对应的 Session，并解析会话内容，如果验证通过，即进行对应的业务操作；否则提示客户端验证失败。

## Token

> `Token` 相比较于 `Session` 的优点在于，当后端系统有多台时，由于是客户端访问时直接带着数据，因此无需做共享数据的操作。

服务端存储用户会话信息，客户端以 Cookie 存储会话的 SessionId，通过 HTTPS 协议，以及设置 Cookie 的属性 HttpOnly=true，还有设置 Cookie 和 Session 的有效期增强安全性，是不是就一劳永逸了呢？其实并不是，Cookie 有可能被浏览器禁用；而且 Cookie 虽然可以在二级域名之间共享，但是依旧存在跨域问题。更重要的是，服务端存储所有用户的会话信息，开发维护成本高。基于此，逐渐出现了无需服务端记录任何状态，且可跨域的鉴权方法，**那就是 Token**。

Token 称作令牌，是一种服务端无状态的认证方式，将关键的信息拼装成字符串，并进行加密，类似于证书签名。一般组成 Token 的信息可以是 uid+time+sign[+ 固定参数]，其中

- uid: 用户唯一身份标识
- time: 当前时间的时间戳
- sign: 签名, 使用 hash/encrypt 压缩成定长的十六进制字符串，以防止第三方恶意拼接
- 固定参数(可选)

有了 Token，那么是如何处理数据和交互的呢？客户端在用户登录后，将用户信息给到服务端；服务端经过计算返回 Token 给客户端；客户端存储 Token，可以是 Cookie，也可以客户端的 localStorage；之后在每次请求的时候，客户端将 Token 放入 HTTPS 的**请求头**或者 **url** 中；服务器拿到 Token 解析并验证合法性。

### JWT

Token 只是一种规范，而我们常见的 JWT（JSON WEB TOKEN），就是 Token 的一种实现方式。JWT 的基本数据结构是 Header.Payload.Signature；其中 Header 部分是一个 JSON 对象，用来记录该 Token 所使用的加密算法，以及 Token 类别，比如：

```javascript
{
  "alg": "HS256",   //签名的算法
  "typ": "JWT"      //token类别
}
```

Payload 部分也是一个 JSON 对象，用来描述 Token 签发的时间/有效时间/签发人/编号等信息，在该部分，还可以自定义一些额外的字段，用来表达用户的私有信息，比如用户的名字/手机号等信息；

Signature 是对 Header 和 Payload 两部分，使用 alg（签名算法）得到的签名，用以验证数据一致，防止数据被篡改。最终，Header 和 Payload 部分，使用 Base64URL 转换为字符串；Signature 根据服务端指定的一个密钥，加上 Header 和 Payload 的转换后的字符串，再使用 alg 算法得到。

![](static/EPW7bKEuCoa3vtxBJLqcaoKSnNu.png)

### 优点

使用 JWT 的优点：

1. 简洁：可以通过 `URL`,`POST` 参数或者是在 `HTTP` 头参数发送，因为数据量小，传输速度也很快
2. 自包含：由于串包含了用户所需要的信息，避免了多次查询数据库
3. 因为 Token 是以 Json 的形式保存在客户端的，所以 JWT 是跨语言的
4. 不需要在服务端保存会话信息，特别适用于分布式微服务

### JWT 示例

看一个 openai 的请求：

![](static/TPdEbBrz5oUR3Yx9rIicSrbRnII.png)

Authorization 对应的 Value，Bearer 后面的就是对应的 JWT Token，解码出来的数据为：

![](static/KoFZbcHq9oyfYkxH43WcYZ6bnWc.png)

### Refresh_token

当 token 过期时，客户端需要重新向服务端发送请求以获取新的 token。一种常见的做法是，服务端在返回 token 时，同时返回一个刷新 token（refresh token），用于获取新的 token。客户端在 token 过期时，可以使用刷新 token 向服务端请求新的 token，而无需重新输入用户名和密码。服务端会验证刷新 token 的有效性，并根据验证结果返回新的 token。

当 token 过期时，客户端需要重新向服务端发送请求以获取新的 token。服务端会验证 token 的有效性，如果 token 已过期，则会返回一个错误响应，客户端根据错误类型（例如 401 Unauthorized）判断 token 过期，并重新发起身份认证请求，例如重新登录或使用 refresh token 获取新的 token。客户端在获取到新的 token 后，可以更新本地存储的 token，并在以后的请求中使用新的 token 进行身份验证。

## 其他

### cookie 和 session

最近学到了 cookie 和 session，也用这两种技术做过身份认证和保持用户登录状态。cookie 的身份认证: 服务器获取请求中的用户名和密码，判断和数据库的数据是否一致，如果数据一致，就回写用户名和密码的 cookie 到浏览器，跳转到主页。如果数据不一致就响应用户或密码错误。

cookie 的保持登录状态: 浏览器请求其他网页时，服务器判断是否有 cookie 数据，如果有就证明用户是在线的，去拿数据库数据显示到页面。如果没有，那么证明用户不在线，需要重新登陆。session 的身份认证:获取用户数据和数据库数据判断，如果数据相同就开辟 sessoon，并将数据存入 session 域，回写 sessionID，跳转到主页。如果不相同，就响应用户和密码错误。

session 的保持登陆状态: 浏览器访问其他页面，判断 sessionID 是否一致，如果 id 一致就证明用户是在线的，去获取 session 域里的数据再去拿数据库数据，将数据显示到页面上。如果 id 不一致，用户并不在线，需要重新登录。

**cookie 和 session 最大的区别是数据存储的位置不同，cookie 是将数据存储在浏览器中的，session 是将数据存储在服务器中的。所以就单论数据安全性来说，cookie 是非常低的，而 session 是相对较高的。**

cookie 是默认一次会话，但是可以做到持久化会话，只需要设置 cookie 的时长。其实 session 如果不设置 sessionID 的时长，它也只是一次会话，浏览器关闭了，下次访问因为 id 不一致，一样拿不到数据。核心还是 sessionId。

cookie 这种特性根本不适合保存用户数据，因为当要存储多个用户数据时，操作就会相当繁琐，需要保存多个 cookie，服务器还要甄别哪个 cookie 是哪个用户的。session 则很适合用来存储数据，因为服务器会为每个用户开辟独立的 session，也就是说用户信息存储在各自的 session 里，并且 sessionID 每一个都不一致。

### sessionID 的安全性

给每个 session 一个 ID，一方面用来方便自己查询，另一方面把这个 ID 给用户，用户下一次访问的时候就可以不用用户名和密码，而是直接使用这个 ID 来表明自己的身份。

首先，这个 ID 安全吗？这个 ID 比直接传用户名和密码安全吗？你很容易会想到，本来用户名和密码的组合还特地设置地比较复杂，你这换一组数字就代替了，是不是太不安全了？

我们知道 http 协议本身是完全不加密的，如果使用用户名和密码，第一次访问是放在 http 头中，后边自动保存了密码就会放在 cookie 中，这些都完全没有加密，它的安全性基本为 0，就是裸奔了，只要被窃取，那就丢失了

所以，**就这个意义来讲，sessionID 的安全性跟使用用户名和密码没什么区别**

但是其实，虽然 http 本身不能加密，但是有些软件什么的，能在应用层面手动给你加密，比如 QQ 就会使用户名密码加临时验证码联合哈希，sessionID 加一个时间戳简单加密也是非常常用的方法

而且因为 sessionID 本身有有效期，即使丢了，也可能很快失效，造成的损失可能没那么大，而用户名跟密码丢了，那就大了

所以总结就是：

然后，使用 sessionID 有哪些好处：

### 一个小问题

我登录成功后有个坏蛋截获 cookie 里的 session Id 或者 token，然后他的请求里带上这些凭证，是不是就可以冒充“我”，随便下单了？！

![](static/Fab6blOVDoINIFxO8JQclUd0nCe.webp)

首先在 https 普及的今天黑客想通过“拦截”的手段获取你的 token 几乎不可能，但是确实有黑客能够通过使用流氓软件的形式盗取你浏览器的 cookie 从而登录你的网站账号，但是如果是对安全性要求高的服务一般都会要求你进行二次验证。所以电脑不要裸奔并且安装来路不明的软件，虽说不至于盗取你的支付信息，但是拿你的 b 站账号乱发东西还是没问题的。

## 参考

[https://www.bilibili.com/video/BV1ob4y1Y7Ep](https://www.bilibili.com/video/BV1ob4y1Y7Ep)

[https://mp.weixin.qq.com/s/A-f_LxJNCVXJ-gQ47OO-iA](https://mp.weixin.qq.com/s/A-f_LxJNCVXJ-gQ47OO-iA)
