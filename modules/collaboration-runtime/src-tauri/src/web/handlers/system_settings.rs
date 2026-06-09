use std::path::PathBuf;
use std::process::Command;
use std::sync::Arc;

use axum::{extract::Extension, Json};
use serde::{Deserialize, Serialize};

use crate::app_error::AppCommandError;
use crate::app_state::AppState;
use crate::commands::system_settings as settings_commands;
use crate::commands::system_settings::{
    LANGUAGE_SETTINGS_UPDATED_EVENT, SYSTEM_LANGUAGE_SETTINGS_KEY, SYSTEM_PROXY_SETTINGS_KEY,
    SYSTEM_TERMINAL_SETTINGS_KEY, TERMINAL_SETTINGS_UPDATED_EVENT,
};
use crate::db::service::app_metadata_service;
use crate::models::*;
use crate::network::proxy;

// Wrapper structs to match Tauri's named parameter convention.
// Frontend sends `{ settings: <T> }` which Tauri `invoke()` unwraps automatically,
// but in web mode the entire JSON body arrives as-is.

#[derive(Deserialize)]
pub struct UpdateProxySettingsParams {
    pub settings: SystemProxySettings,
}

#[derive(Deserialize)]
pub struct UpdateLanguageSettingsParams {
    pub settings: SystemLanguageSettings,
}

#[derive(Deserialize)]
pub struct UpdateTerminalSettingsParams {
    pub settings: SystemTerminalSettings,
}

// ---------------------------------------------------------------------------
// Read handlers
// ---------------------------------------------------------------------------

pub async fn get_system_proxy_settings(
    Extension(state): Extension<Arc<AppState>>,
) -> Result<Json<SystemProxySettings>, AppCommandError> {
    let db = &state.db;
    let settings = settings_commands::load_system_proxy_settings(&db.conn).await?;
    Ok(Json(settings))
}

pub async fn get_system_language_settings(
    Extension(state): Extension<Arc<AppState>>,
) -> Result<Json<SystemLanguageSettings>, AppCommandError> {
    let db = &state.db;
    let settings = settings_commands::load_system_language_settings(&db.conn).await?;
    Ok(Json(settings))
}

pub async fn get_system_terminal_settings(
    Extension(state): Extension<Arc<AppState>>,
) -> Result<Json<SystemTerminalSettings>, AppCommandError> {
    let db = &state.db;
    let settings = settings_commands::load_system_terminal_settings(&db.conn).await?;
    Ok(Json(settings))
}

pub async fn get_available_terminal_shells(
) -> Result<Json<AvailableTerminalShells>, AppCommandError> {
    Ok(Json(settings_commands::build_available_terminal_shells()))
}

#[derive(Deserialize)]
pub struct ProbeTerminalShellPathParams {
    pub path: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RevealPathParams {
    pub path: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RevealPathResponse {
    pub ok: bool,
}

pub async fn probe_terminal_shell_path(
    Json(params): Json<ProbeTerminalShellPathParams>,
) -> Result<Json<bool>, AppCommandError> {
    Ok(Json(settings_commands::probe_terminal_shell_path_core(
        &params.path,
    )))
}

pub async fn reveal_path_in_file_manager(
    Json(params): Json<RevealPathParams>,
) -> Result<Json<RevealPathResponse>, AppCommandError> {
    let path = PathBuf::from(params.path.trim());
    if path.as_os_str().is_empty() {
        return Err(AppCommandError::invalid_input("Path is required"));
    }
    if !path.exists() {
        return Err(AppCommandError::not_found("Path does not exist")
            .with_detail(path.display().to_string()));
    }

    #[cfg(target_os = "macos")]
    let mut command = {
        let mut command = Command::new("open");
        command.arg("-R").arg(&path);
        command
    };

    #[cfg(target_os = "windows")]
    let mut command = {
        let mut command = Command::new("explorer");
        command.arg(format!("/select,{}", path.display()));
        command
    };

    #[cfg(all(unix, not(target_os = "macos")))]
    let mut command = {
        let target = if path.is_dir() {
            path.clone()
        } else {
            path.parent().unwrap_or(&path).to_path_buf()
        };
        let mut command = Command::new("xdg-open");
        command.arg(target);
        command
    };

    let output = command.output().map_err(|err| {
        AppCommandError::external_command("Failed to open file manager", err.to_string())
    })?;
    if !output.status.success() {
        return Err(AppCommandError::external_command(
            "Failed to open file manager",
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }

    Ok(Json(RevealPathResponse { ok: true }))
}

// ---------------------------------------------------------------------------
// Update handlers
// ---------------------------------------------------------------------------

pub async fn update_system_proxy_settings(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<UpdateProxySettingsParams>,
) -> Result<Json<SystemProxySettings>, AppCommandError> {
    let settings = params.settings;
    let db = &state.db;

    // TODO: call normalize_proxy_settings once it is made pub(crate) in
    // commands/system_settings.rs. For now the frontend validates the URL.
    let serialized = serde_json::to_string(&settings).map_err(|e| {
        AppCommandError::invalid_input("Failed to serialize proxy settings")
            .with_detail(e.to_string())
    })?;

    app_metadata_service::upsert_value(&db.conn, SYSTEM_PROXY_SETTINGS_KEY, &serialized)
        .await
        .map_err(AppCommandError::from)?;

    proxy::apply_system_proxy_settings(&settings)?;
    Ok(Json(settings))
}

pub async fn update_system_language_settings(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<UpdateLanguageSettingsParams>,
) -> Result<Json<SystemLanguageSettings>, AppCommandError> {
    let settings = params.settings;
    let db = &state.db;

    let serialized = serde_json::to_string(&settings).map_err(|e| {
        AppCommandError::invalid_input("Failed to serialize language settings")
            .with_detail(e.to_string())
    })?;

    app_metadata_service::upsert_value(&db.conn, SYSTEM_LANGUAGE_SETTINGS_KEY, &serialized)
        .await
        .map_err(AppCommandError::from)?;

    crate::web::event_bridge::emit_event(
        &state.emitter,
        LANGUAGE_SETTINGS_UPDATED_EVENT,
        settings.clone(),
    );

    Ok(Json(settings))
}

pub async fn update_system_terminal_settings(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<UpdateTerminalSettingsParams>,
) -> Result<Json<SystemTerminalSettings>, AppCommandError> {
    let settings = settings_commands::normalize_terminal_settings(params.settings);
    let db = &state.db;

    let serialized = serde_json::to_string(&settings).map_err(|e| {
        AppCommandError::invalid_input("Failed to serialize terminal settings")
            .with_detail(e.to_string())
    })?;

    app_metadata_service::upsert_value(&db.conn, SYSTEM_TERMINAL_SETTINGS_KEY, &serialized)
        .await
        .map_err(AppCommandError::from)?;

    crate::web::event_bridge::emit_event(
        &state.emitter,
        TERMINAL_SETTINGS_UPDATED_EVENT,
        settings.clone(),
    );

    Ok(Json(settings))
}
