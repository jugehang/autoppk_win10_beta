//! AutoPMX Tauri backend.
//!
//! 职责分层（对应原 Swift 工程的迁移映射）：
//! - `apply_glass`            -> 原 AppKit NSVisualEffectView / 窗口装饰（双平台）
//! - `render_model_template`  -> 原 ProcessRunner + poppk_model_templates.py 渲染链路
//! - 后续迁移：ProjectScanner / WorkbenchStore / ModelRunEvidence 的状态机逻辑落在这里

use std::path::PathBuf;
use std::process::Command;
use tauri::Manager;
#[cfg(target_os = "macos")]
use window_vibrancy::{apply_vibrancy, NSVisualEffectMaterial};
#[cfg(target_os = "windows")]
use window_vibrancy::apply_mica;

/// 按平台施加系统级毛玻璃：
/// - macOS: 系统 Vibrancy（HudWindow 材质，与原生效果一致）
/// - Windows: Windows 11 Mica（Win10 自动忽略，前端有降级样式）
fn apply_glass(app: &tauri::AppHandle) {
    let Some(window) = app.get_webview_window("main") else {
        return;
    };

    #[cfg(target_os = "macos")]
    {
        let _ = apply_vibrancy(&window, NSVisualEffectMaterial::HudWindow, None, Some(16.0));
    }

    #[cfg(target_os = "windows")]
    {
        let _ = apply_mica(&window, Some(true));
    }
}

#[tauri::command]
fn get_platform() -> String {
    format!("{} / {}", std::env::consts::OS, std::env::consts::ARCH)
}

/// 跨平台找 Python 解释器：优先 python3，回退 python（Windows 常见）。
fn find_python() -> Option<&'static str> {
    for name in ["python3", "python"] {
        if Command::new(name).arg("--version").output().is_ok() {
            return Some(name);
        }
    }
    None
}

/// 定位模型库渲染脚本：
/// 1. bundle 资源目录（打包后 / dev 运行时的标准位置，Tauri 自动同步）
/// 2. 仓库内 Resources 副本（直接 cargo run 时的兜底）
fn locate_template_script(app: &tauri::AppHandle) -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Ok(dir) = app.path().resource_dir() {
        candidates.push(dir.join("poppk_model_templates.py"));
    }
    // cargo run 的 cwd 通常是 src-tauri 或仓库根，两种情况都探测
    if let Ok(cwd) = std::env::current_dir() {
        candidates.push(cwd.join("resources/poppk_model_templates.py"));
        candidates.push(cwd.join("../Resources/poppk_model_templates.py"));
        candidates.push(cwd.join("../../Resources/poppk_model_templates.py"));
    }
    candidates.into_iter().find(|p| p.exists())
}

#[tauri::command]
fn render_model_template(
    app: tauri::AppHandle,
    template: String,
    run: String,
) -> Result<String, String> {
    // 白名单模板，避免任意参数注入
    const ALLOWED: [&str; 8] = [
        "iv_bolus_1c_advan1_trans2",
        "iv_infusion_1c_advan1_trans2",
        "iv_bolus_2c_advan3_trans4",
        "iv_infusion_2c_advan3_trans4",
        "iv_bolus_3c_advan11_trans4",
        "iv_infusion_3c_advan11_trans4",
        "extravascular_1c_advan2_trans2",
        "extravascular_2c_advan4_trans4",
    ];
    if !ALLOWED.contains(&template.as_str()) {
        return Err(format!("模板不在白名单：{template}"));
    }
    if run.is_empty() || run.len() > 3 || !run.chars().all(|c| c.is_ascii_digit()) {
        return Err("Run 必须是 1-3 位数字".into());
    }

    let Some(python) = find_python() else {
        return Err("PATH 中找不到 python3/python".into());
    };
    let Some(script) = locate_template_script(&app) else {
        return Err("找不到 poppk_model_templates.py（bundle 资源或 ../Resources）".into());
    };

    let output = Command::new(python)
        .arg(&script)
        .arg(&template)
        .arg("--run")
        .arg(&run)
        .output()
        .map_err(|e| format!("启动渲染进程失败：{e}"))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).into_owned())
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            apply_glass(app.handle());
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![get_platform, render_model_template])
        .run(tauri::generate_context!())
        .expect("AutoPMX 启动失败");
}
