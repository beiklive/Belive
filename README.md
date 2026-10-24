# Belive

UI 宿主程序。界面库用 [BekUI](https://github.com/beiklive/BekUI)（`bklv`），以 git submodule
的形式放在 `3rd/BekUI`。

## 目录

```
3rd/BekUI/        三方库：BekUI（含它自己的子模块：SDL3 / imgui / yoga / tweeny / stb / json / webp / lunasvg / plutovg）
src/main.cpp      主程序入口（当前是最小宿主：链进 bklv、起窗口、读 exe 旁边的 resources/）
resources/        资源树（**自有**，构建只拷这一份：字体 / 文案 / 主题 / 音效；含自有主题 theme/belive/）
scripts/          sync-resources.ps1（从 3rd/BekUI/resources 增量拉新素材）
CMakeLists.txt    构建入口
CMakePresets.json 两套 Windows 工具链的 preset（windows-msvc / windows-mingw）
.vscode/          共享的编辑器配置（CMake Tools 走 preset、C++ 标准、推荐扩展）
```

## 拿代码

```bash
git clone --recursive git@github.com:beiklive/Belive.git
# 已经克隆过、但 3rd/BekUI 是空目录：
git submodule update --init --recursive
```

`--recursive` 不能省：BekUI 自己还带着 9 个子模块，少一层都会在 CMake 配置阶段报
`bklv/3rd/imgui/imgui.h 不存在，子模块不完整`。

## 构建

要求 CMake ≥ 3.24（BekUI 的 SDL3 子模块用了 3.24 才有的链接特性）。

```bash
# GL（产物 dist/belive.exe，资源在 dist/resources）
cmake -S . -B build/gl -DBKLV_GRAPHICS=gl
cmake --build build/gl --config Release

# Vulkan（产物 dist/vk/belive.exe）
cmake -S . -B build/vk -DBKLV_GRAPHICS=vk
cmake --build build/vk --config Release
```

Windows 上两种工具链都能用：

```powershell
# MinGW（MSYS2 MINGW64 终端里跑，或让 PATH 里有 mingw64/bin）
cmake -S . -B build/gl -G Ninja -DBKLV_GRAPHICS=gl

# MSVC / Visual Studio 2022
cmake -S . -B build/gl -G "Visual Studio 17 2022" -DBKLV_GRAPHICS=gl
```

生成器是**配置时定死**的：已经配好的构建目录不能换 `-G`，要换先删目录。
`-DBKLV_GRAPHICS` 也是缓存变量，`build/vk` 里必须显式传 `vk`，否则会编出 GL 版。

### 用 preset 构建（推荐）

`CMakePresets.json` 已经把两套 Windows 工具链分开写在各自的构建目录里，命令行和
VS Code 用的是同一份：

```bash
cmake --list-presets                 # windows-msvc / windows-mingw
cmake --preset windows-msvc          # 配置到 build/msvc
cmake --build --preset windows-msvc  # 产物 dist/belive.exe
cmake --preset windows-mingw         # 配置到 build/mingw（需要 MSYS2 mingw64，路径见 preset）
cmake --build --preset windows-mingw
```

两个 preset 的构建目录是分开的，但**产物都落在 `dist/`**（bklv 按这个目录找 exe 和资源）。
所以来回切 preset 时，另一套工具链可能因为"输出比自己的 .obj 新"而跳过链接，看到的是上一次
的 exe —— 这时加 `--clean-first`（或先删 `dist/belive.exe`）：

```bash
cmake --build --preset windows-msvc --clean-first
```

### VS Code

装两个扩展：**CMake Tools**（`ms-vscode.cmake-tools`）与 **C/C++**（`ms-vscode.cpptools`，
仓库的 `.vscode/extensions.json` 会提示）。打开目录后直接按 `F7` 构建即可，配置来自：

- `.vscode/settings.json` 里 `"cmake.useCMakePresets": "always"` —— 让 CMake Tools 用
  `CMakePresets.json`，而不是让它按 "kit" 自己挑生成器
- 左下角状态栏可以切 preset：`windows-msvc`（默认，装了 VS 2022 就能用）或
  `windows-mingw`（MSYS2）

为什么必须走 preset：CMake Tools 默认把工作区根下的 `build/` 当构建目录，并且按 kit 决定
生成器。只要 `build/` 里已经有一份别的生成器的缓存（比如先用 Ninja 配过一次），再选
Visual Studio kit 就会直接失败：

```
CMake Error: Error: generator : Visual Studio 17 2022
Does not match the generator used previously: Ninja
Either remove the CMakeCache.txt file and CMakeFiles directory or choose a different binary directory.
```

preset 把每个工具链的目录分开（`build/msvc`、`build/mingw`），不会再撞；要换工具链就换
preset，不要删缓存硬来。

运行：`dist/belive.exe`（资源按「exe 所在目录 /resources」解析，所以别把 exe 单独拷走）。
截图自检：`dist/belive.exe --screenshot shot.png --frames 10`。

## 资源与样式

资源**只在运行时从 exe 旁边的 `dist/resources` 读**（`bklv/core/resource.cpp` 用
`SDL_GetBasePath()`；Switch 上是 `romfs:/`）。`dist/resources` 是构建产物，由仓库根的
`resources/` 整目录拷过去（先删后拷）：

```
resources/  --(cmake -E copy_directory)-->  dist/resources
```

这是资源的**唯一来源**：Belive 全量接管了资源树，构建不再读 `3rd/BekUI/resources`，
所以字体、文案、主题、音效都在这里改，不用碰子模块。

```
resources/
├─ font/                       字体（switch_icons.ttf、MaterialIcons-Regular.ttf）
├─ i18n/                       文案（en-US / zh-Hans / pinyin.json）
├─ focus_ring_gradient.png     焦点环的渐变色带
├─ audio/                      音效 wav（sound.json 里写 "@res/audio/x.wav"）
└─ theme/
   ├─ themes.json              {"default": ..., "available": [...]}，只列真实存在的主题
   ├─ default/                 默认主题（库的原始素材，可直接改）
   ├─ glass/                   库自带的另一套（样板：只覆盖 7 个文件）
   └─ belive/                  Belive 自己的主题（启动时 app.setTheme("belive")）
```

**不要手改 `dist/resources`**（下次构建会被删掉重建）。

`resources/theme/belive/` 的结构（最小主题，其余全部回退 default）：

```
theme.json                   name / files[] / colorScheme；files[] 是外观文件的**显式清单**
tokens/colors.json           色板：只写要改的 key，写 color.<组>.<键>
tokens/metrics.json          数值：一个都不改也要留这份空文件，缺它装载时会报"打不开"
base/**.json  widget/**.json  （可选）外观覆盖，每个文件都是整份覆盖，所以文件必须在 files[] 里登记
sound.json                   （可选）音效表，缺省继承 default
```

几条硬规则：

- `files[]` **不扫目录**（romfs 上不能列目录），没登记的外观文件不会加载，也不报错
- 外观名 = 相对主题目录的路径去掉扩展名（`base/button/button.json` → `base/button/button`），
  挪文件位置等于改名
- 颜色/数值按 key 回退 default，外观文件按整份文件回退 → 想改一点点就往薄了写
- 新主题要在启动时选中：`app.setTheme("belive")`（`src/main.cpp` 里已经这么做了），
  或临时用环境变量 `BKLV_THEME=belive`；`themes.json` 的 `available` 只影响换肤列表，
  不在里面也能 `setTheme()`

### 从 BekUI 拉新素材

资源树是自有的，所以 BekUI 以后新增的字体/主题文件/音效不会自己过来。用脚本做增量对比：

```powershell
powershell -NoProfile -File scripts/sync-resources.ps1                 # 只看差异，不动文件
powershell -NoProfile -File scripts/sync-resources.ps1 -Apply          # 拉"库里有、我们没有"的文件
powershell -NoProfile -File scripts/sync-resources.ps1 -Apply -Force   # 连内容不同的也覆盖（会盖掉你的改动）
```

脚本**只增不删**：Belive 独有的文件（比如 `theme/belive/`）永远不会被它删掉或覆盖，
除非你显式加 `-Force`。

## 更新三方库

```bash
cd 3rd/BekUI
git fetch && git checkout <tag-or-commit>
cd ../..
git add 3rd/BekUI
git commit -m "chore(3rd): 更新 BekUI 到 <版本>"
```

BekUI 的 MSVC 兼容补丁（它仓库里的 `notes/tweeny-msvc-render.patch`）由它自己的 CMake
在配置阶段按平台打，这里不需要做任何事；因此 `git status` 里看到子模块 dirty 是正常的。
