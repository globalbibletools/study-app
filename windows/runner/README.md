# runner

## Overview
Windows application runner component implementing Win32 window hosting, DPI scaling, and Flutter view controller management.

## Interface
- [main.cpp:wWinMain(HINSTANCE, HINSTANCE, wchar_t*, int)] - Win32 application entry point initializing COM and running the window message loop.
- [flutter_window.h:FlutterWindow] - Specialization of `Win32Window` hosting a `flutter::FlutterViewController`.
- [flutter_window.h:FlutterWindow::FlutterWindow(const flutter::DartProject&)] - Constructs FlutterWindow for a given Dart project.
- [win32_window.h:Win32Window] - High-DPI-aware Win32 abstraction window class.
- [win32_window.h:Win32Window::Create(const std::wstring&, const Point&, const Size&)] - Creates Win32 window on the default monitor.
- [win32_window.h:Win32Window::Show()] - Displays the window.
- [win32_window.h:Win32Window::Destroy()] - Destroys window resources.
- [utils.h:CreateAndAttachConsole()] - Attaches console and redirects stdout/stderr when debugging.
- [utils.h:Utf8FromUtf16(const wchar_t*)] - Converts UTF-16 wide string to UTF-8 std::string.
- [utils.h:GetCommandLineArguments()] - Parses Win32 command line arguments as a UTF-8 string vector.

## Invariants
- COM is initialized as apartment threaded (`COINIT_APARTMENTTHREADED`) before window creation.
- Window handles DPI changes through Win32 message pump delegation.

## Side Effects
- Allocates Win32 desktop window (`HWND`) and runs the Win32 message loop until exit.

## Verification
- Run: `flutter test`
