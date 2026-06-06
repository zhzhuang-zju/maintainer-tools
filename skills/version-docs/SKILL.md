---
name: version-docs
description: Guide to Writing Karmada Version Documents. Use this when asked to write Karmada Version document.
---

在编写Karmada 版本文档（version-docs）时，您必须严格遵循以下指南，以确保文档的清晰、准确和易于理解：

1. 你首先需要知道是哪个版本，比如v1.16,v1.17，必须有此信息才能继续后续步骤。如果上下文没有提供相应信息，你必须主动问询，不可猜测。
2. 最终输出结果：单独在outputs目录下创建一个文件夹，目录名 `{年}-{月}-{日}-karmada-{版本号}`，比如 `2026-06-06-karmada-v1.18`，里面包含版本文档，以及一个名为`resources`的文件夹，里面存放版本文档中使用的图片资源（比如贡献者头像）。版本文档的命名格式为 `karmada-{版本号}.md`，比如 `karmada-v1.18.md`。目录结构如下：
    ```md
    outputs/
    ├── 2026-06-06-karmada-v1.18/
    │   ├── karmada-v1.18.md
    │   └── resources/
    │       ├── image1  
    │       ├── image2
    ```
3. 你需要了解这个版本的主要特性和改进点。
   - 查找release note： 此版本的 release note 文件位置是 `docs/CHANGELOG/CHANGELOG-{版本号}.md`，比如 `docs/CHANGELOG/CHANGELOG-1.17.md`。 
   - 如果本地文件没有，你可以从链接 `https://github.com/karmada-io/karmada/blob/master/docs/CHANGELOG/CHANGELOG-{版本号}.md` 来获取。
   - 从release note中的 minor 版本的 `What's New` 章节获取主要特性和改进点信息。版本文档的新增特性部分和其保持一致。
   - 如果`What's New`章节提供了特性文档或proposal链接，你可以从这些链接中获取更多细节信息，以便你更好地理解和描述这些特性。
4. 在完成第2步后，增加一个问询点： 你需要简单列出这个版本的主要特性和改进点，并询问是否正确，以及是否有其它补充特性。只有在问题得到确认后，你才能继续后续步骤。
5. 你需要从template.md中了解版本文档的格式，新文档也需要遵守此格式
6. 你需要从demo.md中了解一个完整的版本文档示例，以便你更好地理解如何撰写版本文档。
7. 当撰写“致谢贡献者”部分，需要获取以下信息：
    - 贡献者用户名名单： 从 release note 的 Contributors 部分直接获取，最终格式是表格，一列有三个。
    - 贡献者的GitHub头像总图：使用脚本 `hack/make-contributors-collage.sh` 生成，输出文件名固定为 `contributors.png`，放置在版本文档的 `resources/` 目录下。脚本会自动从 `https://github.com/{用户名}.png` 下载头像，按一排 6 个、每个 2.5cm × 2.5cm 的规格拼接成总图。贡献者名单作为输入传给脚本，可通过 `-m` 直接解析版本文档中的贡献者表格（保持表格顺序），也支持 `-f`、stdin、位置参数等方式。示例：
      ```bash
      .github/skills/hack/make-contributors-collage.sh \
        -m outputs/{年}-{月}-{日}-karmada-{版本号}/karmada-{版本号}.md \
        -o outputs/{年}-{月}-{日}-karmada-{版本号}/resources/contributors.png
      ```
    - 代码提交次数，通过构造https://github.com/karmada-io/karmada/compare/{版本号}-alpha.0...{版本号}，比如https://github.com/karmada-io/karmada/compare/v1.18.0-alpha.0...v1.18.0来获取总的提交数，减去其中是merge commit的提交数
   