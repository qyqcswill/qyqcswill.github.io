---
title: spring-boot容器化[1]
---


> `pod` 可以理解成一个豌豆，里面运行的容器是一粒粒豌豆，但是kubernetes在启动 `pod` 的时候同时启动启动一个pause的容器，这个容器其实就可以理解成豌豆荚。基于此，我们清楚，一个`pod`可以包含多个container, 每个容器（豌豆）共享一个pause容器（豌豆荚），这个parse容器主要作用其实为了做网络栈和存储共享。但是正常来说，一个`pod`只运行一个业务容器。


关于 `pod` 的服务质量，参考官方文档[^kubernetes-qos] 这里官方将相关的服务质量分为三种

* Guaranteed
* Burstable
* BestEffort

这里具体的解释参考官方的内容，官方肯定比我写的好。

### memory

针对java应用内存设置比较麻烦，首先`pod`需要设置相关的cpu和 memory 的limit/request。但是jvm也需要配置`-Xms/-Xmx`，按照jvm的优化 `-Xms=-Xmx` ，所以正常来说 `pod` memory 的request=limit，用于保证内存稳定。在容器化初期，可能很多人都踩过应用程序`OOM`的坑，即使设置-Xms/-Xms参数，依旧会`OOM`。这里主要原因是jvm感知的宿主机内存，而非容器的内存，从而导致`OOM`。JDK8分别在8u131和8u191针对容器做了相关的jVM参数优化，这里我们参考 [^8u191] 的release-note。我们重点关注如下jvm参数:
```java
-XX:+UseContainerSupport
-XX:InitialRAMPercentage
-XX:MaxRAMPercentage
-XX:MinRAMPercentage
```
其实这些参数主要代替 -XX:InitialRAMFraction、-XX:MaxRAMFraction、-XX:MinRAMFraction。而且这些参数是按着百分比设置，比如，我们设置`pod`的 `request=limit=4G`，我们设置  `-XX:MaxRAMPercentage=75.0`，这里就相当于设置 `-Xmx=3g`，其他 `Xmn` 和 `Xms` 同理。这样就解决容器`OOM` 的问题。

### cpu
其实很多人都发现，java应用在容器化的时候，启动速度会变慢很多。这个时候就需要看你 qos中 cpu的`limit/request`的配置，如果你配置了 `limit`，这里就限制容器可使用的cpu核心数量。主要还是`spring` 上面，`IOC`大量非反射，动态代理，类加载过程都导致应用程序启动特别慢，如果你还增加了链路追踪的`java-agent`，恭喜你，你的应用启动时间可能还会翻倍。其实这也是没有办法的事情，框架的便利总会牺牲一些东西。毕竟裸程序启动，java 程序使用了整个宿主机的cpu。在 `kubernetes` 中，qos会限制容器使用的cpu的大小，而且spring-boot应用的启动速度和cpu的关联特别大，这里，我们参考文章 [^java-k8s]。这篇文章不推荐我们设置相关cpu的limit。

但是关于慢启动的问题。在下一篇文章中，我们继续讨论

### 总结
 * memory: request=limit
 * cpu: 设置request，不设置 limit(属于妥协的方案)
 * MinRAMPercentage/MaxRAMPercentage/InitialRAMPercentage 取值75.0到80.0

Dockerfile示例如下：
```Dockerfile
FROM openjdk:jre-8


ADD target/xxx.jar ./

ENTRYPOINT java \
-XX:+UseContainerSupport \
-XX:InitialRAMPercentage=75.0 \
-XX:MaxRAMPercentage=75.0 \
-XX:MinRAMPercentage=75.0 \
$JAVA_OPTS -jar xxx.jar
```

---
[^kubernetes-qos]: https://kubernetes.io/zh/docs/tasks/configure-`pod`-container/quality-service-`pod`/
[^8u191]: https://www.oracle.com/java/technologies/javase/8u191-relnotes.html
[^java-k8s]: https://medium.com/faun/java-application-optimization-on-kubernetes-on-the-example-of-a-spring-boot-microservice-cf3737a2219c
