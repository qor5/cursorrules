# 团队开发规范

## 目录

1. [治理与代码整洁](#governance)
2. [错误处理与接口](#errors-interfaces)
3. [Go 命名与序列化](#naming-serialization)
4. [配置文件规范（confx）](#configuration)
5. [GORM 使用规范](#gorm-usage)
6. [数据库与迁移实践](#db-migrations)
7. [Proto 与 API 指南](#proto-api)
8. [运行时与部署](#runtime-deployment)
9. [库使用偏好](#library-preferences)
10. [设计模式与注意事项](#design-cautions)

---

<a id="governance"></a>

## 1. 治理与代码整洁

- 严审 AI（Cursor）生成代码：提交前需严格人工审查。
- 移除未使用代码：保持代码库精简、可维护。
- 英文化代码与注释；文档需有英文版本。
- 拒绝过度注释：优先通过清晰命名与结构提升可读性；仅在必要时添加简明注释。

> 💡 提示：当你准备写注释时，先尝试改进命名与抽象，让代码自身表达语义。

---

<a id="errors-interfaces"></a>

## 2. 错误处理与接口

- 错误包装策略：
  - 外部函数返回的错误必须使用 `github.com/pkg/errors`（如 `errors.Wrap`、`errors.WithStack`）。
  - 新建错误使用 `errors.New`/`errors.Errorf`，保留错误起源。
  - 若能够保证错误已经记录了调用栈的前提下可直接透传。
- 错误比较统一使用 `errors.Is`，禁止 `==` 比较。
- gRPC 边界（方法实现或中间件）强制使用 `statusx`。注意 `statusx.Wrap` 若遇到已是 status 错误，会以底层 status 为准，避免多层包裹信息丢失或重复。
- 避免使用 `panic`/`log.Fatal`，优先返回 `error`。
- 所有 goroutine 必须具备 `recover` 逻辑，避免进程级崩溃。
- IO 方法签名：必须以 `ctx context.Context` 作为首参，并返回 `error`。
- interface 实现校验：提供编译期断言，防止后续变更导致潜在不匹配。

```go
// Compile-time interface assertion example
var _ MyInterface = (*MyImpl)(nil)
```

- 当返回类型可为 interface 并且可能为 `nil` 时，直接返回该 interface 类型而非具体类型，避免“typed-nil”陷阱。

```go
// typed-nil pitfall: e has a concrete type, therefore e != nil
var e error = func() *errFoo { return nil }()
// e != nil is true
```

---

<a id="naming-serialization"></a>

## 3. Go 命名与序列化

- 常量：
  - 业务字符串常量值使用 SCREAMING_SNAKE_CASE，例如：`const StatusActive = "STATUS_ACTIVE"`。
  - 若作为配置项的选项值，使用 kebab-case，例如：`const ModeReadOnly = "read-only"`。
- 缩写（Acronyms）在标识符中应全大写（如 `userID`、`HTTPServer`），除非位于标识符起始处（如 `idGenerator`）。第三方生成代码可例外。
- 序列化与配置字段命名：
  - `json` tag 与 `confx` YAML 字段统一使用 `camelCase`。
  - 保持缩写大写（如 `json:"userID"`, `json:"readTimeoutMS"`），避免混用（如 `userId`）。
  - 第三方生成代码或外部系统对接的命名可例外。
  - 非必要不使用 `omitempty`，避免隐藏逻辑错误。
- 包名与 import alias 必须全小写；多词建议 snake_case（如 `user_service`），除非本就很清晰，例如：`ledgerv1`。

<a id="configuration"></a>

## 4. 配置文件规范（confx）

- 默认 embed 的 YAML 必须列出对应 cmd 的全部可配置项，即使为零值；
- 以可读性优先，所有字段显式声明，便于审查、对比与文档化；
- 非默认 YAML 可按需裁剪（不强制）。
- 示例（camelCase，对齐缩写大写约定）：

```yaml
# Default config (embedded)
server:
  port: 8080
  readTimeoutMS: 5000
  writeTimeoutMS: 5000
database:
  host: localhost
  port: 5432
  username: ""
  password: ""
features:
  enableAudit: true
  maxRetries: 0
```

---

<a id="gorm-usage"></a>

## 5. GORM 使用规范

- 禁用关联写入：不得使用 `db.Association(...)`（及 `Replace`、`Append` 等）。必须启用 `gormx.OmitAssociationsPlugin` 避免黑盒修改。
- 所有 `gorm.DB` 调用必须保证先前有调用 `.WithContext(ctx)`。
- `Model()` 传类型非实例：例如使用 `db.Model(&User{})`，避免实例字段被隐式拼接成查询条件。
- 字符串主键查询（如 UUID）：不得将主键直接传给 `First()`，必须显式 `WHERE` 条件。

```go
// Good
db.Where("id = ?", uuid).First(&model)

// Avoid
// db.First(&model, uuid) // may generate invalid SQL
```

- 非必要避免使用 `UpdateColumn`，因为它不会触发 Hook。

---

<a id="db-migrations"></a>

## 6. 数据库与迁移实践

- 破坏性操作前先校验：在执行 `DELETE`/`TRUNCATE` 前，应准备并运行对应 `SELECT` 确认目标记录。
- 大批量 DML 分批执行：`INSERT`/`UPDATE`/`DELETE` 应带条件并分批运行。
- 架构变更治理（MVP 之后）：
  - 除新增列外的所有表结构修改，必须经至少两位审查人确认。
  - 生产环境中删除或重命名列默认禁止；仅在多方审查并有明确迁移方案时可执行。
- 主键策略：
  - 强制使用全局唯一标识符（如 UUID、XID、Snowflake），禁止使用自增 ID；
  - 禁止联合主键（Composite Primary Key）；使用单字段主键 + 业务层唯一约束替代；
  - 采用单主键可避免在查询时必须将联合唯一约束的所有字段全部带入 WHERE 条件，降低易错率、减少遗漏并提升可维护性；
  - 同时更适应分库分表、跨系统数据合并以及未来的分布式系统需求。
- 禁用 `lib/pq` 作为 PostgreSQL 驱动。

> 💡 另见独立规则：`1050-database-design`（审计字段置顶、snake_case、软删除及过滤唯一/索引、禁用物理外键、索引过滤软删除等）。

---

<a id="proto-api"></a>

## 7. Proto 与 API 指南

- 导入别名：避免不必要的别名；使用语义清晰的版本化别名。

```go
// Good
import authv1 "github.com/theplant/ciam-next/gen/ciam/auth/v1"

// Avoid
// import authpb "github.com/theplant/ciam-next/gen/ciam/auth/v1"
```

- 模型字段：proto model 定义不包含 `deleted_at`。软删除属于数据库实现细节，不应暴露于 API 层。

---

<a id="runtime-deployment"></a>

## 8. 运行时与部署

- gRPC 负载均衡：在部署环境中使用 headless Service + round-robin，确保请求级负载均衡，并正确配置客户端策略。

---

<a id="library-preferences"></a>

## 9. 库使用偏好

- 若扩展包提供等价方法，优先使用扩展包（如 `lox.Must`、`filepathx.Join`、`clonex.Clone`、`clonex.CloneSlowy`、`jsonx.Marshal`），以获得更好的错误处理、性能或功能增强。
- 测试优先使用 github.com/stretchr/testify 。

---

<a id="design-cautions"></a>

## 10. 设计模式与注意事项

- Interface Wrapper：若下游会对原始对象做额外的接口断言，wrapper 可能改变该行为。除非确认无此需求，否则考虑在 wrapper 中嵌入原始 interface，以保留方法与断言行为。

---
