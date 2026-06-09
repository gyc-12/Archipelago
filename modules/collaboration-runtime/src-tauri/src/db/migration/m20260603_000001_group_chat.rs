use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(GroupChat::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(GroupChat::Id)
                            .integer()
                            .not_null()
                            .auto_increment()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(GroupChat::Name).string().not_null())
                    .col(ColumnDef::new(GroupChat::FolderId).integer().null())
                    .col(ColumnDef::new(GroupChat::FolderPath).text().null())
                    .col(ColumnDef::new(GroupChat::PrimaryAgentId).integer().null())
                    .col(
                        ColumnDef::new(GroupChat::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(GroupChat::UpdatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(GroupChat::DeletedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(GroupAgent::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(GroupAgent::Id)
                            .integer()
                            .not_null()
                            .auto_increment()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(GroupAgent::GroupId).integer().not_null())
                    .col(ColumnDef::new(GroupAgent::AgentType).string().not_null())
                    .col(
                        ColumnDef::new(GroupAgent::Role)
                            .string()
                            .not_null()
                            .default("Coder"),
                    )
                    .col(ColumnDef::new(GroupAgent::ConversationId).integer().null())
                    .col(ColumnDef::new(GroupAgent::ConnectionId).string().null())
                    .col(ColumnDef::new(GroupAgent::WorkingDir).text().not_null())
                    .col(
                        ColumnDef::new(GroupAgent::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(GroupAgent::UpdatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(GroupAgent::DeletedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_group_agent_group_id")
                            .from(GroupAgent::Table, GroupAgent::GroupId)
                            .to(GroupChat::Table, GroupChat::Id)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_group_agent_group_id")
                    .table(GroupAgent::Table)
                    .col(GroupAgent::GroupId)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_group_chat_folder_id")
                    .table(GroupChat::Table)
                    .col(GroupChat::FolderId)
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(GroupAgent::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(GroupChat::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum GroupChat {
    Table,
    Id,
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
    Id,
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
