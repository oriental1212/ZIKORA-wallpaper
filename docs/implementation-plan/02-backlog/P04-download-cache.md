# P04 — 安全下载、图片校验与缓存

## P04-01 受限 HTTP 下载器

> 状态：完成（2026-08-19）。已实现 `URLSessionImageDownloader`：ephemeral URLSession、请求/资源15秒超时、成功 HTTP 门禁、最多5次重定向、Content-Length 与流式累计50MB限制、临时文件流式写入、取消和失败清理，以及脱敏网络日志。

- 需求：12.4、NFR-NET-003、NFR-SEC-003/004。
- 步骤：URLSession 配置 15s 超时；只接受成功 HTTP；最多 5 次重定向；流式计数 50MB 并立即取消；写入应用临时目录；支持取消；URL 日志脱敏。
- 测试：重定向环、无长度、大/小 Content-Length、流式超限、超时、取消、非 2xx。
- 验收：不把完整响应先读进内存；失败清理临时文件。

- 验收证据：`URLSessionImageDownloaderTests` 5 项通过，覆盖分块写入、无 Content-Length、响应头/流式超限、非2xx、重定向环、取消、超时和临时文件失败清理；全量测试 91 项/21 套件通过，Release 构建通过。

## P04-02 图片真实性与解码校验

> 状态：完成（2026-08-19）。已实现 `ImageIOImageValidator`：要求声明 MIME 属于支持集合，校验 UTI 与 magic bytes 一致，使用 ImageIO 解码并检查非零像素尺寸，输出 `ValidatedImage` 的尺寸与格式元数据。

- 需求：10.2.4、12.4。
- 步骤：校验声明 MIME、magic bytes/UTType、ImageIO 可解码、width/height/format；拒绝 HTML/JSON/损坏文件；产出 preview metadata。
- 测试：JPG/PNG/HEIC/WebP、扩展名欺骗、MIME 欺骗、零尺寸、损坏尾部。
- 辅佐：[test-matrix.md](../03-support/test-matrix.md)。

- 验收证据：`ImageIOImageValidatorTests` 5 项通过，覆盖 PNG、JPEG、HEIC、WebP、扩展名/MIME 欺骗、HTML/损坏 payload、非支持格式和非文件 URL；全量测试 96 项/22 套件通过，Release 构建通过。

## P04-03 内容 Hash 与去重

> 状态：完成（2026-08-19）。已增加流式 `SHA256ImageHasher` 与 `DeduplicateWallpaperUseCase`：对已验证临时文件计算稳定 SHA-256，按内容 Hash 查询既有 Wallpaper，返回可复用的既有物理路径，并通过 `AssociateWallpaperWithFetchUseCase` 关联每日记录；决策不读取或依赖来源 URL。

- 需求：12.5。
- 步骤：对验证后完整内容计算 SHA-256；查询已有 Wallpaper；重复则复用物理文件并关联每日记录；相同 URL 不作为去重依据。
- 测试：不同 URL 同内容、同 URL 不同内容、重复手动更新、当前同图提示。

- 验收证据：`DeduplicateWallpaperUseCaseTests` 4 项通过，覆盖不同 URL 同内容复用、同 URL 内容变化生成新 Hash、重复手动更新复用当前 Wallpaper，以及每日记录关联；全量测试 100 项/23 套件通过，Release 构建通过。

## P04-04 原子文件仓库

> 状态：完成（2026-08-19）。已实现 `AtomicWallpaperFileStore`：按逻辑日期创建目录，在管理根目录内生成 UUID 文件名，先流式复制到同目录 partial 文件再原子 rename；异常、取消、扩展名非法和冲突均清理临时源/partial 文件，删除与统计均执行根目录边界校验。

- 需求：12.4、15.1、NFR-STAB-003。
- 步骤：创建逻辑日期目录；生成不含敏感 URL 的文件名；验证临时文件后原子移动；保存相对路径；处理同名/磁盘不足/权限失败；`defer` 清临时文件。
- 验收：不存在半文件；失败不写成功记录；所有路径在管理根目录。

- 验收证据：`AtomicWallpaperFileStoreTests` 5 项通过，覆盖逻辑日期目录、partial→原子提交、失败清理、同名保护、统计、路径逃逸和非法根目录；全量测试 105 项/24 套件通过，Release 构建通过。

## P04-05 缩略图管线

> 状态：完成（2026-08-19）。已实现 `ThumbnailPipeline` 与 `ImageIOThumbnailRenderer`：按内容 Hash/目标尺寸缓存 PNG，ImageIO 异步缩放解码；actor 合并相同 in-flight 请求，支持取消、损坏/缺失原图占位失败和按内容 Hash 缓存失效，不长期保留 `CGImage`。

- 需求：REQ-LIB-002、NFR-PERF-003/005。
- 步骤：按目标像素尺寸生成/缓存缩略图；异步解码；取消离屏任务；损坏显示占位；定义缓存失效。
- 测试：并发请求合并、取消、原图缺失、1,000 条模拟记录内存行为。

- 验收证据：`ThumbnailPipelineTests` 6 项通过，覆盖缓存命中、20 路并发合并、取消无残留、缺失/损坏原图、Hash 失效和 1,000 条记录无 in-flight 任务；全量测试 111 项/25 套件通过，Release 构建通过。

## P04-06 清理估算与执行

> 状态：完成（2026-08-19）。已实现 `WallpaperCleanupPlanner` 与 `CleanupWallpapersUseCase`：纯函数计算保留边界/损坏记录/孤儿文件，current 永不列入候选；执行有确认门禁，按安全文件删除→Repository 删除顺序处理，支持部分失败报告并刷新剩余统计。

- 需求：15、REQ-STORE-001～006。
- 步骤：纯函数计算过期；生成预计数量/空间；确认后安全路径校验→删文件→删记录；current 保护；永久策略只维护损坏记录；刷新统计。
- 测试：边界日、current 过期、部分删除失败、路径逃逸、孤儿文件/记录。
- 辅佐：[data-and-state-machines.md](../01-architecture/data-and-state-machines.md)。

- 验收证据：`CleanupWallpapersUseCaseTests` 5 项通过，覆盖边界日、current 保护、永久策略、确认门禁、部分删除失败、孤儿文件和执行后统计；全量测试 116 项/26 套件通过，Release 构建通过。

## P04-07 缓存统计与 Finder URL

> 状态：完成（2026-08-19）。已实现 `ManagedCacheService`：异步委托 FileStore 汇总有效文件大小，提供短时统计缓存与主动失效；统计失败不会污染缓存，后续刷新可恢复；同时返回合法容器目录 URL 与 Home-relative 用户友好路径。

- 步骤：异步汇总有效文件大小；用户友好显示容器路径；为 P06 Finder 打开提供合法目录 URL；避免每次刷新全量高频扫描。
- 验收：统计失败可恢复；不硬编码 `~/.zikora/cache`。

- 验收证据：`ManagedCacheServiceTests` 4 项通过，覆盖缓存命中与失效、失败后恢复、合法目录 URL、用户目录显示路径和非法根目录拒绝；全量测试 120 项/27 套件通过，Release 构建通过。

## 阶段退出条件

恶意/异常响应不能越过限制；原子保存、Hash 去重、缩略图和清理均在临时目录完成自动测试；未增加不必要权限。
