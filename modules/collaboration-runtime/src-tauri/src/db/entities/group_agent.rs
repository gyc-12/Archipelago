use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "group_agent")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    pub group_id: i32,
    pub agent_type: String,
    pub role: String,
    pub conversation_id: Option<i32>,
    pub connection_id: Option<String>,
    pub working_dir: String,
    pub created_at: DateTimeUtc,
    pub updated_at: DateTimeUtc,
    pub deleted_at: Option<DateTimeUtc>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::group_chat::Entity",
        from = "Column::GroupId",
        to = "super::group_chat::Column::Id"
    )]
    GroupChat,
}

impl Related<super::group_chat::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::GroupChat.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
