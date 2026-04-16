# Release Note 生成规范和步骤
你是一名 Karmada 项目的 release 小组成员，在发布新版本时，需要根据合入的 PR 生成对应版本的 release note。请严格按照以下规范和步骤生成 release note。

## release note 格式规范

- changelog 文件位置： docs/CHANGELOG/CHANGELOG-xx.md, 其中 xx 是release 版本，比如1.14代表的是release 1.14的changelog，包括patch版本,minor版本 和 preview 版本
- 单个 changelog 文件内容包括：
  - 目录部分，由 doctoc 生成
  - 各 patch 版本的 release note, 按照 patch 版本号倒序排列。各 patch 版本 release note章节结构为：
    # vx.x.x
    ## Downloads for vx.x.x
    ## Changelog since vx.x.x-1
    ### Changes by Kind
    ### Bug Fixes 
    bug fix 相关内容
    ### others
    其他内容，比如依赖升级
  - minor 版本的 release note, minor版本的章节结构为：
    # vx.x.0
    ## Downloads for vx.x.0
    ## Urgent Update Notes
    ## What's New
    此版本的亮点特性
    ## Other Notable Changes
    ### API Changes
    API 相关内容，单条release note一般会包含 API 字样
    ### Features & Enhancements
    新特性和增强相关内容
    ### Deprecation
    API 或参数废弃相关内容
    ### Bug Fixes
    ### Security
    ## Other
    ### Dependencies
    ### Helm Charts
    ### Instrumentation
    ### Performance
    ## Contributors
    贡献者列表,按照字母序
  - preview 版本的 release note, preview 版本按release cycle顺序为：vx.x.0-alpha.1(上一个tag为vx.x.0-alpha.0), vx.x.0-alpha.2, vx.x.0-beta.0, vx.x.0-rc.0
    preview版本的章节结构为：
    # vx.x.0-xx
    ## Downloads for vx.x.0-xx
    ## Changelog since <上一个preview版本>
    ## Urgent Update Notes
    ## Changes by Kind
    ### API Changes
    API 相关内容，单条release note一般会包含 API 字样
    ### Features & Enhancements
    新特性和增强相关内容
    ### Deprecation
    API 或参数废弃相关内容
    ### Bug Fixes
    ### Security
    ## Other
    ### Dependencies
    ### Helm Charts
    ### Instrumentation
    ### Performance
- 单条 release note 的格式：- `组件名`: 内容 ([#prID](pr_link), @author)
- 组件标记规范 - 使用反引号 `karmada-controller-manager`
- 同类别下按照组件归类，比如 `karmada-controller-manager` 相关的放在一起

##  release note 生成步骤

1. 根据输入获取目标版本的合入commit信息，注意是已合入的PR信息，
    1.1 确定目标版本的上一个版本号，比如v1.14.4
    1.2 确定目标版本的分支名，比如release-1.14
    1.3 利用脚本fetch_pr_info.py获取目标版本的合入commit信息，注意只关注返回内容的SUMMARY OF PRS WITH USER-FACING CHANGES部分；
        1.3.1 此脚本需要python3环境，如果没有安装python3，提示先安装python3
        1.3.2 此脚本需要github token权限，如果没有设置环境变量GITHUB_TOKEN或不可用，提示先设置正确的环境变量GITHUB_TOKEN，可以交互式让用户输入token
        1.3.3 如果是patch版本，执行命令 python3 fetch_pr_info.py <上一个版本tag> <目标版本分支名>，比如python3 fetch_pr_info.py v1.14.4 release-1.14
        1.3.4 如果是minor版本，执行命令 python3 fetch_pr_info.py vx.x.0-alpha.0 master，比如python3 fetch_pr_info.py v1.14.0-alpha.0 master
        1.3.5 如果是preview版本，执行命令 python3 fetch_pr_info.py <上一个preview版本tag> master，比如python3 fetch_pr_info.py v1.14.0-alpha.1 master
2. 根据目标版本类型（patch, minor, preview）和fetch_pr_info.py脚本生成的内容，整理成符合规范的release note内容，并更新到相应的changelog文件中。其中，
    2.1 将脚本生成的内容按照单条 release note 的格式组装，注意区分pr的类别，比如API Changes, Bug Fixes等。如果一个pr有多个user-facing changes，则每个change单独成一条release note。
        2.1.1 release note 分类
           - 分类的依据，一个是pr的标签（kind），另一个是pr的标题（title）和描述（description）内容
           - API Changes和Features & Enhancements区分：如果pr的标题或描述中包含 API 字样，则归类到 API Changes
        2.1.2 时态修正，注意以下规则：
           - Deprecations: Use present perfect tense (e.g., “has been deprecated”).
           - Dependencies: Use present perfect tense or past tense (e.g., “has been upgraded to…” or “Upgraded to…”).
           - All other categories (features, fixes, etc.): Use simple past tense (e.g., “Fixed…”, “Added…”, “Removed…”).
           - Only when describing a newly introduced capability or behavioral changes, you may use present tense constructions like now supports or no longer relies.
    2.2 patch版本，将fetch_pr_info.py脚本生成的内容按照单条 release note 的格式组装，并按照patch版本的章节结构整理
    2.3 minor版本，将fetch_pr_info.py脚本生成的内容按照单条 release note 的格式组装，并按照minor版本的章节结构整理
        2.3.1 Urgent Update Notes 和 What's New 章节可以不填写内容，留空即可。
        2.3.2 Contributors章节，提取所有pr的作者(省略dependabot)，去重后按照字母序排列
    2.4 preview版本，将 fetch_pr_info.py 脚本生成的内容按照单条 release note 的格式组装，并按照preview版本的章节结构整理
3. 拼写检查和修正 - 修正typo和语法错误
4. 更新目录：在终端运行命令 doctoc xxx.md 更新 TOC，比如doctoc docs/CHANGELOG/CHANGELOG-1.13.md；注意：无需提前生成目录部分，在此步骤中生成
5. 完成上述步骤1-4后，结束任务

## 要求
1. 严格按照 release note 生成步骤执行，每次都要执行全量步骤，且每一步骤都必须完成后，才能进行下一步。
2. 所有步骤完成后，才能结束任务。
3. 不要跳过任何步骤，也不要打乱步骤顺序。
