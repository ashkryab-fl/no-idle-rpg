#include "flutter_window.h"

#include <optional>
#include <algorithm>
#include <cmath>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  HWND hwnd = GetHandle();
  SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, WS_EX_LAYERED | WS_EX_TOOLWINDOW);
  // Flutter paints this exact color only into empty overlay space.
  SetLayeredWindowAttributes(hwnd, RGB(1, 1, 1), 255, LWA_COLORKEY);
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "idle_companion/desktop",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "idleSeconds") {
      LASTINPUTINFO info{};
      info.cbSize = sizeof(info);
      if (!GetLastInputInfo(&info)) {
        result->Error("idle_failed", "GetLastInputInfo failed");
        return;
      }
      // Unsigned 32-bit subtraction handles the GetTickCount wrap boundary.
      const DWORD elapsed = GetTickCount() - info.dwTime;
      result->Success(flutter::EncodableValue(elapsed / 1000.0));
    } else if (call.method_name() == "configure") {
      const auto* map = std::get_if<flutter::EncodableMap>(call.arguments());
      if (map) {
        auto read = [map](const char* key, bool fallback) {
          auto it = map->find(flutter::EncodableValue(key));
          if (it == map->end()) return fallback;
          const bool* value = std::get_if<bool>(&it->second);
          return value ? *value : fallback;
        };
        expanded_ = read("expanded", false);
        topmost_ = read("alwaysOnTop", true);
        const auto it = map->find(flutter::EncodableValue("scale"));
        const double* scale = it == map->end() ? nullptr : std::get_if<double>(&it->second);
        window_scale_ = scale && std::isfinite(*scale)
            ? std::clamp(*scale, 0.5, 3.0) : 1.0;
      }
      ConfigureOverlay();
      UpdateClickThrough();
      result->Success();
    } else if (call.method_name() == "cancelClose") {
      close_pending_ = false;
      result->Success();
    } else if (call.method_name() == "quit") {
      result->Success();
      close_pending_ = true;
      DestroyWindow(GetHandle());
    } else {
      result->NotImplemented();
    }
  });
  ConfigureOverlay();
  SetTimer(hwnd, 1, 33, nullptr);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  KillTimer(GetHandle(), 1);
  channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE && channel_) {
    if (!close_pending_) {
      close_pending_ = true;
      channel_->InvokeMethod("closeRequested", nullptr);
    }
    return 0;
  }
  if (message == WM_TIMER && wparam == 1) {
    UpdateClickThrough();
    return 0;
  }
  if (message == WM_DISPLAYCHANGE || message == WM_SETTINGCHANGE) {
    if (flutter_controller_) ConfigureOverlay();
  }
  if (message == WM_DPICHANGED && flutter_controller_) {
    const auto result = Win32Window::MessageHandler(hwnd, message, wparam, lparam);
    ConfigureOverlay();
    return result;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::ConfigureOverlay() {
  HWND hwnd = GetHandle();
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfo(monitor, &info)) return;
  const double scale = GetDpiForWindow(hwnd) / 96.0;
  const int margin = static_cast<int>(12 * scale);
  const double available_width = (info.rcWork.right - info.rcWork.left - margin * 2) / scale;
  const double available_height = (info.rcWork.bottom - info.rcWork.top - margin * 2) / scale;
  const double fitted_scale = std::min({window_scale_,
      available_width / 400.0, available_height / 190.0});
  // The popup overlays the scene; it never reserves scene space.
  const int width = static_cast<int>((expanded_ ? available_width :
      std::max(400.0, 400 * fitted_scale)) * scale);
  // Keep room for speech at its default text and container size.
  const int height = static_cast<int>((expanded_ ? available_height :
      std::min(available_height, std::max(190.0, 190 * fitted_scale))) * scale);
  SetWindowPos(hwnd, topmost_ ? HWND_TOPMOST : HWND_NOTOPMOST,
      info.rcWork.right - width - margin, info.rcWork.bottom - height - margin,
      width, height, SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

void FlutterWindow::UpdateClickThrough() {
  HWND hwnd = GetHandle();
  POINT cursor{};
  GetCursorPos(&cursor);
  ScreenToClient(hwnd, &cursor);
  RECT client{};
  GetClientRect(hwnd, &client);
  const double scale = GetDpiForWindow(hwnd) / 96.0;
  const double x = cursor.x / scale, y = cursor.y / scale;
  const double width = client.right / scale, height = client.bottom / scale;
  const bool inside = x >= 0 && x < width && y >= 0 && y < height;
  const double scene_scale = std::min({window_scale_, width / 400.0, height / 190.0});
  const double menu_top = height - 190 * scene_scale + 8;
  const bool menu = x >= width - 46 && x < width - 8 && y >= menu_top && y < menu_top + 38;
  const double panel_height = std::min(418.0, height - 16);
  const double panel_bottom = std::min(194.0, std::max(8.0, height - panel_height - 8));
  const double panel_top = height - panel_bottom - panel_height;
  const bool panel = expanded_ && x >= width - 392 && x < width - 8 && y >= panel_top && y < panel_top + panel_height;
  const bool interactive = inside && (panel || menu);
  const LONG_PTR previous = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  const LONG_PTR next = interactive ? previous & ~WS_EX_TRANSPARENT : previous | WS_EX_TRANSPARENT;
  if (previous != next) SetWindowLongPtr(hwnd, GWL_EXSTYLE, next);
}
