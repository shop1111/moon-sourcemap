# MoonSourceMap

[English](#english) · [中文](#中文)

MoonSourceMap 是一个纯 MoonBit 的 [ECMA-426 Source Map][ecma426] 工具链：
解析、生成、校验、双向查询、Index Map 展平、两级映射组合和栈帧符号化，
并提供适合 CI 使用的命令行程序。

它不依赖 JavaScript Source Map 运行库，核心库可在 wasm、wasm-gc、
JavaScript 和 native 四个稳定后端构建。

## 中文

### 五分钟上手

安装依赖并验证：

```bash
moon update
moon test --target all --deny-warn
moon run --target native cmd/main -- validate examples/demo.min.js.map
```

查询生成位置（行列均为零基）：

```bash
moon run --target native cmd/main -- \
  lookup examples/demo.min.js.map --line 0 --column 4 --format json
```

输出会恢复到 `../src/demo.ts:0:0 greet`。再用同一张 map 符号化栈帧：

```bash
moon run --target native cmd/main -- \
  symbolize examples/demo.min.js.map examples/frames.txt
```

### 库 API

下面的片段由 `moon test` 检查：

```mbt check
///|
test "parse, validate and query" {
  let json =
    #|{"version":3,"sources":["src/main.ts"],"names":["main"],"mappings":"AAAAA"}
  let document = @moon_sourcemap.parse_document(json)
  assert_false(
    @moon_sourcemap.diagnostics_have_errors(@moon_sourcemap.validate(document)),
  )
  let decoded = @moon_sourcemap.decode_document(document)
  let mapping = @moon_sourcemap.original_position_for(
    decoded,
    generated=@moon_sourcemap.Position::new(line=0, column=0),
  )
  assert_true(mapping is Some(_))
}
```

Builder 会在生产映射时检查生成位置顺序，并自动维护 sources 与 names 表：

```mbt check
///|
test "build a map" {
  let builder = @moon_sourcemap.SourceMapBuilder::new(file="bundle.js")
  let source = builder.add_source(
    url="src/main.ts",
    content="export const answer = 42",
  )
  builder.add_mapping(
    generated=@moon_sourcemap.Position::new(line=0, column=0),
    source_index=source,
    original_line=0,
    original_column=0,
    name="answer",
  )
  let document = builder.build()
  assert_eq(document.version, 3)
}
```

主要公开接口：

| 能力 | API |
|---|---|
| JSON 双向转换 | `parse_document`, `encode_document` |
| mappings 编解码 | `decode_mappings`, `encode_mappings` |
| 严格校验 | `validate`, `validate_json`, `Diagnostic` |
| 位置查询 | `original_position_for`, `generated_positions_for` |
| 批量索引 | `SourceMapConsumer` |
| Index Map | `decode_document`, `flatten` |
| 生成 | `SourceMapBuilder`, `encode_decoded` |
| 两级构建 | `compose`, `compose_with_options` |
| 栈帧恢复 | `parse_stack_frame`, `symbolize`, `symbolize_frame` |
| 规范化变换 | `canonicalize`, `slice_generated`, `concatenate` |

### CLI

```text
moon-sourcemap validate <map> [--format text|json]
moon-sourcemap inspect <map> [--format text|json]
moon-sourcemap lookup <map> --line N --column N [--bias glb|lub] [--strict]
moon-sourcemap flatten <map> -o <output>
moon-sourcemap compose <outer> <inner> -o <output>
moon-sourcemap symbolize <map> <frames> [--context N] [--strict] [--format text|json]
```

退出码固定为：

- `0`：成功；
- `1`：用法或 I/O 错误；
- `2`：Source Map JSON、结构或 mappings 非法；
- `3`：`--strict` 模式下没有找到映射。

### 与通用 VLQ 包的区别

VLQ 只是 Source Map `mappings` 字段的整数编码。MoonSourceMap 在此之上提供：

- ECMA-426 文档与 Index Map 数据模型；
- source/name 增量状态、索引边界和映射顺序校验；
- GLB/LUB 与反向查询；
- section 偏移、展平和多级构建组合；
- `sourcesContent`、ignore list、符号名和栈帧恢复；
- 结构化诊断、确定性序列化及 CI 退出码。

因此相邻的通用 VLQ 包可以作为底层编码器，但不能替代本项目。

### 合规与范围

本项目依据公开 ECMA-426 标准原创实现，没有移植其他 Source Map
运行库。`third_party/tc39-source-map-tests` 记录了所选官方数据用例的
来源、固定 revision 和 BSD 许可；产品代码使用 Apache-2.0。

v0.1 不实现仍在演进的 Scopes、Range Mappings、Debug ID 与 Env
提案。坐标在库和 CLI 中统一为零基，避免隐式换算。

### 当前里程碑

当前 0.1.0 已完成核心库、六命令 CLI、源码上下文、多文件 map registry、
结构质量报告、TC39 选例、四后端 CI、示例和发布元数据。生产 MoonBit
有效代码由 CI 强制保持在 4000–4499 行，不把测试、空行、纯注释、示例
或第三方数据计入。

## English

MoonSourceMap is an original, pure-MoonBit implementation of ECMA-426. It
parses and emits regular and index source maps, validates mapping state,
supports GLB/LUB and reverse queries, composes build stages, and symbolizes
generated stack frames.

Run the complete verification matrix:

```bash
moon fmt --check
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon info
git diff --exit-code
moon package
```

The CLI uses stable JSON output and deterministic exit codes, so `validate`,
`lookup`, `flatten`, `compose`, and `symbolize` can be used directly in CI.

## License

MoonSourceMap is licensed under Apache-2.0. Selected test data attribution is
documented separately under `third_party/tc39-source-map-tests`.

[ecma426]: https://tc39.es/ecma426/
