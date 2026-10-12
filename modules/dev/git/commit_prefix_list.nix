[
  {
    prefix = "feat";
    description = "新功能，包含实质性逻辑的新文件";
    example = "add support for CSV import";
  }
  {
    prefix = "fix";
    description = "修复 bug";
    example = "handle token refresh race condition";
  }
  {
    prefix = "docs";
    description = "仅文档变更（README、注释、文档字符串）";
    example = "update installation instructions";
  }
  {
    prefix = "style";
    description = "格式调整、空白、缺少分号（无代码逻辑变化）";
    example = "format with prettier";
  }
  {
    prefix = "refactor";
    description = "代码重构，非新增功能或修复 bug";
    example = "extract connection pool into separate module";
  }
  {
    prefix = "perf";
    description = "性能改进";
    example = "reduce TTL to improve memory usage";
  }
  {
    prefix = "test";
    description = "添加或修改测试";
    example = "add integration tests for /users endpoint";
  }
  {
    prefix = "build";
    description = "构建系统、依赖";
    example = "pin Node version in GitHub Actions";
  }
  {
    prefix = "ci";
    description = "CI/CD 配置变更（GitHub Actions、CI 脚本、自动化流程）";
    example = "add release workflow to GitHub Actions";
  }
  {
    prefix = "chore";
    description = "维护、工具、配置文件、gitignore";
    example = "bump lodash to 4.17.21";
  }
  {
    prefix = "config";
    description = "配置文件变更（分离于 chore，专指配置文件修改）";
    example = "update ESLint rule for import ordering";
  }
  {
    prefix = "types";
    description = "类型定义变更（TypeScript/Flow 类型标注、接口定义）";
    example = "add strict types for API response";
  }
  {
    prefix = "security";
    description = "安全修复或改进，与普通 fix 区分";
    example = "sanitize user input in search query";
  }
  {
    prefix = "i18n";
    description = "国际化/本地化（翻译、语言包、区域设置）";
    example = "add zh-CN translation for settings page";
  }
  {
    prefix = "release";
    description = "版本发布、版本号更新";
    example = "bump version to 2.1.0";
  }
  {
    prefix = "remove";
    description = "删除功能、文件或代码";
    example = "drop deprecated v1 API endpoints";
  }
  {
    prefix = "revert";
    description = "回退之前的提交";
    example = "feat(parser): add support for CSV import";
  }
  {
    prefix = "update";
    description = "依赖更新、工具链版本更新、库更新等";
    example = "upgrade axios to 1.7.0";
  }
]
