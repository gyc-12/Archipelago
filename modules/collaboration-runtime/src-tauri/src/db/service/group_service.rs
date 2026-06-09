use chrono::Utc;
use sea_orm::{
    ActiveModelTrait, ActiveValue::NotSet, ColumnTrait, DatabaseConnection, EntityTrait,
    IntoActiveModel, QueryFilter, QueryOrder, Set,
};

use crate::db::entities::{group_agent, group_chat};
use crate::db::error::DbError;

pub const DEFAULT_GROUP_AGENT_ROLE: &str = "Coder";

fn normalize_group_agent_role(role: String) -> String {
    if role.trim().is_empty() {
        DEFAULT_GROUP_AGENT_ROLE.to_string()
    } else {
        role
    }
}

pub async fn create_group(
    conn: &DatabaseConnection,
    name: String,
    folder_id: Option<i32>,
    folder_path: Option<String>,
) -> Result<group_chat::Model, DbError> {
    let now = Utc::now();
    let active = group_chat::ActiveModel {
        id: NotSet,
        name: Set(name),
        folder_id: Set(folder_id),
        folder_path: Set(folder_path),
        primary_agent_id: Set(None),
        created_at: Set(now),
        updated_at: Set(now),
        deleted_at: Set(None),
    };
    Ok(active.insert(conn).await?)
}

pub async fn update_group(
    conn: &DatabaseConnection,
    id: i32,
    name: Option<String>,
    primary_agent_id: Option<Option<i32>>,
) -> Result<group_chat::Model, DbError> {
    let model = group_chat::Entity::find_by_id(id)
        .filter(group_chat::Column::DeletedAt.is_null())
        .one(conn)
        .await?
        .ok_or_else(|| DbError::Migration(format!("group chat not found: {id}")))?;

    let mut active = model.into_active_model();
    if let Some(v) = name {
        active.name = Set(v);
    }
    if let Some(v) = primary_agent_id {
        active.primary_agent_id = Set(v);
    }
    active.updated_at = Set(Utc::now());
    Ok(active.update(conn).await?)
}

pub async fn soft_delete_group(conn: &DatabaseConnection, id: i32) -> Result<(), DbError> {
    let now = Utc::now();
    if let Some(model) = group_chat::Entity::find_by_id(id)
        .filter(group_chat::Column::DeletedAt.is_null())
        .one(conn)
        .await?
    {
        let mut active = model.into_active_model();
        active.deleted_at = Set(Some(now));
        active.updated_at = Set(now);
        active.update(conn).await?;
    }

    group_agent::Entity::update_many()
        .filter(group_agent::Column::GroupId.eq(id))
        .filter(group_agent::Column::DeletedAt.is_null())
        .col_expr(
            group_agent::Column::DeletedAt,
            sea_orm::sea_query::Expr::value(now),
        )
        .col_expr(
            group_agent::Column::UpdatedAt,
            sea_orm::sea_query::Expr::value(now),
        )
        .exec(conn)
        .await?;

    Ok(())
}

pub async fn soft_delete_groups_by_folder(
    conn: &DatabaseConnection,
    folder_id: i32,
) -> Result<Vec<i32>, DbError> {
    let groups = group_chat::Entity::find()
        .filter(group_chat::Column::FolderId.eq(folder_id))
        .filter(group_chat::Column::DeletedAt.is_null())
        .all(conn)
        .await?;
    let ids = groups.iter().map(|g| g.id).collect::<Vec<_>>();
    for group in groups {
        soft_delete_group(conn, group.id).await?;
    }
    Ok(ids)
}

pub async fn list_groups(conn: &DatabaseConnection) -> Result<Vec<group_chat::Model>, DbError> {
    Ok(group_chat::Entity::find()
        .filter(group_chat::Column::DeletedAt.is_null())
        .order_by_desc(group_chat::Column::UpdatedAt)
        .all(conn)
        .await?)
}

pub async fn list_agents_by_group(
    conn: &DatabaseConnection,
    group_id: i32,
) -> Result<Vec<group_agent::Model>, DbError> {
    Ok(group_agent::Entity::find()
        .filter(group_agent::Column::GroupId.eq(group_id))
        .filter(group_agent::Column::DeletedAt.is_null())
        .order_by_asc(group_agent::Column::Id)
        .all(conn)
        .await?)
}

pub async fn list_groups_by_folder(
    conn: &DatabaseConnection,
    folder_id: i32,
) -> Result<Vec<group_chat::Model>, DbError> {
    Ok(group_chat::Entity::find()
        .filter(group_chat::Column::FolderId.eq(folder_id))
        .filter(group_chat::Column::DeletedAt.is_null())
        .order_by_desc(group_chat::Column::UpdatedAt)
        .all(conn)
        .await?)
}

pub async fn add_agent(
    conn: &DatabaseConnection,
    group_id: i32,
    agent_type: String,
    role: String,
    conversation_id: Option<i32>,
    connection_id: Option<String>,
    working_dir: String,
) -> Result<group_agent::Model, DbError> {
    let normalized_role = normalize_group_agent_role(role);
    if let Some(existing) = group_agent::Entity::find()
        .filter(group_agent::Column::GroupId.eq(group_id))
        .filter(group_agent::Column::AgentType.eq(agent_type.clone()))
        .filter(group_agent::Column::DeletedAt.is_null())
        .one(conn)
        .await?
    {
        let mut active = existing.into_active_model();
        active.role = Set(normalized_role);
        active.conversation_id = Set(conversation_id);
        active.connection_id = Set(connection_id);
        active.working_dir = Set(working_dir);
        active.updated_at = Set(Utc::now());
        return Ok(active.update(conn).await?);
    }

    let now = Utc::now();
    let active = group_agent::ActiveModel {
        id: NotSet,
        group_id: Set(group_id),
        agent_type: Set(agent_type),
        role: Set(normalized_role),
        conversation_id: Set(conversation_id),
        connection_id: Set(connection_id),
        working_dir: Set(working_dir),
        created_at: Set(now),
        updated_at: Set(now),
        deleted_at: Set(None),
    };
    Ok(active.insert(conn).await?)
}

pub async fn list_agents_by_conversation(
    conn: &DatabaseConnection,
    conversation_id: i32,
) -> Result<Vec<group_agent::Model>, DbError> {
    Ok(group_agent::Entity::find()
        .filter(group_agent::Column::ConversationId.eq(conversation_id))
        .filter(group_agent::Column::DeletedAt.is_null())
        .all(conn)
        .await?)
}

pub async fn remove_agent(conn: &DatabaseConnection, id: i32) -> Result<(), DbError> {
    if let Some(model) = group_agent::Entity::find_by_id(id)
        .filter(group_agent::Column::DeletedAt.is_null())
        .one(conn)
        .await?
    {
        let now = Utc::now();
        let mut active = model.into_active_model();
        active.deleted_at = Set(Some(now));
        active.updated_at = Set(now);
        active.update(conn).await?;
    }
    Ok(())
}

pub async fn update_agent(
    conn: &DatabaseConnection,
    id: i32,
    role: Option<String>,
    connection_id: Option<Option<String>>,
    conversation_id: Option<Option<i32>>,
) -> Result<group_agent::Model, DbError> {
    let model = group_agent::Entity::find_by_id(id)
        .filter(group_agent::Column::DeletedAt.is_null())
        .one(conn)
        .await?
        .ok_or_else(|| DbError::Migration(format!("group agent not found: {id}")))?;

    let mut active = model.into_active_model();
    if let Some(v) = role {
        active.role = Set(normalize_group_agent_role(v));
    }
    if let Some(v) = connection_id {
        active.connection_id = Set(v);
    }
    if let Some(v) = conversation_id {
        active.conversation_id = Set(v);
    }
    active.updated_at = Set(Utc::now());
    Ok(active.update(conn).await?)
}
