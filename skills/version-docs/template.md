# Karmada 版本号 版本发布！亮点[optional]！

Karmada 是开放的多云多集群容器编排引擎，旨在帮助用户在多云环境下部署和运维业务应用。凭借兼容 Kubernetes 原生 API 的能力，Karmada 可以平滑迁移单集群工作负载，并且仍可保持与 Kubernetes 周边生态工具链协同。

Karmada 版本号版本现已发布，本版本包含下列新增特性：

* 新增特性1
* 新增特性2
*

# 新特性概览

## 特性1

这里介绍新特性的用途，亮点等细节

例如：

在用户将业务从单集群迁移至多集群的过程中，如果资源已经被迁移到 Karmada 控制面，那么当控制面中的资源模板被删除时，成员集群中的资源也会随之删除。但在某些场景，用户希望能够保留成员集群中的资源。例如，作为管理员，在工作负载迁移过程中可能遇到意外情况（如云平台无法发布应用程序或 Pod 异常）， 需要回滚机制立刻恢复到迁移之前的状态，以便快速止损。

在 v1.12 版本，社区在 PropagationPolicy/ClusterPropagationPolicy API 中引入了 `PreserveResourcesOnDeletion` 字段，用于定义当控制面中的资源模板被删除时成员集群上资源的保留行为，如果设置为 `true`，...

## 特性2

# 致谢贡献者

Karmada 版本号 版本包含了来自 贡献者数 位贡献者的 代码提交次数 次代码提交，在此对各位贡献者表示由衷的感谢：

贡献者列表：  
这里通过表格和头像来列出此版本的贡献者  
例如：

| ^-^     | ^-^         | ^-^        |
|:--------|:------------|:-----------|
| @B1f030 | @chaosi-zju | @CharlesQQ |

![contributors](./resources/contributors.png)

# 参考资料

这里列出上述文本所使用的参考资料

例如：

[1] Karmada v1.12版本:[https://github.com/karmada-io/karmada/releases/tag/v1.12.0](https://github.com/karmada-io/karmada/releases/tag/v1.12.0)
