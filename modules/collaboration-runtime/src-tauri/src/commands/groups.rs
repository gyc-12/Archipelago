use crate::app_error::AppCommandError;
use crate::db::service::group_service;
use crate::db::AppDatabase;
use crate::models::group::{GroupAgentInfo, GroupChatInfo, GroupChatWithAgents};
use serde::Serialize;

pub const GROUP_UPSERTED_EVENT: &str = "island://group-upserted";
pub const GROUP_DELETED_EVENT: &str = "island://group-deleted";
pub const AGENT_UPSERTED_EVENT: &str = "island://agent-upserted";
pub const AGENT_DELETED_EVENT: &str = "island://agent-deleted";

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDeletedPayload {
    pub group_id: i32,
    pub folder_id: Option<i32>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentDeletedPayload {
    pub group_id: Option<i32>,
    pub agent_id: i32,
}

pub async fn group_with_agents_core(
    db: &AppDatabase,
    group: crate::db::entities::group_chat::Model,
) -> Result<GroupChatWithAgents, AppCommandError> {
    let agents = group_service::list_agents_by_group(&db.conn, group.id)
        .await
        .map_err(AppCommandError::from)?;
    Ok(GroupChatWithAgents {
        group: GroupChatInfo::from(group),
        agents: agents.into_iter().map(GroupAgentInfo::from).collect(),
    })
}

pub async fn list_groups_core(
    db: &AppDatabase,
) -> Result<Vec<GroupChatWithAgents>, AppCommandError> {
    let groups = group_service::list_groups(&db.conn)
        .await
        .map_err(AppCommandError::from)?;

    let mut results = Vec::with_capacity(groups.len());
    for group in groups {
        results.push(group_with_agents_core(db, group).await?);
    }
    Ok(results)
}

pub async fn create_group_core(
    db: &AppDatabase,
    name: String,
    folder_id: Option<i32>,
    folder_path: Option<String>,
) -> Result<GroupChatWithAgents, AppCommandError> {
    let group = group_service::create_group(&db.conn, name, folder_id, folder_path)
        .await
        .map_err(AppCommandError::from)?;
    group_with_agents_core(db, group).await
}

pub async fn update_group_core(
    db: &AppDatabase,
    id: i32,
    name: Option<String>,
    primary_agent_id: Option<Option<i32>>,
) -> Result<GroupChatWithAgents, AppCommandError> {
    let group = group_service::update_group(&db.conn, id, name, primary_agent_id)
        .await
        .map_err(AppCommandError::from)?;
    group_with_agents_core(db, group).await
}

pub async fn delete_group_core(db: &AppDatabase, id: i32) -> Result<(), AppCommandError> {
    group_service::soft_delete_group(&db.conn, id)
        .await
        .map_err(AppCommandError::from)
}

pub async fn delete_groups_by_folder_core(
    db: &AppDatabase,
    folder_id: i32,
) -> Result<Vec<i32>, AppCommandError> {
    group_service::soft_delete_groups_by_folder(&db.conn, folder_id)
        .await
        .map_err(AppCommandError::from)
}

pub async fn add_group_agent_core(
    db: &AppDatabase,
    group_id: i32,
    agent_type: String,
    role: String,
    conversation_id: Option<i32>,
    connection_id: Option<String>,
    working_dir: String,
) -> Result<GroupAgentInfo, AppCommandError> {
    let agent = group_service::add_agent(
        &db.conn,
        group_id,
        agent_type,
        role,
        conversation_id,
        connection_id,
        working_dir,
    )
    .await
    .map_err(AppCommandError::from)?;
    Ok(GroupAgentInfo::from(agent))
}

pub async fn remove_group_agent_core(db: &AppDatabase, id: i32) -> Result<(), AppCommandError> {
    group_service::remove_agent(&db.conn, id)
        .await
        .map_err(AppCommandError::from)
}

pub async fn update_group_agent_core(
    db: &AppDatabase,
    id: i32,
    role: Option<String>,
    connection_id: Option<Option<String>>,
    conversation_id: Option<Option<i32>>,
) -> Result<GroupAgentInfo, AppCommandError> {
    let agent = group_service::update_agent(&db.conn, id, role, connection_id, conversation_id)
        .await
        .map_err(AppCommandError::from)?;
    Ok(GroupAgentInfo::from(agent))
}

#[cfg(feature = "tauri-runtime")]
#[tauri::command]
pub async fn list_groups(
    db: tauri::State<'_, AppDatabase>,
) -> Result<Vec<GroupChatWithAgents>, AppCommandError> {
    list_groups_core(&db).await
}

#[cfg(feature = "tauri-runtime")]
#[tauri::command]
pub async fn create_group(
    app: tauri::AppHandle,
    db: tauri::State<'_, AppDatabase>,
    name: String,
    folder_id: Option<i32>,
    folder_path: Option<String>,
) -> Result<GroupChatWithAgents, AppCommandError> {
    let group = create_group_core(&db, name, folder_id, folder_path).await?;
    crate::web::event_bridge::emit_event(
        &crate::web::event_bridge::EventEmitter::Tauri(app),
        GROUP_UPSERTED_EVENT,
        &group,
    );
    Ok(group)
}

#[cfg(feature = "tauri-runtime")]
#[tauri::command]
pub async fn update_group(
    app: tauri::AppHandle,
    db: tauri::State<'_, AppDatabase>,
    id: i32,
    name: Option<String>,
    primary_agent_id: Option<Option<i32>>,
) -> Result<GroupChatWithAgents, AppCommandError> {
    let group = update_group_core(&db, id, name, primary_agent_id).await?;
    crate::web::event_bridge::emit_event(
        &crate::web::event_bridge::EventEmitter::Tauri(app),
        GROUP_UPSERTED_EVENT,
        &group,
    );
    Ok(group)
}

#[cfg(feature = "tauri-runtime")]
#[tauri::command]
pub async fn delete_group(
    app: tauri::AppHandle,
    db: tauri::State<'_, AppDatabase>,
    id: i32,
    folder_id: Option<i32>,
) -> Result<(), AppCommandError> {
    delete_group_core(&db, id).await?;
    crate::web::event_bridge::emit_event(
        &crate::web::event_bridge::EventEmitter::Tauri(app),
        GROUP_DELETED_EVENT,
        &GroupDeletedPayload {
            group_id: id,
            folder_id,
        },
    );
    Ok(())
}

#[cfg(feature = "tauri-runtime")]
#[tauri::command]
pub async fn add_group_agent(
    app: tauri::AppHandle,
    db: tauri::State<'_, AppDatabase>,
    group_id: i32,
    agent_type: String,
    role: String,
    conversation_id: Option<i32>,
    connection_id: Option<String>,
    working_dir: String,
) -> Result<GroupAgentInfo, AppCommandError> {
    add_group_agent_core(
        &db,
        group_id,
        agent_type,
        role,
        conversation_id,
        connection_id,
        working_dir,
    )
    .await
    .inspect(|agent| {
        crate::web::event_bridge::emit_event(
            &crate::web::event_bridge::EventEmitter::Tauri(app),
            AGENT_UPSERTED_EVENT,
            agent,
        );
    })
}

#[cfg(feature = "tauri-runtime")]
#[tauri::command]
pub async fn remove_group_agent(
    app: tauri::AppHandle,
    db: tauri::State<'_, AppDatabase>,
    id: i32,
    group_id: Option<i32>,
) -> Result<(), AppCommandError> {
    remove_group_agent_core(&db, id).await?;
    crate::web::event_bridge::emit_event(
        &crate::web::event_bridge::EventEmitter::Tauri(app),
        AGENT_DELETED_EVENT,
        &AgentDeletedPayload {
            group_id,
            agent_id: id,
        },
    );
    Ok(())
}

#[cfg(feature = "tauri-runtime")]
#[tauri::command]
pub async fn update_group_agent(
    app: tauri::AppHandle,
    db: tauri::State<'_, AppDatabase>,
    id: i32,
    role: Option<String>,
    connection_id: Option<Option<String>>,
    conversation_id: Option<Option<i32>>,
) -> Result<GroupAgentInfo, AppCommandError> {
    let agent = update_group_agent_core(&db, id, role, connection_id, conversation_id).await?;
    crate::web::event_bridge::emit_event(
        &crate::web::event_bridge::EventEmitter::Tauri(app),
        AGENT_UPSERTED_EVENT,
        &agent,
    );
    Ok(agent)
}
