# Team Development Standards

> ℹ️ Note: Chinese document `TEAM_DEVELOPMENT_STANDARDS_ZH.md` is the authoritative source. This English document is a synchronized reference.

## Table of Contents

1. [Governance & Codebase Hygiene](#governance)
2. [Error Handling & Interfaces](#errors-interfaces)
3. [Go Naming & Serialization](#naming-serialization)
4. [Configuration files (confx)](#configuration)
5. [GORM Usage Standards](#gorm-usage)
6. [Database & Migration Practices](#db-migrations)
7. [Proto & API Guidelines](#proto-api)
8. [Runtime & Deployment](#runtime-deployment)
9. [Library Usage Preferences](#library-preferences)
10. [Design Patterns & Cautions](#design-cautions)

---

<a id="governance"></a>

## 1. Governance & Codebase Hygiene

- **Strict review for AI-authored code**: All code authored via Cursor must be carefully reviewed before acceptance.
- **Remove unused code**: Do not keep code that is not used anywhere.
- **English-only code and docs**: Source code and comments must be in English. Documentation must have an English version.
- **Package naming**: Package names and import aliases must be lowercase. Prefer snake_case for multi-word names (e.g., `user_service`) unless the combination is already clear (e.g., `ledgerv1`). Avoid any uppercase letters in package names.
- **Avoid over-commenting**: Favor readable code over excessive comments; add concise comments only when necessary.

> 💡 **Tip:** When in doubt, refactor names and structure to improve readability instead of adding comments.

---

<a id="errors-interfaces"></a>

## 2. Error Handling & Interfaces

- **Error wrapping policy**:
  - Wrap errors from external functions with `github.com/pkg/errors` (e.g., `errors.Wrap`, `errors.WithStack`).
  - For newly created errors, use `errors.New`/`errors.Errorf` to capture origin.
  - Internal errors from within the same layer can be passed through as-is when stack trace is preserved.
- **Error comparison**: Always use `errors.Is` (e.g., `errors.Is(err, gorm.ErrRecordNotFound)`). Never compare with `==`.
- **Status errors in gRPC boundaries**: In gRPC method implementations or middleware, use `statusx` for errors. `statusx.Wrap` will preserve an existing status error to avoid multi-layer wrapping duplicates.
- **Avoid panic/fatal**: Prefer returning errors. Do not use `panic` or `log.Fatal` unless absolutely necessary.
- **Goroutine panic safety**: Ensure every goroutine has a `recover` mechanism to prevent process-wide crashes.
- **IO method signatures**: Long-running IO methods must accept `ctx context.Context` as the first parameter and return `error`.
- **Interface implementation validation**: When implementing an interface, include a compile-time assertion to ensure conformance.
- **Return interface when nil is possible**: If the expected return type is an interface (e.g., `error`) and `nil` is a valid result, return the interface type directly rather than a concrete implementation to avoid non-nil interface values with nil underlying pointers.

```go
// Compile-time interface assertion example
var _ MyInterface = (*MyImpl)(nil)
```

```go
// Example: avoid returning a concrete typed nil into an interface variable
var e error = func() *errFoo { return nil }()
// e != nil is true because e has a concrete type
```

---

<a id="naming-serialization"></a>

## 3. Go Naming & Serialization

- **Acronyms casing**: Use all-caps for acronyms in Go identifiers (e.g., `userID`, `HTTPServer`), except when they start an identifier (e.g., `idGenerator`). Third-party generated code (e.g., proto) is exempt.
- **Constants**:
  - String constant values should use SCREAMING_SNAKE_CASE (e.g., `const StatusActive = "STATUS_ACTIVE"`).
  - When constant values are used as configuration options, use kebab-case (e.g., `const ModeReadOnly = "read-only"`).
- **Serialization and config naming**:

  - `json` struct tags and `confx` YAML config fields must use `camelCase`.
  - Preserve acronym capitalization (e.g., `json:"userID"`, `json:"readTimeoutMS"`). Avoid mixed forms like `userId`.
  - Third-party generated code or external system requirements are exempt.
  - Avoid `omitempty` unless strictly necessary.

- **Types**: Prefer `any` over `interface{}` (Go 1.18+) for readability.

<a id="configuration"></a>

## 4. Configuration files (confx)

- The embedded default YAML must list all configurable items for each cmd, even when values are zero.
- Prioritize readability: declare fields explicitly for easy review, diff, and documentation.
- Non-default YAML configs may be trimmed as needed (not enforced).
- Example (camelCase with acronym casing alignment):

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

## 5. GORM Usage Standards

- **Disable association writes**: Do not use `db.Association(...)` or related methods (`Replace`, `Append`, ...). Use `gormx.OmitAssociationsPlugin` to prevent black-box writes.
- **Always pass context**: All `gorm.DB` calls must use `.WithContext(ctx)`.
- **Do not pass instances to `Model()`**: Pass a type, not an instance, to avoid hidden query conditions (e.g., `db.Model(&User{})`, not `db.Model(&existingUser)`).
- **String primary key queries**: For string PKs (e.g., UUID), do not pass the ID directly to `First()`; use explicit `WHERE` clauses.

```go
// Good
db.Where("id = ?", uuid).First(&model)

// Bad
// db.First(&model, uuid) // may generate invalid SQL
```

- **Avoid `UpdateColumn` unless necessary**: It does not trigger hooks. Use other update methods when hooks are required.

---

<a id="db-migrations"></a>

## 6. Database & Migration Practices

- **Pre-validate destructive operations**: Before `DELETE`/`TRUNCATE`, prepare and run the matching `SELECT` to confirm target rows.
- **Batch large DML**: For large `INSERT`/`UPDATE`/`DELETE` operations, run with filters and in batches.
- **Schema change governance (post-MVP)**:
  - After MVP, any schema change other than adding new columns requires approval by at least two reviewers.
  - In production, deleting or renaming columns is prohibited by default; only proceed after multi-party review with a clear migration plan.
- **Primary key strategy**:
  - Enforce globally unique identifiers (e.g., UUID, XID, Snowflake); auto-increment IDs are prohibited.
  - Ban composite primary keys. Use a single-field primary key plus business-level unique constraints instead.
  - A single primary key avoids including all fields of composite unique constraints in `WHERE` clauses, reducing error-proneness, omissions, and maintenance overhead.
  - Better supports sharding, cross-system data merges, and future distributed architectures.
- **PostgreSQL driver**: Do not use `lib/pq`.

> 💡 **See also:** Database design conventions are covered in the dedicated rule `1050-database-design` (audit columns first, snake_case, soft delete semantics, filtered unique constraints and indexes, no physical FKs, etc.).

---

<a id="proto-api"></a>

## 7. Proto & API Guidelines

- **Import aliasing**: Do not create unnecessary aliases for proto imports. Prefer versioned, descriptive aliases.

```go
// Good
import authv1 "github.com/theplant/ciam-next/gen/ciam/auth/v1"

// Avoid
// import authpb "github.com/theplant/ciam-next/gen/ciam/auth/v1"
```

- **Model fields**: Proto model definitions should not include `deleted_at`. Soft delete is a database concern and should not be exposed in API models.

---

<a id="runtime-deployment"></a>

## 8. Runtime & Deployment

- **gRPC load balancing**: In deployment, use headless Service + round-robin to ensure per-request load balancing. Verify client-side configuration.

---

<a id="library-preferences"></a>

## 9. Library Usage Preferences

- **Prefer extension packages when available**: If an extension package provides an equivalent function, use it (e.g., `lox.Must`, `filepathx.Join`, `clonex.Clone`, `clonex.CloneSlowy`, `jsonx.Marshal`) for better error handling, performance, or features.
- **Testing preference**: Prefer `github.com/stretchr/testify` for unit tests.

---

<a id="design-cautions"></a>

## 10. Design Patterns & Cautions

- **Interface wrappers**: Be cautious when wrapping interfaces. If consumers perform additional interface assertions on the original type, a wrapper can change behavior. Consider embedding the original interface to preserve methods and assertion behavior.

---
