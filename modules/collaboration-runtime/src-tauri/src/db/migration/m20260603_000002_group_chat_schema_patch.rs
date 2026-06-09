use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

const DEFAULT_TIMESTAMP: &str = "1970-01-01T00:00:00Z";

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        ensure_group_chat_schema(manager).await?;
        ensure_group_agent_schema(manager).await?;

        manager
            .create_index(
                Index::create()
                    .if_not_exists()
                    .name("idx_group_agent_group_id")
                    .table(GroupAgent::Table)
                    .col(GroupAgent::GroupId)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .if_not_exists()
                    .name("idx_group_chat_folder_id")
                    .table(GroupChat::Table)
                    .col(GroupChat::FolderId)
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let _ = manager;
        Ok(())
    }
}

async fn ensure_group_chat_schema(manager: &SchemaManager<'_>) -> Result<(), DbErr> {
    add_column_if_missing(
        manager,
        "group_chat",
        "name",
        ColumnDef::new(GroupChat::Name)
            .string()
            .not_null()
            .default("Group Chat"),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_chat",
        "folder_id",
        ColumnDef::new(GroupChat::FolderId).integer().null(),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_chat",
        "folder_path",
        ColumnDef::new(GroupChat::FolderPath).text().null(),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_chat",
        "primary_agent_id",
        ColumnDef::new(GroupChat::PrimaryAgentId).integer().null(),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_chat",
        "created_at",
        ColumnDef::new(GroupChat::CreatedAt)
            .timestamp_with_time_zone()
            .not_null()
            .default(DEFAULT_TIMESTAMP),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_chat",
        "updated_at",
        ColumnDef::new(GroupChat::UpdatedAt)
            .timestamp_with_time_zone()
            .not_null()
            .default(DEFAULT_TIMESTAMP),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_chat",
        "deleted_at",
        ColumnDef::new(GroupChat::DeletedAt)
            .timestamp_with_time_zone()
            .null(),
    )
    .await
}

async fn ensure_group_agent_schema(manager: &SchemaManager<'_>) -> Result<(), DbErr> {
    add_column_if_missing(
        manager,
        "group_agent",
        "group_id",
        ColumnDef::new(GroupAgent::GroupId)
            .integer()
            .not_null()
            .default(0),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "agent_type",
        ColumnDef::new(GroupAgent::AgentType)
            .string()
            .not_null()
            .default("claude_code"),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "role",
        ColumnDef::new(GroupAgent::Role)
            .string()
            .not_null()
            .default("Coder"),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "conversation_id",
        ColumnDef::new(GroupAgent::ConversationId).integer().null(),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "connection_id",
        ColumnDef::new(GroupAgent::ConnectionId).string().null(),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "working_dir",
        ColumnDef::new(GroupAgent::WorkingDir)
            .text()
            .not_null()
            .default(""),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "created_at",
        ColumnDef::new(GroupAgent::CreatedAt)
            .timestamp_with_time_zone()
            .not_null()
            .default(DEFAULT_TIMESTAMP),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "updated_at",
        ColumnDef::new(GroupAgent::UpdatedAt)
            .timestamp_with_time_zone()
            .not_null()
            .default(DEFAULT_TIMESTAMP),
    )
    .await?;
    add_column_if_missing(
        manager,
        "group_agent",
        "deleted_at",
        ColumnDef::new(GroupAgent::DeletedAt)
            .timestamp_with_time_zone()
            .null(),
    )
    .await
}

async fn add_column_if_missing(
    manager: &SchemaManager<'_>,
    table_name: &str,
    column_name: &str,
    column: &mut ColumnDef,
) -> Result<(), DbErr> {
    if manager.has_column(table_name, column_name).await? {
        return Ok(());
    }

    manager
        .alter_table(
            Table::alter()
                .table(Alias::new(table_name))
                .add_column(column.to_owned())
                .to_owned(),
        )
        .await
}

#[derive(DeriveIden)]
enum GroupChat {
    Table,
    Name,
    FolderId,
    FolderPath,
    PrimaryAgentId,
    CreatedAt,
    UpdatedAt,
    DeletedAt,
}

#[derive(DeriveIden)]
enum GroupAgent {
    Table,
    GroupId,
    AgentType,
    Role,
    ConversationId,
    ConnectionId,
    WorkingDir,
    CreatedAt,
    UpdatedAt,
    DeletedAt,
}

#[cfg(test)]
mod tests {
    use super::*;
    use sea_orm::{ConnectionTrait, Database, DbBackend, EntityTrait, Statement};

    use crate::db::entities::{group_agent, group_chat};

    #[tokio::test]
    async fn patches_existing_group_tables_missing_soft_delete_columns() {
        let conn = Database::connect("sqlite::memory:")
            .await
            .expect("open sqlite");
        conn.execute(Statement::from_string(
            DbBackend::Sqlite,
            "CREATE TABLE group_chat (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL
            );"
            .to_owned(),
        ))
        .await
        .expect("create old group_chat");
        conn.execute(Statement::from_string(
            DbBackend::Sqlite,
            "CREATE TABLE group_agent (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                group_id INTEGER NOT NULL,
                agent_type TEXT NOT NULL,
                role TEXT NOT NULL,
                working_dir TEXT NOT NULL
            );"
            .to_owned(),
        ))
        .await
        .expect("create old group_agent");
        conn.execute(Statement::from_string(
            DbBackend::Sqlite,
            "INSERT INTO group_chat (name) VALUES ('Legacy Group');".to_owned(),
        ))
        .await
        .expect("seed old group_chat");
        conn.execute(Statement::from_string(
            DbBackend::Sqlite,
            "INSERT INTO group_agent (group_id, agent_type, role, working_dir)
             VALUES (1, 'claude_code', 'Coder', '/tmp/legacy');"
                .to_owned(),
        ))
        .await
        .expect("seed old group_agent");

        let manager = SchemaManager::new(&conn);
        ensure_group_chat_schema(&manager)
            .await
            .expect("patch group_chat");
        ensure_group_agent_schema(&manager)
            .await
            .expect("patch group_agent");

        assert!(manager
            .has_column("group_chat", "deleted_at")
            .await
            .unwrap());
        assert!(manager
            .has_column("group_agent", "deleted_at")
            .await
            .unwrap());
        assert!(manager
            .has_column("group_chat", "primary_agent_id")
            .await
            .unwrap());
        assert!(manager
            .has_column("group_agent", "connection_id")
            .await
            .unwrap());

        let group = group_chat::Entity::find_by_id(1)
            .one(&conn)
            .await
            .expect("query patched group")
            .expect("legacy group exists");
        assert_eq!(group.name, "Legacy Group");
        assert_eq!(group.deleted_at, None);

        let agent = group_agent::Entity::find_by_id(1)
            .one(&conn)
            .await
            .expect("query patched agent")
            .expect("legacy agent exists");
        assert_eq!(agent.agent_type, "claude_code");
        assert_eq!(agent.deleted_at, None);
    }
}
