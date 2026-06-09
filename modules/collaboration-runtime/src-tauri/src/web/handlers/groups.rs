use std::sync::Arc;

use axum::{extract::Extension, Json};
use serde::Deserialize;

use crate::app_error::AppCommandError;
use crate::app_state::AppState;
use crate::commands::groups::{
    self as group_commands, AgentDeletedPayload, GroupDeletedPayload, AGENT_DELETED_EVENT,
    AGENT_UPSERTED_EVENT, GROUP_DELETED_EVENT, GROUP_UPSERTED_EVENT,
};
use crate::models::group::{GroupAgentInfo, GroupChatWithAgents};
use crate::web::event_bridge::emit_event;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateGroupParams {
    pub name: String,
    pub folder_id: Option<i32>,
    pub folder_path: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateGroupParams {
    pub id: i32,
    pub name: Option<String>,
    pub primary_agent_id: Option<Option<i32>>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteGroupParams {
    pub id: i32,
    pub folder_id: Option<i32>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AddGroupAgentParams {
    pub group_id: i32,
    pub agent_type: String,
    pub role: String,
    pub conversation_id: Option<i32>,
    pub connection_id: Option<String>,
    pub working_dir: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RemoveGroupAgentParams {
    pub id: i32,
    pub group_id: Option<i32>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateGroupAgentParams {
    pub id: i32,
    pub role: Option<String>,
    pub connection_id: Option<Option<String>>,
    pub conversation_id: Option<Option<i32>>,
}

pub async fn list_groups(
    Extension(state): Extension<Arc<AppState>>,
) -> Result<Json<Vec<GroupChatWithAgents>>, AppCommandError> {
    Ok(Json(group_commands::list_groups_core(&state.db).await?))
}

pub async fn create_group(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<CreateGroupParams>,
) -> Result<Json<GroupChatWithAgents>, AppCommandError> {
    let group = group_commands::create_group_core(
        &state.db,
        params.name,
        params.folder_id,
        params.folder_path,
    )
    .await?;
    emit_event(&state.emitter, GROUP_UPSERTED_EVENT, &group);
    Ok(Json(group))
}

pub async fn update_group(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<UpdateGroupParams>,
) -> Result<Json<GroupChatWithAgents>, AppCommandError> {
    let group = group_commands::update_group_core(
        &state.db,
        params.id,
        params.name,
        params.primary_agent_id,
    )
    .await?;
    emit_event(&state.emitter, GROUP_UPSERTED_EVENT, &group);
    Ok(Json(group))
}

pub async fn delete_group(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<DeleteGroupParams>,
) -> Result<Json<()>, AppCommandError> {
    group_commands::delete_group_core(&state.db, params.id).await?;
    emit_event(
        &state.emitter,
        GROUP_DELETED_EVENT,
        &GroupDeletedPayload {
            group_id: params.id,
            folder_id: params.folder_id,
        },
    );
    Ok(Json(()))
}

pub async fn add_group_agent(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<AddGroupAgentParams>,
) -> Result<Json<GroupAgentInfo>, AppCommandError> {
    let agent = group_commands::add_group_agent_core(
        &state.db,
        params.group_id,
        params.agent_type,
        params.role,
        params.conversation_id,
        params.connection_id,
        params.working_dir,
    )
    .await?;
    emit_event(&state.emitter, AGENT_UPSERTED_EVENT, &agent);
    Ok(Json(agent))
}

pub async fn remove_group_agent(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<RemoveGroupAgentParams>,
) -> Result<Json<()>, AppCommandError> {
    group_commands::remove_group_agent_core(&state.db, params.id).await?;
    emit_event(
        &state.emitter,
        AGENT_DELETED_EVENT,
        &AgentDeletedPayload {
            group_id: params.group_id,
            agent_id: params.id,
        },
    );
    Ok(Json(()))
}

pub async fn update_group_agent(
    Extension(state): Extension<Arc<AppState>>,
    Json(params): Json<UpdateGroupAgentParams>,
) -> Result<Json<GroupAgentInfo>, AppCommandError> {
    let agent = group_commands::update_group_agent_core(
        &state.db,
        params.id,
        params.role,
        params.connection_id,
        params.conversation_id,
    )
    .await?;
    emit_event(&state.emitter, AGENT_UPSERTED_EVENT, &agent);
    Ok(Json(agent))
}
