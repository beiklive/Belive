// Belive 主程序：bklv（BekUI 三方库）的最小宿主。
//
// 跟 BekUI 的 demo 不同，这里不含任何"演示"代码 —— 只验证一件事：
//   三方库能链进来、能起窗口、能按 exe 旁边的 resources/ 找到字体与主题。
//
// 自动化：--screenshot <png> --frames N 截一帧就退出（CI / 无人值守验证用）。

#include <cstdlib>
#include <cstring>
#include <string>

#include "bklv/bklv.hpp"

int main(int argc, char** argv)
{
    std::string screenshot;
    int         frames = 0;

    for (int i = 1; i < argc; i++)
    {
        if (std::strcmp(argv[i], "--screenshot") == 0 && i + 1 < argc)
            screenshot = argv[++i];
        else if (std::strcmp(argv[i], "--frames") == 0 && i + 1 < argc)
            frames = std::atoi(argv[++i]);
    }

    bklv::App app;

    // 初始界面。真正的 Belive 界面以后都挂在这棵树上。
    bklv::Box root(bklv::Axis::COLUMN);
    root.setJustifyContent(bklv::JustifyContent::CENTER);
    root.setAlignItems(bklv::AlignItems::CENTER);
    root.setGap(16.0f);
    root.setPadding(32.0f);

    // 按钮：点了弹一条通知，用来确认事件链路（也顺便验证通知层能用）
    bklv::Button button("Belive");
    button.setOnClick([&app]() { app.notify("Hello, Belive"); });

    // 普通文本：确认默认字体与 i18n 之外的绘制路径
    // 主题里的 `color.text.primary` 是给浅色底的深色字，放在这块深色玻璃底上几乎看不见，
    // --screenshot 自检会拍出一片灰，所以这里显式给一个浅灰（只为自检可读，不代表设计要求）。
    bklv::Label hint;
    hint.setText("BekUI 已作为三方库链接进来（3rd/BekUI）");
    hint.setTextColor(IM_COL32(210, 210, 214, 255));

    root.addView(&button);
    root.addView(&hint);

    app.setRootView(&root);

    if (!screenshot.empty())
        app.requestScreenshot(screenshot, frames > 0 ? frames : 10);

    return app.run("Belive", 1280, 720);
}
